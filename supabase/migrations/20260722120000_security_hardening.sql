-- Security hardening — fixes for confirmed review findings.
--
-- Forward migration (the base migrations are already deployed): every
-- statement is written to run standalone, so it can also be pasted into the
-- Supabase SQL editor. Covers four backend issues:
--   1. Customers could read the whole company directory (profiles RLS).
--   2. Invites could carry another company's project_ids -> cross-tenant
--      membership on redemption (create_invite / apply_invite / helper).
--   3. Any non-customer (incl. workers) could INSERT a task pre-set to
--      approved/done with forged stamps (enforce_task_transition + trigger).
--   4. Workers could forge completion/approval/creation stamps on updates.

-- ============================================================ 1. profiles RLS
-- Replace the single company-wide select policy with role-aware policies:
-- staff keep full-directory visibility; customers see only themselves plus
-- staff on a project they share (never other customers).

-- Whether the target profile shares a project with the caller. SECURITY
-- DEFINER so it can read project_members (whose own RLS hides all rows from
-- customers — a plain subquery in the policy would always see nothing).
create or replace function app.shares_project_with_me(p_profile_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_members pm_self
    join public.project_members pm_target
      on pm_target.project_id = pm_self.project_id
    where pm_self.profile_id = (select auth.uid())
      and pm_target.profile_id = p_profile_id
  );
$$;

grant execute on function app.shares_project_with_me(uuid) to authenticated;

drop policy if exists profiles_select_same_company on public.profiles;

create policy profiles_select_staff on public.profiles
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and coalesce(app.current_member_role() <> 'customer', false)
  );

create policy profiles_select_customer on public.profiles
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and app.current_member_role() = 'customer'
    and (
      id = (select auth.uid())
      or (
        -- Office (points of contact / portal message senders) and non-customer
        -- staff on a project the customer shares. Never other customers, never
        -- staff on projects the customer has nothing to do with.
        role in ('owner', 'manager')
        or (role <> 'customer' and app.shares_project_with_me(id))
      )
    )
  );

-- ================================================ 2. invite project scoping
-- Defense in depth: even if a cross-company membership row exists, a project
-- only grants access when it belongs to the caller's company.

create or replace function app.is_member_of_project(p_project_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.project_members pm
    join public.projects p on p.id = pm.project_id
    where pm.project_id = p_project_id
      and pm.profile_id = (select auth.uid())
      and p.company_id = app.current_company_id()
  )
  or (
    app.is_office()
    and exists (
      select 1
      from public.projects p
      where p.id = p_project_id
        and p.company_id = app.current_company_id()
    )
  );
$$;

-- Reject invites that reference projects outside the inviter's company.
create or replace function public.create_invite(
  p_role public.app_role,
  p_full_name text default null,
  p_project_ids uuid[] default '{}'
)
returns table (invite_id uuid, code text)
language plpgsql
set search_path = ''
as $$
declare
  v_alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_code text;
  v_id uuid;
begin
  if p_project_ids is not null and array_length(p_project_ids, 1) is not null then
    if exists (
      select 1
      from unnest(p_project_ids) as u(pid)
      where not exists (
        select 1 from public.projects p
        where p.id = u.pid and p.company_id = app.current_company_id()
      )
    ) then
      raise exception 'one or more projects do not belong to your company';
    end if;
  end if;

  for attempt in 1..5 loop
    select string_agg(substr(v_alphabet, 1 + floor(random() * 31)::int, 1), '')
    into v_code
    from generate_series(1, 8);

    begin
      insert into public.invites (company_id, code, role, full_name, project_ids, invited_by)
      values (app.current_company_id(), v_code, p_role, nullif(trim(p_full_name), ''),
              coalesce(p_project_ids, '{}'), (select auth.uid()))
      returning id into v_id;

      invite_id := v_id;
      code := v_code;
      return next;
      return;
    exception when unique_violation then
      -- collision: retry with a fresh code
    end;
  end loop;
  raise exception 'could not generate a unique invite code';
end;
$$;

-- Belt-and-suspenders on redemption: only add memberships for projects that
-- actually belong to the invite's company, even if a stale invite carries a
-- foreign project_id.
create or replace function app.apply_invite(p_user_id uuid, p_code text, p_fallback_name text)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
declare
  v_invite public.invites%rowtype;
begin
  select * into v_invite
  from public.invites
  where code = upper(trim(p_code))
    and redeemed_at is null
    and expires_at > now()
  for update;

  if not found then
    return false;
  end if;

  insert into public.profiles (id, company_id, role, full_name)
  values (p_user_id, v_invite.company_id, v_invite.role,
          coalesce(v_invite.full_name, p_fallback_name));

  insert into public.project_members (project_id, profile_id, added_by)
  select p.id, p_user_id, v_invite.invited_by
  from unnest(v_invite.project_ids) as u(pid)
  join public.projects p on p.id = u.pid and p.company_id = v_invite.company_id
  on conflict do nothing;

  update public.invites
  set redeemed_by = p_user_id, redeemed_at = now()
  where id = v_invite.id;

  return true;
end;
$$;

-- ============================================ 3 & 4. task authorization/stamps
-- Now fires on INSERT too, so a task cannot be created pre-approved/pre-done
-- with forged attribution. Workers are held to status-only changes (audit
-- columns added to the allowlist), and completion/approval/creation stamps are
-- always derived from state — client-supplied values are ignored in every
-- branch (previously they survived on no-op / blocked transitions).

create or replace function app.enforce_task_transition()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
  v_role public.app_role := app.current_member_role();
begin
  if v_actor is null then
    return new; -- service role / internal
  end if;

  if tg_op = 'INSERT' then
    -- Workers may only open tasks in a pre-completion state.
    if v_role = 'worker' and new.status not in ('todo', 'in_progress', 'blocked') then
      raise exception 'workers cannot create approved or completed tasks';
    end if;

    -- Creation attribution is the actor; stamps derive from the initial status.
    new.created_by := v_actor;
    if new.status = 'approved' then
      new.approved_by := v_actor;  new.approved_at := now();
      new.completed_by := v_actor; new.completed_at := now();
    elsif new.status = 'done' then
      new.approved_by := null;     new.approved_at := null;
      new.completed_by := v_actor; new.completed_at := now();
    else
      new.approved_by := null;     new.approved_at := null;
      new.completed_by := null;    new.completed_at := null;
    end if;

    return new;
  end if;

  -- tg_op = 'UPDATE'
  if v_role = 'worker' then
    if not exists (
      select 1 from public.task_assignments ta
      where ta.task_id = old.id and ta.profile_id = v_actor
    ) then
      raise exception 'workers can only update tasks assigned to them';
    end if;

    -- Only status may change. Audit/stamp columns (completed_*, approved_*,
    -- created_*) are not listed here because they are fully derived below for
    -- every role — a worker's client may send them, but the derivation
    -- overwrites whatever it sends, so forging is impossible regardless.
    if new.title is distinct from old.title
       or new.description is distinct from old.description
       or new.due_date is distinct from old.due_date
       or new.sort_order is distinct from old.sort_order
       or new.visible_to_customer is distinct from old.visible_to_customer
       or new.project_id is distinct from old.project_id
    then
      raise exception 'workers can only change task status';
    end if;

    if new.status is distinct from old.status
       and ('approved' in (new.status::text, old.status::text))
    then
      raise exception 'only a foreman or manager can approve tasks';
    end if;
  end if;

  -- created_by/created_at are set once, at insert.
  new.created_by := old.created_by;
  new.created_at := old.created_at;

  -- Approval stamp: derived, never trusted from the client.
  if new.status = 'approved' then
    if old.status = 'approved' then
      new.approved_by := old.approved_by;
      new.approved_at := old.approved_at;
    else
      new.approved_by := v_actor;
      new.approved_at := now();
    end if;
  else
    new.approved_by := null;
    new.approved_at := null;
  end if;

  -- Completion stamp: set on entry to done, cleared when reopened, otherwise
  -- (staying done, or blocked/approved) the prior stamp is preserved.
  if new.status = 'done' and old.status <> 'done' then
    new.completed_by := v_actor;
    new.completed_at := now();
  elsif new.status in ('todo', 'in_progress') then
    new.completed_by := null;
    new.completed_at := null;
  else
    new.completed_by := old.completed_by;
    new.completed_at := old.completed_at;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_task_transition on public.tasks;
create trigger enforce_task_transition before insert or update on public.tasks
  for each row execute function app.enforce_task_transition();
