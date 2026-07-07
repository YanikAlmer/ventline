-- RLS + trigger test suite. Runs after migrations + seed on the scratch DB.
-- Every block asserts BOTH what a role can do and what it must not be able
-- to do. Any failure aborts psql (ON_ERROR_STOP).
--
-- Impersonation uses the same mechanism as PostgREST: the request.jwt.claims
-- GUC plus SET ROLE authenticated.

create schema if not exists tests;

create or replace function tests.impersonate(p_user uuid)
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true);
  execute 'set local role authenticated';
end;
$$;

create or replace function tests.reset()
returns void
language plpgsql
as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end;
$$;

grant usage on schema tests to authenticated;
grant execute on function tests.impersonate(uuid), tests.reset() to authenticated;

-- Seed identities --------------------------------------------------------
-- olivia  ..001 owner@Alpine     marcus ..002 manager@Alpine
-- frank   ..003 foreman@Alpine   wanda  ..004 worker@Alpine (Maple)
-- miguel  ..005 worker@Alpine (Depot)
-- carla   ..006 customer@Alpine (Maple)
-- boris   ..007 owner@Baltic     wes    ..008 worker@Baltic (no projects)
-- maple 9000..001 / depot 9000..002
-- tasks: filter a000..001 (maple, customer-visible, assigned wanda)
--        duct   a000..002 (maple, hidden, assigned wanda)
--        therm  a000..003 (depot, assigned miguel)
-- messages: b000..001 shared with customer, b000..002 private (both wanda's)

-- ======================================================== visibility matrix
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  wes    uuid := '00000000-0000-4000-8000-000000000008';
begin
  -- Owner and manager see everything in their company.
  perform tests.impersonate(olivia);
  assert (select count(*) from public.projects) = 2, 'owner sees both projects';
  assert (select count(*) from public.tasks) = 3, 'owner sees all tasks';
  assert (select count(*) from public.profiles) = 6, 'owner sees all company profiles';

  perform tests.impersonate(marcus);
  assert (select count(*) from public.projects) = 2, 'manager sees both projects';
  assert (select count(*) from public.messages) = 2, 'manager sees both messages';
  assert (select count(*) from public.project_overview) = 2, 'manager overview has 2 rows';

  -- Foreman/worker: explicit membership only.
  perform tests.impersonate(frank);
  assert (select count(*) from public.projects) = 1, 'foreman sees only Maple';
  assert (select count(*) from public.tasks) = 2, 'foreman sees Maple tasks';

  perform tests.impersonate(wanda);
  assert (select count(*) from public.projects) = 1, 'worker sees only Maple';
  assert (select count(*) from public.tasks) = 2, 'worker sees Maple tasks';
  assert (select count(*) from public.messages) = 2, 'worker sees Maple messages';
  assert (select count(*) from public.task_assignments where profile_id = wanda) = 2,
    'worker sees own assignments';

  perform tests.impersonate(miguel);
  assert (select count(*) from public.projects) = 1, 'miguel sees only Depot';
  assert (select count(*) from public.messages) = 0, 'miguel sees no Maple messages';

  -- Customer: curated slice of their own project only.
  perform tests.impersonate(carla);
  assert (select count(*) from public.projects) = 1, 'customer sees own project';
  assert (select count(*) from public.tasks) = 1, 'customer sees only customer-visible tasks';
  assert (select count(*) from public.messages) = 1, 'customer sees only shared messages';
  assert (select count(*) from public.project_members) = 0, 'customer cannot see the roster';
  assert (select task_count from public.project_overview) = 1,
    'customer overview counts only visible tasks';

  -- Cross-tenant isolation: Baltic sees nothing of Alpine.
  perform tests.impersonate(boris);
  assert (select count(*) from public.projects) = 0, 'other-company owner sees no projects';
  assert (select count(*) from public.tasks) = 0, 'other-company owner sees no tasks';
  assert (select count(*) from public.messages) = 0, 'other-company owner sees no messages';
  assert (select count(*) from public.profiles) = 2, 'boris sees only Baltic profiles';

  perform tests.impersonate(wes);
  assert (select count(*) from public.projects) = 0, 'unassigned worker sees no projects';

  perform tests.reset();
end;
$$;

-- ================================================== task transitions (RBAC)
do $$
declare
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  t_filter uuid := '00000000-0000-4000-a000-000000000001';
  t_duct   uuid := '00000000-0000-4000-a000-000000000002';
  t_therm  uuid := '00000000-0000-4000-a000-000000000003';
  n int;
  denied boolean;
begin
  -- Worker completes an assigned task; stamps are set by the trigger.
  perform tests.impersonate(wanda);
  update public.tasks set status = 'done' where id = t_filter;
  assert (select completed_by from public.tasks where id = t_filter) = wanda,
    'completed_by stamped with the worker';
  assert (select completed_at from public.tasks where id = t_filter) is not null,
    'completed_at stamped';

  -- Worker cannot forge stamps (trigger overwrites).
  update public.tasks set status = 'in_progress' where id = t_duct;
  update public.tasks set status = 'done', completed_by = miguel where id = t_duct;
  assert (select completed_by from public.tasks where id = t_duct) = wanda,
    'forged completed_by overwritten by trigger';
  update public.tasks set status = 'todo' where id = t_duct;

  -- Worker cannot approve.
  denied := false;
  begin
    update public.tasks set status = 'approved' where id = t_filter;
  exception when others then denied := true;
  end;
  assert denied, 'worker must not approve tasks';

  -- Worker cannot edit task fields.
  denied := false;
  begin
    update public.tasks set title = 'hacked' where id = t_filter;
  exception when others then denied := true;
  end;
  assert denied, 'worker must not edit task title';

  -- Worker cannot touch tasks on projects they are not a member of.
  update public.tasks set status = 'done' where id = t_therm;
  get diagnostics n = row_count;
  assert n = 0, 'worker update outside their projects matches 0 rows';

  -- Foreman approves the done task.
  perform tests.impersonate(frank);
  update public.tasks set status = 'approved' where id = t_filter;
  assert (select approved_by from public.tasks where id = t_filter) = frank,
    'approved_by stamped with the foreman';

  -- Reverting clears approval stamps.
  update public.tasks set status = 'in_progress' where id = t_filter;
  assert (select approved_by from public.tasks where id = t_filter) is null,
    'approval stamps cleared on revert';

  perform tests.reset();
end;
$$;

-- ============================================================ people & roles
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  denied boolean;
begin
  -- Office promotes a worker to foreman (and back).
  perform tests.impersonate(marcus);
  update public.profiles set role = 'foreman' where id = wanda;
  assert (select role from public.profiles where id = wanda) = 'foreman',
    'manager can change roles';
  update public.profiles set role = 'worker' where id = wanda;

  -- Manager cannot mint owners.
  denied := false;
  begin
    update public.profiles set role = 'owner' where id = wanda;
  exception when others then denied := true;
  end;
  assert denied, 'manager must not grant owner role';

  -- Worker cannot change roles at all.
  perform tests.impersonate(wanda);
  denied := false;
  begin
    update public.profiles set role = 'manager' where id = wanda;
  exception when others then denied := true;
  end;
  assert denied, 'worker must not change own role';

  -- Worker can edit own name.
  update public.profiles set full_name = 'Wanda W.' where id = wanda;
  assert (select full_name from public.profiles where id = wanda) = 'Wanda W.',
    'worker edits own name';
  update public.profiles set full_name = 'Wanda Worker' where id = wanda;

  -- Foreman adds a worker to their project; cannot add a manager.
  perform tests.impersonate(frank);
  insert into public.project_members (project_id, profile_id, added_by)
  values (maple, miguel, frank);
  assert (select count(*) from public.project_members
          where project_id = maple and profile_id = miguel) = 1,
    'foreman adds worker to own project';
  delete from public.project_members where project_id = maple and profile_id = miguel;

  denied := false;
  begin
    insert into public.project_members (project_id, profile_id, added_by)
    values (maple, marcus, frank);
  exception when others then denied := true;
  end;
  assert denied, 'foreman must not add non-workers';

  -- Foreman cannot create invites (office only).
  denied := false;
  begin
    perform public.create_invite('worker', 'X', '{}');
  exception when others then denied := true;
  end;
  assert denied, 'foreman must not create invites';

  -- Manager cannot create an owner invite.
  perform tests.impersonate(marcus);
  denied := false;
  begin
    perform public.create_invite('owner', 'X', '{}');
  exception when others then denied := true;
  end;
  assert denied, 'manager must not create owner invites';

  perform tests.reset();
end;
$$;

-- ==================================================== messaging & send_message
do $$
declare
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  t_filter uuid := '00000000-0000-4000-a000-000000000001';
  m_shared  uuid := '00000000-0000-4000-b000-000000000001';
  m_private uuid := '00000000-0000-4000-b000-000000000002';
  v_alpine uuid;
  v_msg uuid;
  n int;
  denied boolean;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;

  -- Worker sends a photo message through the RPC; attachment lands with it.
  perform tests.impersonate(wanda);
  v_msg := public.send_message(
    maple, t_filter, 'photo', 'Filter before/after',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo',
      'storage_bucket', 'photos',
      'storage_path', v_alpine || '/' || maple || '/' || gen_random_uuid() || '/before.jpg',
      'mime_type', 'image/jpeg',
      'byte_size', 123456, 'width', 2048, 'height', 1536)),
    false, null);
  assert (select count(*) from public.attachments where message_id = v_msg) = 1,
    'send_message creates the attachment';
  assert (select company_id from public.messages where id = v_msg) = v_alpine,
    'company_id derived by trigger';

  -- Sender edits own recent message.
  update public.messages set body = 'edited' where id = m_private;
  assert (select edited_at from public.messages where id = m_private) is not null,
    'edit stamps edited_at';

  -- Sender cannot forge sender_id.
  denied := false;
  begin
    perform public.send_message(maple, null, 'text', 'x', '[]', false, null);
    update public.messages set sender_id = miguel where sender_id = wanda and body = 'x';
  exception when others then denied := true;
  end;
  assert denied, 'sender_id must be immutable';

  -- A non-office member who isn't the sender matches 0 rows via USING.
  perform tests.impersonate('00000000-0000-4000-8000-000000000003'); -- frank
  update public.messages set body = 'takeover' where id = m_private;
  assert (select body from public.messages where id = m_private) = 'edited',
    'non-sender member edit must not change body';

  -- Office passes the USING filter but the trigger blocks body edits.
  perform tests.impersonate(marcus);
  denied := false;
  begin
    update public.messages set body = 'takeover' where id = m_private;
  exception when others then denied := true;
  end;
  assert denied, 'office must not edit someone else''s message body';

  -- Customer cannot send messages.
  perform tests.impersonate(carla);
  denied := false;
  begin
    perform public.send_message(maple, null, 'text', 'hi', '[]', false, null);
  exception when others then denied := true;
  end;
  assert denied, 'customer must not send messages';

  -- Customer cannot create tasks.
  denied := false;
  begin
    insert into public.tasks (project_id, company_id, title)
    values (maple, v_alpine, 'customer task');
  exception when others then denied := true;
  end;
  assert denied, 'customer must not create tasks';

  -- A non-sender, non-office member cannot delete.
  perform tests.impersonate('00000000-0000-4000-8000-000000000003'); -- frank
  denied := false;
  begin
    perform public.delete_message(m_private);
  exception when others then denied := true;
  end;
  assert denied, 'foreman must not delete others'' messages';

  -- Office soft-deletes via RPC; message disappears for everyone.
  perform tests.impersonate(marcus);
  perform public.delete_message(m_private);
  perform tests.impersonate(wanda);
  assert (select count(*) from public.messages where id = m_private) = 0,
    'soft-deleted message hidden from members';

  -- Read receipts: reader can record their own read of a visible message.
  insert into public.message_reads (message_id, profile_id) values (m_shared, wanda);
  denied := false;
  begin
    insert into public.message_reads (message_id, profile_id) values (m_shared, miguel);
  exception when others then denied := true;
  end;
  assert denied, 'cannot record reads for someone else';

  perform tests.reset();
end;
$$;

-- ===================================== disappearing messages & media purge
do $$
declare
  wanda uuid := '00000000-0000-4000-8000-000000000004';
  maple uuid := '00000000-0000-4000-9000-000000000001';
  v_alpine uuid;
  v_msg uuid;
  v_purged int;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;

  -- Seed an already-expired message with an attachment (as service role).
  insert into public.messages (company_id, project_id, sender_id, kind, body, expires_at)
  values (v_alpine, maple, wanda, 'text', 'gone soon', now() - interval '1 second')
  returning id into v_msg;
  insert into public.attachments (message_id, kind, storage_bucket, storage_path, mime_type)
  values (v_msg, 'photo', 'photos', v_alpine || '/' || maple || '/x/expired.jpg', 'image/jpeg');

  -- Members never see expired messages.
  perform tests.impersonate(wanda);
  assert (select count(*) from public.messages where id = v_msg) = 0,
    'expired message hidden by RLS';
  assert (select count(*) from public.attachments where message_id = v_msg) = 0,
    'attachment of expired message hidden';

  -- Purge hard-deletes and queues the storage object for cleanup.
  perform tests.reset();
  v_purged := public.purge_expired_messages();
  assert v_purged = 1, 'purge removed exactly the expired message';
  assert (select count(*) from public.media_deletion_queue
          where storage_path like '%expired.jpg') = 1,
    'attachment path queued for storage cleanup';
end;
$$;

-- ============================================================ storage policies
do $$
declare
  wanda uuid := '00000000-0000-4000-8000-000000000004';
  wes   uuid := '00000000-0000-4000-8000-000000000008';
  carla uuid := '00000000-0000-4000-8000-000000000006';
  maple uuid := '00000000-0000-4000-9000-000000000001';
  m_shared  uuid := '00000000-0000-4000-b000-000000000001';
  m_private uuid := '00000000-0000-4000-b000-000000000002';
  v_alpine uuid;
  v_shared_path text;
  v_private_path text;
  denied boolean;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;
  v_shared_path  := v_alpine || '/' || maple || '/' || m_shared || '/shared.jpg';
  v_private_path := v_alpine || '/' || maple || '/' || m_private || '/private.jpg';

  -- Attach files to the shared and (soft-deleted) private messages, plus the
  -- storage objects themselves — setup as service role.
  insert into public.attachments (message_id, kind, storage_bucket, storage_path, mime_type)
  values (m_shared, 'photo', 'photos', v_shared_path, 'image/jpeg'),
         (m_private, 'photo', 'photos', v_private_path, 'image/jpeg');
  insert into storage.objects (bucket_id, name, owner_id)
  values ('photos', v_shared_path, wanda::text),
         ('photos', v_private_path, wanda::text);

  -- Worker uploads under their company/project prefix.
  perform tests.impersonate(wanda);
  insert into storage.objects (bucket_id, name, owner_id)
  values ('photos', v_alpine || '/' || maple || '/up/new.jpg', wanda::text);

  -- ...but not under someone else's company prefix.
  denied := false;
  begin
    insert into storage.objects (bucket_id, name, owner_id)
    values ('photos', gen_random_uuid() || '/' || maple || '/up/evil.jpg', wanda::text);
  exception when others then denied := true;
  end;
  assert denied, 'upload outside own company prefix must fail';

  -- Members read project media.
  assert (select count(*) from storage.objects where name = v_shared_path) = 1,
    'member reads project media';

  -- Foreign workers read nothing.
  perform tests.impersonate(wes);
  assert (select count(*) from storage.objects) = 0,
    'other-company worker reads no objects';

  -- Customer reads only media of messages shared with them.
  perform tests.impersonate(carla);
  assert (select count(*) from storage.objects where name = v_shared_path) = 1,
    'customer reads shared photo';
  assert (select count(*) from storage.objects where name = v_private_path) = 0,
    'customer cannot read unshared photo';

  perform tests.reset();
end;
$$;

-- ================================================= onboarding (RPCs + trigger)
do $$
declare
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  u_founder uuid := '00000000-0000-4000-c000-000000000001';
  u_joiner  uuid := '00000000-0000-4000-c000-000000000002';
  u_meta    uuid := '00000000-0000-4000-c000-000000000003';
  v_code1 text;
  v_code2 text;
  v_company uuid;
begin
  -- Founder path: bare signup, then create_company RPC.
  insert into auth.users (id, email) values (u_founder, 'founder@new.test');
  assert (select count(*) from public.profiles where id = u_founder) = 0,
    'no profile before create_company';
  perform tests.impersonate(u_founder);
  v_company := public.create_company('Founder Co', 'Fiona Founder');
  assert (select role from public.profiles where id = u_founder) = 'owner',
    'create_company makes an owner profile';

  -- Invite path via RPC: manager mints a code, new user redeems it.
  perform tests.impersonate(marcus);
  select code into strict v_code1
  from public.create_invite('worker', 'Willy Welder', array[maple]);
  select code into strict v_code2
  from public.create_invite('worker', null, array[maple]);

  perform tests.reset();
  insert into auth.users (id, email) values (u_joiner, 'willy@new.test');
  perform tests.impersonate(u_joiner);
  assert public.redeem_invite(v_code1, 'Willy'), 'invite code redeems';
  assert (select role from public.profiles where id = u_joiner) = 'worker',
    'redeemed profile has invite role';
  assert (select count(*) from public.project_members
          where profile_id = u_joiner and project_id = maple) = 1,
    'redeemed user auto-joined the invite projects';

  -- Reusing a code fails cleanly (user already has a profile / code spent).
  begin
    perform public.redeem_invite(v_code1, 'Again');
    raise exception 'TEST FAIL: double redemption not blocked';
  exception when others then
    if sqlerrm like 'TEST FAIL%' then raise; end if;
  end;

  -- Signup-metadata path: handle_new_user consumes the code automatically.
  perform tests.reset();
  insert into auth.users (id, email, raw_user_meta_data)
  values (u_meta, 'meta@new.test',
          jsonb_build_object('invite_code', v_code2, 'full_name', 'Meta Mason'));
  assert (select full_name from public.profiles where id = u_meta) = 'Meta Mason',
    'signup metadata invite creates profile via trigger';
  assert (select count(*) from public.project_members
          where profile_id = u_meta and project_id = maple) = 1,
    'trigger path also joins invite projects';
end;
$$;

select 'RLS TESTS PASSED' as result;
