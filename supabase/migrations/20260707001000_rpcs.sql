-- Client-callable RPCs (public schema — the only schema exposed via the API),
-- the project_overview view, and realtime publication setup.

-- ---------------------------------------------------------------- bootstrap

-- Shared invite-redemption logic, used by the auth.users trigger and the
-- redeem_invite() RPC. Returns false when the code is invalid/expired.
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
  select pid, p_user_id, v_invite.invited_by
  from unnest(v_invite.project_ids) as pid
  on conflict do nothing;

  update public.invites
  set redeemed_by = p_user_id, redeemed_at = now()
  where id = v_invite.id;

  return true;
end;
$$;

-- Bootstrap path: signed-up user without a profile founds a company.
create or replace function public.create_company(p_name text, p_full_name text)
returns uuid
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_company_id uuid;
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from public.profiles where id = v_user) then
    raise exception 'user already belongs to a company';
  end if;
  if nullif(trim(p_name), '') is null or nullif(trim(p_full_name), '') is null then
    raise exception 'company name and your name are required';
  end if;

  insert into public.companies (name) values (trim(p_name))
  returning id into v_company_id;

  insert into public.profiles (id, company_id, role, full_name)
  values (v_user, v_company_id, 'owner', trim(p_full_name));

  return v_company_id;
end;
$$;

-- Bootstrap path: signed-up user without a profile joins via invite code.
create or replace function public.redeem_invite(p_code text, p_full_name text default null)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from public.profiles where id = v_user) then
    raise exception 'user already belongs to a company';
  end if;

  return app.apply_invite(
    v_user, p_code,
    coalesce(nullif(trim(p_full_name), ''), 'New member'));
end;
$$;

-- Office mints invite codes server-side (unambiguous alphabet, unique).
-- SECURITY INVOKER: the invites RLS insert policy is the authorization.
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

-- --------------------------------------------------------------- messaging

-- Atomic message + attachments insert. SECURITY INVOKER: messages and
-- attachments RLS policies fully apply. Clients upload files to storage
-- first, then call this with the resulting paths.
create or replace function public.send_message(
  p_project_id uuid,
  p_task_id uuid default null,
  p_kind public.message_kind default 'text',
  p_body text default null,
  p_attachments jsonb default '[]',
  p_shared_with_customer boolean default false,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_message_id uuid;
  v_att jsonb;
begin
  if jsonb_typeof(coalesce(p_attachments, '[]'::jsonb)) <> 'array' then
    raise exception 'p_attachments must be a JSON array';
  end if;

  insert into public.messages
    (company_id, project_id, task_id, sender_id, kind, body, shared_with_customer, expires_at)
  values
    -- company_id placeholder: the sync_message_company trigger derives the
    -- real value from the project before constraints/RLS checks run.
    ('00000000-0000-0000-0000-000000000000', p_project_id, p_task_id,
     (select auth.uid()), p_kind, nullif(trim(p_body), ''), p_shared_with_customer, p_expires_at)
  returning id into v_message_id;

  for v_att in select * from jsonb_array_elements(coalesce(p_attachments, '[]'::jsonb))
  loop
    insert into public.attachments
      (message_id, kind, storage_bucket, storage_path, mime_type,
       byte_size, width, height, duration_seconds, waveform)
    values
      (v_message_id,
       (v_att ->> 'kind')::public.attachment_kind,
       v_att ->> 'storage_bucket',
       v_att ->> 'storage_path',
       v_att ->> 'mime_type',
       (v_att ->> 'byte_size')::bigint,
       (v_att ->> 'width')::int,
       (v_att ->> 'height')::int,
       (v_att ->> 'duration_seconds')::double precision,
       v_att -> 'waveform');
  end loop;

  return v_message_id;
end;
$$;

-- Soft-delete. Must be SECURITY DEFINER: the select policy hides deleted
-- messages, so a plain UPDATE would make the new row invisible to its own
-- writer and fail RLS (PG checks updated rows against select policies).
-- Authorization still happens in enforce_message_update(): only the sender
-- or an office role of the same company passes.
create or replace function public.delete_message(p_message_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'not authenticated';
  end if;

  update public.messages
  set deleted_at = now()
  where id = p_message_id
    and company_id = app.current_company_id()
    and deleted_at is null;

  if not found then
    raise exception 'message not found';
  end if;
end;
$$;

-- ------------------------------------------------------------ maintenance

-- Hard-purge expired disappearing messages (milestone 2: called on a
-- schedule by cleanup-expired-media). Service role only.
create or replace function public.purge_expired_messages()
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  delete from public.messages
  where expires_at is not null and expires_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ------------------------------------------------------------------ grants

-- Definer functions default to EXECUTE for PUBLIC — lock them down.
revoke execute on function public.create_company(text, text) from public, anon;
revoke execute on function public.redeem_invite(text, text) from public, anon;
revoke execute on function public.create_invite(public.app_role, text, uuid[]) from public, anon;
revoke execute on function public.send_message(uuid, uuid, public.message_kind, text, jsonb, boolean, timestamptz) from public, anon;
revoke execute on function public.delete_message(uuid) from public, anon;
revoke execute on function public.purge_expired_messages() from public, anon, authenticated;
revoke execute on function app.apply_invite(uuid, text, text) from public, anon, authenticated;

grant execute on function public.create_company(text, text) to authenticated;
grant execute on function public.redeem_invite(text, text) to authenticated;
grant execute on function public.create_invite(public.app_role, text, uuid[]) to authenticated;
grant execute on function public.send_message(uuid, uuid, public.message_kind, text, jsonb, boolean, timestamptz) to authenticated;
grant execute on function public.delete_message(uuid) to authenticated;

-- ----------------------------------------------------------------- overview

-- Powers the manager grid on iOS and web. security_invoker: every join is
-- RLS-filtered per caller — customers get counts of shared items only.
create view public.project_overview
with (security_invoker = on) as
select
  p.id,
  p.company_id,
  p.name,
  p.address,
  p.status,
  p.customer_display_name,
  p.cover_photo_path,
  p.created_at,
  p.updated_at,
  count(t.id)::int                                          as task_count,
  count(t.id) filter (where t.status = 'todo')::int         as todo_count,
  count(t.id) filter (where t.status = 'in_progress')::int  as in_progress_count,
  count(t.id) filter (where t.status = 'blocked')::int      as blocked_count,
  count(t.id) filter (where t.status = 'done')::int         as done_count,
  count(t.id) filter (where t.status = 'approved')::int     as approved_count,
  (select count(*)::int from public.project_members pm
    where pm.project_id = p.id)                             as member_count,
  greatest(
    p.updated_at,
    max(t.updated_at),
    (select max(m.created_at) from public.messages m where m.project_id = p.id)
  )                                                         as last_activity_at,
  (select a.storage_path
     from public.attachments a
     join public.messages m on m.id = a.message_id
    where m.project_id = p.id and a.kind = 'photo'
    order by a.created_at desc
    limit 1)                                                as latest_photo_path
from public.projects p
left join public.tasks t on t.project_id = p.id
group by p.id;

grant select on public.project_overview to authenticated;

-- ----------------------------------------------------------------- realtime

-- Live chat and live task boards. Delivery of postgres_changes respects RLS.
do $$
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;
end;
$$;

alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.tasks;
