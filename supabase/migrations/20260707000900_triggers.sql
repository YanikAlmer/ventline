-- Triggers: updated_at maintenance, denormalization guards, the rules RLS
-- cannot express (old-vs-new column comparisons), and new-user bootstrap.

create or replace function app.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.profiles
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.projects
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.tasks
  for each row execute function app.set_updated_at();

-- Keep tasks.company_id honest: always derived from the project, never
-- trusted from the client. SECURITY DEFINER so the lookup is never blocked
-- by projects RLS mid-write.
create or replace function app.sync_task_company()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  select p.company_id into strict new.company_id
  from public.projects p where p.id = new.project_id;
  return new;
end;
$$;

create trigger sync_task_company before insert or update of project_id on public.tasks
  for each row execute function app.sync_task_company();

-- Same for messages, plus: a task thread's task must belong to the message's
-- project.
create or replace function app.sync_message_company()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  select p.company_id into strict new.company_id
  from public.projects p where p.id = new.project_id;

  if new.task_id is not null and not exists (
    select 1 from public.tasks t
    where t.id = new.task_id and t.project_id = new.project_id
  ) then
    raise exception 'task % does not belong to project %', new.task_id, new.project_id;
  end if;

  return new;
end;
$$;

create trigger sync_message_company before insert on public.messages
  for each row execute function app.sync_message_company();

-- Profile updates: nobody moves companies; role changes are office-only and
-- involving 'owner' are owner-only.
create or replace function app.enforce_profile_update()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_actor_role public.app_role := app.current_member_role();
begin
  -- Writes not coming through the API (service role, definer RPCs) pass.
  if (select auth.uid()) is null then
    return new;
  end if;

  if new.company_id <> old.company_id then
    raise exception 'company_id is immutable';
  end if;

  if new.role <> old.role then
    if v_actor_role not in ('owner', 'manager') then
      raise exception 'only owners and managers can change roles';
    end if;
    if (new.role = 'owner' or old.role = 'owner') and v_actor_role <> 'owner' then
      raise exception 'only an owner can grant or revoke the owner role';
    end if;
    if old.id = (select auth.uid()) and old.role = 'owner' then
      raise exception 'owners cannot demote themselves';
    end if;
  end if;

  if old.id <> (select auth.uid())
     and v_actor_role not in ('owner', 'manager')
  then
    raise exception 'only owners and managers can edit other profiles';
  end if;

  return new;
end;
$$;

create trigger enforce_profile_update before update on public.profiles
  for each row execute function app.enforce_profile_update();

-- Task updates. Workers: assigned tasks only, status-only changes, no
-- touching 'approved'. Everyone: completion/approval stamps are maintained
-- here so clients cannot forge them.
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

  if v_role = 'worker' then
    if not exists (
      select 1 from public.task_assignments ta
      where ta.task_id = old.id and ta.profile_id = v_actor
    ) then
      raise exception 'workers can only update tasks assigned to them';
    end if;

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

  -- Stamp transitions (all roles; forged values are overwritten).
  if new.status = 'done' and old.status <> 'done' then
    new.completed_by := v_actor;
    new.completed_at := now();
  end if;
  if new.status = 'approved' and old.status <> 'approved' then
    new.approved_by := v_actor;
    new.approved_at := now();
  end if;
  if new.status <> 'approved' then
    new.approved_by := null;
    new.approved_at := null;
  end if;
  if new.status in ('todo', 'in_progress') then
    new.completed_by := null;
    new.completed_at := null;
  end if;

  return new;
end;
$$;

create trigger enforce_task_transition before update on public.tasks
  for each row execute function app.enforce_task_transition();

-- Message updates: core columns are immutable; body edits are sender-only
-- within 15 minutes; soft-delete by sender or office; sharing toggle by
-- sender or office at any time.
create or replace function app.enforce_message_update()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_actor uuid := (select auth.uid());
begin
  if v_actor is null then
    return new;
  end if;

  if new.company_id is distinct from old.company_id
     or new.project_id is distinct from old.project_id
     or new.task_id is distinct from old.task_id
     or new.sender_id is distinct from old.sender_id
     or new.kind is distinct from old.kind
     or new.created_at is distinct from old.created_at
     or new.reply_to_message_id is distinct from old.reply_to_message_id
     or new.expires_at is distinct from old.expires_at
  then
    raise exception 'message core fields are immutable';
  end if;

  if new.body is distinct from old.body then
    if old.sender_id <> v_actor then
      raise exception 'only the sender can edit a message';
    end if;
    if old.created_at < now() - interval '15 minutes' then
      raise exception 'messages can only be edited within 15 minutes';
    end if;
    new.edited_at := now();
  end if;

  if new.deleted_at is distinct from old.deleted_at then
    if old.deleted_at is not null then
      raise exception 'deleted messages cannot be restored';
    end if;
    if old.sender_id <> v_actor and not app.is_office() then
      raise exception 'only the sender or a manager can delete a message';
    end if;
    new.deleted_at := now();
  end if;

  if new.shared_with_customer is distinct from old.shared_with_customer
     and old.sender_id <> v_actor and not app.is_office()
  then
    raise exception 'only the sender or a manager can change customer sharing';
  end if;

  return new;
end;
$$;

create trigger enforce_message_update before update on public.messages
  for each row execute function app.enforce_message_update();

-- Hard-deleted attachments leave storage objects behind; queue them for the
-- cleanup-expired-media function (milestone 2). Fires on cascade deletes
-- from purge_expired_messages().
create or replace function app.enqueue_media_deletion()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  insert into public.media_deletion_queue (storage_bucket, storage_path)
  values (old.storage_bucket, old.storage_path);

  insert into public.media_deletion_queue (storage_bucket, storage_path)
  select 'photos', pa.rendered_path
  from public.photo_annotations pa
  where pa.attachment_id = old.id;

  return old;
end;
$$;

create trigger enqueue_media_deletion before delete on public.attachments
  for each row execute function app.enqueue_media_deletion();

-- New-user bootstrap. Reads signup metadata:
--   { "invite_code": "ABC12345", "full_name": "..." }  -> join via invite
--   { "company_name": "...", "full_name": "..." }      -> new company, owner
-- With neither, no profile is created; the client offers "create company or
-- enter invite code" and calls the create_company()/redeem_invite() RPCs.
create or replace function app.handle_new_user()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_code text := new.raw_user_meta_data ->> 'invite_code';
  v_company_name text := new.raw_user_meta_data ->> 'company_name';
  v_full_name text := coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'New member');
  v_company_id uuid;
begin
  if v_code is not null then
    -- Shared logic with the redeem_invite() RPC (defined in the rpcs
    -- migration; plpgsql resolves it at call time, i.e. at signup).
    -- Invalid/expired code: user is created without a profile; the client
    -- surfaces this and lets them retry via redeem_invite().
    perform app.apply_invite(new.id, v_code, v_full_name);
    return new;
  end if;

  if v_company_name is not null and trim(v_company_name) <> '' then
    insert into public.companies (name) values (trim(v_company_name))
    returning id into v_company_id;

    insert into public.profiles (id, company_id, role, full_name)
    values (new.id, v_company_id, 'owner', v_full_name);
  end if;

  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function app.handle_new_user();
