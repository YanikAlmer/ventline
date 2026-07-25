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

-- ============================ security hardening (20260722120000) regressions
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  depot  uuid := '00000000-0000-4000-9000-000000000002';
  t_duct uuid := '00000000-0000-4000-a000-000000000002';
  u_cust2 uuid := '00000000-0000-4000-c000-000000000010';
  u_inv   uuid := '00000000-0000-4000-c000-000000000011';
  foreign_proj uuid := '00000000-0000-4000-d000-000000000001';
  v_alpine uuid;
  v_baltic uuid;
  v_newtask uuid;
  v_t2 uuid;
  denied boolean;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;
  select company_id into strict v_baltic from public.profiles where id = boris;

  -- Fixtures (service role): a second customer on a different project, and a
  -- foreign-company project for the invite tests.
  insert into auth.users (id, email) values (u_cust2, 'cust2@alpine.test');
  insert into public.profiles (id, company_id, role, full_name)
    values (u_cust2, v_alpine, 'customer', 'Second Customer');
  insert into public.project_members (project_id, profile_id) values (depot, u_cust2);
  insert into public.projects (id, company_id, name) values (foreign_proj, v_baltic, 'Baltic Job');

  -- Fix 1: a customer sees themselves, office, and co-project staff — but NOT
  -- other customers, and NOT staff on unrelated projects.
  perform tests.impersonate(carla);
  assert (select count(*) from public.profiles where id = carla) = 1,
    'customer sees own profile';
  assert (select count(*) from public.profiles where id = frank) = 1,
    'customer sees co-project foreman';
  assert (select count(*) from public.profiles where id = olivia) = 1,
    'customer sees company owner (point of contact)';
  assert (select count(*) from public.profiles where id = marcus) = 1,
    'customer sees company manager';
  assert (select count(*) from public.profiles where id = miguel) = 0,
    'customer must NOT see a worker on a project they do not share';
  assert (select count(*) from public.profiles where id = u_cust2) = 0,
    'customer must NOT see another customer';

  -- Fix 2: create_invite rejects project_ids outside the caller's company.
  perform tests.impersonate(marcus);
  denied := false;
  begin
    perform public.create_invite('worker', 'X', array[foreign_proj]);
  exception when others then denied := true;
  end;
  assert denied, 'create_invite must reject a foreign-company project';

  -- Fix 2: even a hand-crafted invite carrying a foreign project grants no
  -- cross-company membership on redemption (apply_invite filters it out).
  perform tests.reset();
  insert into public.invites (company_id, code, role, project_ids)
    values (v_alpine, 'ZZTESTONE', 'worker', array[foreign_proj]);
  insert into auth.users (id, email) values (u_inv, 'inv@alpine.test');
  perform tests.impersonate(u_inv);
  assert public.redeem_invite('ZZTESTONE', 'Invited User'), 'crafted invite redeems';
  perform tests.reset();
  assert (select company_id from public.profiles where id = u_inv) = v_alpine,
    'redeemer joins the invite company';
  assert (select count(*) from public.project_members
          where profile_id = u_inv and project_id = foreign_proj) = 0,
    'cross-company project membership filtered out on redemption';

  -- Fix 3: a worker cannot INSERT a task pre-set to approved or done.
  perform tests.impersonate(wanda);
  denied := false;
  begin
    insert into public.tasks (project_id, company_id, title, status)
      values (maple, v_alpine, 'sneaky approved', 'approved');
  exception when others then denied := true;
  end;
  assert denied, 'worker must not insert an approved task';

  denied := false;
  begin
    insert into public.tasks (project_id, company_id, title, status)
      values (maple, v_alpine, 'sneaky done', 'done');
  exception when others then denied := true;
  end;
  assert denied, 'worker must not insert a done task';

  -- ...but a normal task insert works and created_by is stamped to the actor.
  insert into public.tasks (project_id, company_id, title)
    values (maple, v_alpine, 'normal worker task') returning id into v_newtask;
  assert (select created_by from public.tasks where id = v_newtask) = wanda,
    'created_by stamped to the actor on insert';

  -- Fix 3: office/foreman CAN insert an approved task, but the stamps are
  -- derived from the actor — client-supplied approved_by/completed_by ignored.
  perform tests.impersonate(frank);
  insert into public.tasks (project_id, company_id, title, status, approved_by, completed_by)
    values (maple, v_alpine, 'pre-approved', 'approved', wanda, miguel)
    returning id into v_t2;
  assert (select approved_by from public.tasks where id = v_t2) = frank,
    'insert approved_by derived to actor, forged value ignored';
  assert (select completed_by from public.tasks where id = v_t2) = frank,
    'insert completed_by derived to actor, forged value ignored';

  -- Fix 4: a worker cannot forge completion stamps on a no-op or ->blocked
  -- update (previously the client value survived when status did not enter done).
  perform tests.impersonate(wanda);
  update public.tasks set status = 'in_progress' where id = t_duct;
  update public.tasks set status = 'done' where id = t_duct;
  assert (select completed_by from public.tasks where id = t_duct) = wanda,
    'done stamps the worker';
  update public.tasks set status = 'done', completed_by = miguel where id = t_duct;
  assert (select completed_by from public.tasks where id = t_duct) = wanda,
    'no-op done update cannot forge completed_by';
  update public.tasks set status = 'blocked', completed_by = miguel where id = t_duct;
  assert (select completed_by from public.tasks where id = t_duct) = wanda,
    '->blocked update preserves the real completed_by, forged value ignored';
  update public.tasks set status = 'todo' where id = t_duct;
  assert (select completed_by from public.tasks where id = t_duct) is null,
    'reopening to todo clears the completion stamp';

  -- Fix 4: a foreman cannot forge approved_by on a stay-approved no-op update.
  perform tests.impersonate(frank);
  update public.tasks set status = 'approved' where id = t_duct;
  assert (select approved_by from public.tasks where id = t_duct) = frank,
    'approval stamps the foreman';
  update public.tasks set status = 'approved', approved_by = wanda where id = t_duct;
  assert (select approved_by from public.tasks where id = t_duct) = frank,
    'no-op approved update cannot forge approved_by';
  update public.tasks set status = 'todo' where id = t_duct;

  perform tests.reset();
end;
$$;

-- ===================== project insert + RETURNING (20260725090000 regression)
-- The clients insert with a RETURNING clause, so the new row must also pass
-- the SELECT policy. This previously failed for every role.
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  v_alpine uuid;
  v_id uuid;
  v_name text;
  denied boolean;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;

  -- Owner creates a project and reads it back in the same statement.
  perform tests.impersonate(olivia);
  insert into public.projects (company_id, name, status)
  values (v_alpine, 'Returning Project', 'active')
  returning id, name into v_id, v_name;
  assert v_name = 'Returning Project', 'insert ... returning must return the new row';
  assert (select count(*) from public.projects where id = v_id) = 1,
    'creator can select the project afterwards';

  -- Office still sees every company project; a non-member worker does not.
  perform tests.impersonate(wanda);
  assert (select count(*) from public.projects where id = v_id) = 0,
    'worker who is not a member cannot see the new project';

  -- Adding the worker as a member grants visibility.
  perform tests.reset();
  insert into public.project_members (project_id, profile_id) values (v_id, wanda);
  perform tests.impersonate(wanda);
  assert (select count(*) from public.projects where id = v_id) = 1,
    'member worker sees the project';

  -- Foreman on Maple still sees Maple (unchanged behaviour).
  perform tests.impersonate(frank);
  assert (select count(*) from public.projects where id = maple) = 1,
    'foreman still sees their project';

  -- Cross-company isolation holds.
  perform tests.impersonate(boris);
  assert (select count(*) from public.projects where id = v_id) = 0,
    'other-company owner cannot see the project';

  -- A worker still cannot create a project (office-only insert).
  perform tests.impersonate(wanda);
  denied := false;
  begin
    insert into public.projects (company_id, name) values (v_alpine, 'Worker Project');
  exception when others then denied := true;
  end;
  assert denied, 'worker must not create projects';

  perform tests.reset();
  delete from public.projects where id = v_id;
end;
$$;

-- ==================================== chat overview (20260726090000) regression
do $$
declare
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  depot  uuid := '00000000-0000-4000-9000-000000000002';
  t_filter uuid := '00000000-0000-4000-a000-000000000001';
  t_therm  uuid := '00000000-0000-4000-a000-000000000003';
  v_proj_msg uuid;
  v_task_msg uuid;
  v_att uuid;
  v_count int;
  denied boolean;
begin
  -- thread_id: project thread keys on project, task thread keys on task.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(maple, null, 'text', 'Projekt-Thread Nachricht');
  v_task_msg := public.send_message(maple, t_filter, 'text', 'Aufgaben-Thread Nachricht');
  perform tests.reset();

  assert (select thread_id from public.messages where id = v_proj_msg) = maple,
    'project-level message threads on the project id';
  assert (select thread_id from public.messages where id = v_task_msg) = t_filter,
    'task message threads on the task id';

  -- thread_state is maintained by trigger, with the newest message as preview.
  assert (select last_message_id from public.thread_state where thread_id = maple) = v_proj_msg,
    'thread_state tracks the newest project message';
  assert (select last_preview from public.thread_state where thread_id = t_filter)
         = 'Aufgaben-Thread Nachricht',
    'thread_state stores a preview of the newest task message';
  assert (select message_count from public.thread_state where thread_id = t_filter) >= 1,
    'thread_state counts messages';

  -- Soft-deleting the newest message must not leave a stale preview behind.
  perform tests.impersonate(wanda);
  v_task_msg := public.send_message(maple, t_filter, 'text', 'Wird gelöscht');
  perform tests.reset();
  assert (select last_preview from public.thread_state where thread_id = t_filter) = 'Wird gelöscht',
    'newest message becomes the preview';
  perform tests.impersonate(marcus);
  perform public.delete_message(v_task_msg);
  perform tests.reset();
  assert (select last_preview from public.thread_state where thread_id = t_filter) <> 'Wird gelöscht',
    'soft delete resyncs the thread preview';

  -- Customers must never see thread_state: last_preview would leak unshared text.
  perform tests.impersonate(carla);
  assert (select count(*) from public.thread_state) = 0,
    'customer sees no thread_state rows';

  -- Cross-company isolation.
  perform tests.impersonate(boris);
  assert (select count(*) from public.thread_state) = 0,
    'other-company owner sees no thread_state rows';

  -- Read cursor + unread. Wanda has read nothing in the depot thread she cannot see;
  -- use the maple project thread she can.
  perform tests.impersonate(frank);
  perform public.mark_thread_read(maple);
  assert (select last_read_at from public.thread_read_state
           where profile_id = frank and thread_id = maple) is not null,
    'mark_thread_read stores a cursor for the caller';

  -- The cursor is private to its owner.
  perform tests.impersonate(wanda);
  assert (select count(*) from public.thread_read_state where profile_id = frank) = 0,
    'read cursors are not visible to other users';

  -- Mentions: a worker may mention a colleague on a shared project.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(
    maple, null, 'text', 'Frank schau dir das an',
    '[]', false, null,
    jsonb_build_array(jsonb_build_object('profile_id', frank, 'start_offset', 0, 'length', 5)));
  perform tests.reset();
  assert (select count(*) from public.message_mentions
           where message_id = v_proj_msg and mentioned_profile_id = frank) = 1,
    'mention is stored with derived scope';
  assert (select project_id from public.message_mentions where message_id = v_proj_msg) = maple,
    'mention scope is derived from the message, not the client';

  -- A customer can never be mentioned.
  perform tests.impersonate(wanda);
  denied := false;
  begin
    perform public.send_message(maple, null, 'text', 'Hallo Carla', '[]', false, null,
      jsonb_build_array(jsonb_build_object('profile_id', carla)));
  exception when others then denied := true;
  end;
  assert denied, 'a customer must not be mentionable';

  -- Nor may someone from another company.
  denied := false;
  begin
    perform public.send_message(maple, null, 'text', 'Hallo Boris', '[]', false, null,
      jsonb_build_array(jsonb_build_object('profile_id', boris)));
  exception when others then denied := true;
  end;
  assert denied, 'a member of another company must not be mentionable';

  -- Opening the thread acknowledges the mention.
  perform tests.impersonate(frank);
  assert (select count(*) from public.message_mentions
           where mentioned_profile_id = frank and acknowledged_at is null) >= 1,
    'mention starts unacknowledged';
  perform public.mark_thread_read(maple);
  assert (select count(*) from public.message_mentions
           where mentioned_profile_id = frank and acknowledged_at is null) = 0,
    'opening the thread clears the mention from the attention list';

  -- References: a task in the same project is fine.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(
    maple, null, 'text', 'Siehe Aufgabe', '[]', false, null, '[]',
    jsonb_build_array(jsonb_build_object('kind', 'task', 'task_id', t_filter)));
  perform tests.reset();
  assert (select count(*) from public.message_refs
           where message_id = v_proj_msg and task_id = t_filter) = 1,
    'task reference is stored';

  -- ...but referencing a task from a different project is rejected outright,
  -- so a reference can never leak a title across project boundaries.
  perform tests.impersonate(marcus);
  denied := false;
  begin
    perform public.send_message(maple, null, 'text', 'Fremde Aufgabe', '[]', false, null, '[]',
      jsonb_build_array(jsonb_build_object('kind', 'task', 'task_id', t_therm)));
  exception when others then denied := true;
  end;
  assert denied, 'referencing a task from another project must fail';

  -- Media flags are set from the attachment, whatever the write path.
  perform tests.impersonate(wanda);
  v_task_msg := public.send_message(
    maple, t_filter, 'photo', 'Mit Foto',
    jsonb_build_array(jsonb_build_object(
      'kind', 'photo', 'storage_bucket', 'photos',
      'storage_path', 'x/y/z/flagged.jpg', 'mime_type', 'image/jpeg')));
  perform tests.reset();
  assert (select has_photo from public.messages where id = v_task_msg),
    'has_photo is set by the attachment trigger';
  assert not (select has_voice from public.messages where id = v_task_msg),
    'has_voice stays false when no voice attachment exists';

  -- German full-text search. NOTE these assertions only mean anything on a UTF8
  -- cluster: under SQL_ASCII the parser splits "Lüftung" into 'l' + 'ftung'.
  -- scripts/pglib.sh pins --encoding=UTF8 for exactly this reason.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(maple, null, 'text', 'Die Lüftung muss noch eingestellt werden');
  perform tests.reset();

  -- unaccent strips the diaeresis: "Lüftung" indexes as "luftung".
  select count(*) into v_count from public.messages
   where id = v_proj_msg
     and search_tsv @@ to_tsquery('public.german_unaccent', 'luftung');
  assert v_count = 1, 'accent-folded search matches (luftung -> Lüftung)';

  -- Typing the umlaut works too.
  select count(*) into v_count from public.messages
   where id = v_proj_msg
     and search_tsv @@ to_tsquery('public.german_unaccent', 'Lüftung');
  assert v_count = 1, 'searching with the umlaut matches';

  -- Documented limitation: unaccent folds ü->u, NOT the German transliteration
  -- ü->ue, so "lueftung" does not match. The search RPC compensates by also
  -- querying a de-transliterated variant; asserted here so the behaviour is
  -- pinned and a future unaccent rules change is caught.
  select count(*) into v_count from public.messages
   where id = v_proj_msg
     and search_tsv @@ to_tsquery('public.german_unaccent', 'lueftung');
  assert v_count = 0, 'ue-transliteration does NOT match via unaccent alone';

  -- Stemming folds plurals, which is what matters for trades vocabulary
  -- (Leitungen/Leitung, Rohre/Rohr, Ventile/Ventil). Snowball is a stemmer and
  -- not a lemmatizer, so a participle like "eingestellt" is NOT reduced to
  -- "einstellen" — do not assert that.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(maple, null, 'text', 'Die Leitungen sind verlegt');
  perform tests.reset();
  select count(*) into v_count from public.messages
   where id = v_proj_msg
     and search_tsv @@ to_tsquery('public.german_unaccent', 'Leitung');
  assert v_count = 1, 'German stemming folds plurals (Leitung matches Leitungen)';

  -- Compounds: a prefix query reaches the head of a compound word.
  perform tests.impersonate(wanda);
  v_proj_msg := public.send_message(maple, null, 'text', 'Das Lüftungsrohr ist undicht');
  perform tests.reset();
  select count(*) into v_count from public.messages
   where id = v_proj_msg
     and search_tsv @@ to_tsquery('public.german_unaccent', 'luftung:*');
  assert v_count = 1, 'prefix query matches the head of a German compound';

  perform tests.reset();
end;
$$;

-- ================================= chat read model (20260726100000) regression
do $$
declare
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  t_filter uuid := '00000000-0000-4000-a000-000000000001';
  v_secret uuid;
  v_shared uuid;
  v_hit uuid;
  v_count int;
begin
  -- Fixtures: one internal message and one shared with the customer.
  perform tests.impersonate(wanda);
  v_secret := public.send_message(maple, null, 'text',
    'Interner Hinweis Kompressor defekt', '[]', false);
  v_shared := public.send_message(maple, null, 'text',
    'Guten Tag, die Lüftung ist fertig montiert', '[]', true);
  perform tests.reset();

  -- ---------------------------------------------------------------- inbox
  perform tests.impersonate(wanda);
  select count(*) into v_count from public.inbox_page();
  assert v_count >= 1, 'inbox_page returns threads for a project member';

  -- Own messages never count as unread.
  select unread_count into v_count from public.inbox_page() where thread_id = maple;
  assert v_count = 0, 'a member does not see their own messages as unread';

  -- Frank has not read the project thread, so Wanda''s messages are unread for him.
  perform tests.impersonate(frank);
  select unread_count into v_count from public.inbox_page() where thread_id = maple;
  assert v_count >= 2, 'unread_count reflects messages from others';
  perform public.mark_thread_read(maple);
  select unread_count into v_count from public.inbox_page() where thread_id = maple;
  assert v_count = 0, 'marking the thread read clears the unread count';

  -- A worker on another project sees no Maple threads.
  perform tests.impersonate(miguel);
  select count(*) into v_count from public.inbox_page() where project_id = maple;
  assert v_count = 0, 'inbox_page hides projects the caller is not a member of';

  -- Customers are excluded from thread_state, so the inbox is empty for them.
  perform tests.impersonate(carla);
  select count(*) into v_count from public.inbox_page();
  assert v_count = 0, 'customer gets no inbox rows (previews would leak)';

  -- Cross-tenant.
  perform tests.impersonate(boris);
  select count(*) into v_count from public.inbox_page();
  assert v_count = 0, 'other-company owner gets no inbox rows';

  -- --------------------------------------------------------------- search
  perform tests.impersonate(wanda);
  select count(*) into v_count from public.search_messages('Kompressor');
  assert v_count = 1, 'search finds an internal message for a member';

  -- THE security case: the customer must not find the internal message, but
  -- must find the one shared with them.
  perform tests.impersonate(carla);
  select count(*) into v_count from public.search_messages('Kompressor');
  assert v_count = 0, 'customer must NOT find an unshared message via search';
  select count(*) into v_count from public.search_messages('montiert');
  assert v_count = 1, 'customer finds a message shared with them';

  -- Cross-tenant search finds nothing.
  perform tests.impersonate(boris);
  select count(*) into v_count from public.search_messages('Kompressor');
  assert v_count = 0, 'other-company owner finds nothing via search';

  -- ue-transliteration: "lueftung" must match "Lüftung" (unaccent alone folds
  -- ue->u only in the fold helper, not in the index).
  perform tests.impersonate(wanda);
  select count(*) into v_count from public.search_messages('lueftung');
  assert v_count >= 1, 'search compensates for the ue transliteration';
  select count(*) into v_count from public.search_messages('Lüftung');
  assert v_count >= 1, 'search matches when the umlaut is typed';

  -- A word genuinely containing "ue" still matches (the fold only ADDS recall).
  v_hit := public.send_message(maple, null, 'text', 'Die Steuerung neu parametriert');
  perform tests.reset();
  perform tests.impersonate(wanda);
  select count(*) into v_count from public.search_messages('Steuerung');
  assert v_count = 1, 'folding ue does not break words that really contain ue';

  -- Filters.
  select count(*) into v_count from public.search_messages(null, array[maple], array[wanda]);
  assert v_count >= 3, 'search filters by project and sender without a query';
  select count(*) into v_count from public.search_messages(null, null, null, null, null, null, true);
  assert v_count >= 0, 'has_photo filter is accepted';

  -- --------------------------------------------------------------- person
  perform tests.impersonate(frank);
  select count(*) into v_count from public.person_messages(wanda, maple, 'from');
  assert v_count >= 3, 'person_messages returns what that person wrote in a project';

  -- Scoping by project is what keeps people straight across projects.
  select count(*) into v_count from public.person_messages(miguel, maple, 'from');
  assert v_count = 0, 'person_messages is scoped to the requested project';

  -- A customer must not be able to mine another person's internal messages.
  -- (The seed already contains one shared message from Wanda, so assert on
  -- content rather than a bare count.)
  perform tests.impersonate(carla);
  select count(*) into v_count from public.person_messages(wanda, maple, 'from')
   where body like 'Interner Hinweis%';
  assert v_count = 0, 'customer must NOT see internal messages in the person lens';
  select count(*) into v_count from public.person_messages(wanda, maple, 'from')
   where body like 'Guten Tag%';
  assert v_count = 1, 'customer does see the message shared with them';

  -- ------------------------------------------------------- jump to context
  perform tests.impersonate(wanda);
  select count(*) into v_count from public.messages_around(v_secret, 5);
  assert v_count >= 1, 'messages_around returns the anchor and its neighbours';

  perform tests.impersonate(carla);
  select count(*) into v_count from public.messages_around(v_secret, 5);
  assert v_count = 0, 'customer cannot pull context around a message they cannot read';

  perform tests.reset();
end;
$$;

-- ================================= push notifications (20260727090000) tests
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  marcus uuid := '00000000-0000-4000-8000-000000000002';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  carla  uuid := '00000000-0000-4000-8000-000000000006';
  boris  uuid := '00000000-0000-4000-8000-000000000007';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  t_filter uuid := '00000000-0000-4000-a000-000000000001';
  v_install uuid := '00000000-0000-4000-e000-000000000001';
  v_msg uuid;
  v_plain uuid;
  v_batch jsonb;
  v_count int;
  denied boolean;
begin
  -- Everyone who should be able to receive needs a device.
  perform tests.reset();
  insert into public.devices (profile_id, install_id, platform, push_token)
  values (frank,  gen_random_uuid(), 'ios', 'tok-frank'),
         (wanda,  gen_random_uuid(), 'ios', 'tok-wanda'),
         (marcus, gen_random_uuid(), 'ios', 'tok-marcus'),
         (olivia, gen_random_uuid(), 'ios', 'tok-olivia'),
         (carla,  gen_random_uuid(), 'ios', 'tok-carla');

  -- ------------------------------------------------------ register_device
  perform tests.impersonate(wanda);
  perform public.register_device(v_install, 'ios', 'tok-handset', 'sandbox', 'de', '0.1.0');
  assert (select profile_id from public.devices where install_id = v_install) = wanda,
    'register_device stores the handset against the caller';

  -- Re-registering the same handset as someone else must move it, or signing
  -- out of one account and into another keeps delivering the first one's chat.
  perform tests.impersonate(miguel);
  perform public.register_device(v_install, 'ios', 'tok-handset', 'sandbox', 'de', '0.1.0');
  assert (select profile_id from public.devices where install_id = v_install) = miguel,
    'register_device reassigns a handset to the new signed-in profile';
  assert (select count(*) from public.devices where install_id = v_install) = 1,
    'a handset never ends up registered twice';
  perform tests.reset();
  delete from public.devices where install_id = v_install;

  -- ---------------------------------------------------------- enqueueing
  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'Kompressor läuft wieder');
  perform tests.reset();
  assert (select count(*) from public.notification_outbox
           where message_id = v_msg and kind = 'chat_message') = 1,
    'a chat message enqueues exactly one outbox row';

  -- System rows would duplicate the task_status push for the same event.
  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, t_filter, 'system', 'marked the task as done');
  perform tests.reset();
  assert (select count(*) from public.notification_outbox where message_id = v_msg) = 0,
    'system messages do not enqueue a notification';

  -- Mentions enqueue with the mentioned person as the explicit target.
  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'Frank bitte pruefen', '[]', false, null,
    jsonb_build_array(jsonb_build_object('profile_id', frank)));
  perform tests.reset();
  assert (select count(*) from public.notification_outbox
           where message_id = v_msg and kind = 'mention' and target_id = frank) = 1,
    'a mention enqueues a targeted notification';

  -- --------------------------------------------- recipient resolution
  -- The actor is never notified about their own action.
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, null)
  where profile_id = wanda;
  assert v_count = 0, 'the actor is never a recipient of their own message';

  -- THE security case: a customer must never be in an internal audience, even
  -- though carla is a member of Maple and has a device.
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, null)
  where profile_id = carla;
  assert v_count = 0, 'a customer is NEVER an internal notification recipient';

  -- A member of the project does get plain chat. Use a message WITHOUT a
  -- mention: someone who was mentioned is deliberately dropped from the chat
  -- audience so the same message does not arrive twice (see below).
  perform tests.impersonate(wanda);
  v_plain := public.send_message(maple, null, 'text', 'Ganz normale Nachricht');
  perform tests.reset();
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_plain, wanda, null)
  where profile_id = frank;
  assert v_count = 1, 'a project member receives project chat';

  -- A mention must not produce two pushes: the mention row carries it, so the
  -- chat_message row drops that person from its audience.
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, null)
  where profile_id = frank;
  assert v_count = 0, 'a mentioned person is dropped from the chat audience';
  select count(*) into v_count
  from app.notification_recipients('mention', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, frank)
  where profile_id = frank;
  assert v_count = 1, 'the mention itself still reaches them exactly once';

  -- Someone from another company never appears.
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, null)
  where profile_id = boris;
  assert v_count = 0, 'another company is never in the audience';

  -- Muting a project removes you from its audience.
  insert into public.project_notification_mutes (profile_id, project_id)
  values (frank, maple);
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_plain, wanda, null)
  where profile_id = frank;
  assert v_count = 0, 'muting a project removes you from its audience';
  delete from public.project_notification_mutes where profile_id = frank;

  -- Turning chat notifications off removes you too, without affecting mentions.
  update public.notification_prefs set chat_enabled = false where profile_id = frank;
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_plain, wanda, null)
  where profile_id = frank;
  assert v_count = 0, 'chat_enabled = false silences chat pushes';
  select count(*) into v_count
  from app.notification_recipients('mention', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_msg, wanda, frank)
  where profile_id = frank;
  assert v_count = 1, 'a mention still arrives when chat pushes are off';
  update public.notification_prefs set chat_enabled = true where profile_id = frank;

  -- Quiet hours mark the push passive; they never drop it.
  update public.notification_prefs
     set quiet_hours_enabled = true, quiet_hours_start = '00:00', quiet_hours_end = '23:59',
         time_zone = 'Europe/Zurich'
   where profile_id = frank;
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_plain, wanda, null)
  where profile_id = frank and passive;
  assert v_count = 1, 'quiet hours mark a recipient passive rather than removing them';
  update public.notification_prefs
     set quiet_hours_start = '21:00', quiet_hours_end = '06:00' where profile_id = frank;

  -- No device means nowhere to deliver.
  delete from public.devices where profile_id = frank;
  select count(*) into v_count
  from app.notification_recipients('chat_message', (select company_id from public.profiles where id = wanda),
                                   maple, null, v_plain, wanda, null)
  where profile_id = frank;
  assert v_count = 0, 'a profile with no device is not a recipient';
  insert into public.devices (profile_id, install_id, platform, push_token)
  values (frank, gen_random_uuid(), 'ios', 'tok-frank-2');

  -- --------------------------------------------------- claim and settle
  v_batch := public.claim_notification_batch(100);
  assert jsonb_typeof(v_batch) = 'array', 'claim returns a JSON array';
  assert (select count(*) from public.notification_outbox where status = 'pending') = 0,
    'claiming moves every due row out of pending';

  -- A batch never contains a customer.
  select count(*) into v_count
  from jsonb_array_elements(v_batch) e
  where (e ->> 'profile_id')::uuid = carla;
  assert v_count = 0, 'a claimed batch never targets a customer';

  -- Settling as delivered finishes the rows.
  perform public.settle_notification_batch(
    (select coalesce(jsonb_agg(jsonb_build_object(
       'id', e -> 'id', 'device_id', e -> 'device_id', 'ok', true, 'retryable', false)), '[]'::jsonb)
     from jsonb_array_elements(v_batch) e));
  assert (select count(*) from public.notification_outbox where status = 'sending') = 0,
    'settling clears the sending state';

  -- A 410 from APNs prunes the token so we stop pushing to a dead handset.
  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'Noch eine Nachricht');
  perform tests.reset();
  v_batch := public.claim_notification_batch(100);
  perform public.settle_notification_batch(
    (select coalesce(jsonb_agg(jsonb_build_object(
       'id', e -> 'id', 'device_id', e -> 'device_id',
       'ok', false, 'retryable', false, 'prune', true)), '[]'::jsonb)
     from jsonb_array_elements(v_batch) e
     where (e ->> 'profile_id')::uuid = marcus));
  assert (select count(*) from public.devices where profile_id = marcus) = 0,
    'a 410 prunes the dead token';

  -- The outbox is service-role only: no client may read who is being notified.
  perform tests.impersonate(olivia);
  denied := false;
  begin
    perform 1 from public.notification_outbox limit 1;
  exception when others then denied := true;
  end;
  assert denied, 'even an owner cannot read the notification outbox';

  perform tests.reset();
end;
$$;

-- ============================== push hardening (20260727120000) regressions
do $$
declare
  olivia uuid := '00000000-0000-4000-8000-000000000001';
  frank  uuid := '00000000-0000-4000-8000-000000000003';
  wanda  uuid := '00000000-0000-4000-8000-000000000004';
  miguel uuid := '00000000-0000-4000-8000-000000000005';
  maple  uuid := '00000000-0000-4000-9000-000000000001';
  t_duct uuid := '00000000-0000-4000-a000-000000000002';
  v_alpine uuid;
  v_install uuid := '00000000-0000-4000-e000-000000000009';
  v_msg uuid;
  v_count int;
  denied boolean;
begin
  select company_id into strict v_alpine from public.profiles where id = wanda;

  -- ---------------------------------------------------- timezone poisoning
  -- One bad string used to abort claim_notification_batch for EVERY tenant,
  -- because `at time zone` raises on an unknown identifier.
  assert app.in_quiet_hours('Europe/Zuerich', '21:00', '06:00') is not null,
    'an unknown timezone must fall back rather than throw';
  assert app.in_quiet_hours('', '21:00', '06:00') is not null,
    'an empty timezone must fall back rather than throw';

  -- ...and it can no longer be stored in the first place.
  perform tests.impersonate(frank);
  denied := false;
  begin
    update public.notification_prefs set time_zone = 'Europe/Zuerich' where profile_id = frank;
  exception when others then denied := true;
  end;
  assert denied, 'an invalid timezone is rejected at write time';
  perform tests.reset();

  -- Defence in depth: a row written BEFORE the validation trigger existed
  -- would still be poisoned, so the drain must survive one regardless. Bypass
  -- the trigger to simulate exactly that legacy row.
  alter table public.notification_prefs disable trigger validate_notification_prefs;
  update public.notification_prefs set time_zone = 'Nowhere/Atlantis' where profile_id = frank;
  alter table public.notification_prefs enable trigger validate_notification_prefs;
  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'Drain trotz kaputter Zeitzone');
  perform tests.reset();
  assert public.claim_notification_batch(100) is not null,
    'the drain survives a profile carrying an unusable timezone';
  alter table public.notification_prefs disable trigger validate_notification_prefs;
  update public.notification_prefs set time_zone = 'Europe/Zurich' where profile_id = frank;
  alter table public.notification_prefs enable trigger validate_notification_prefs;

  -- --------------------------------------------- task visibility (leak fix)
  -- Removing somebody from a project leaves their task_assignments row behind.
  -- Task notifications carry no message_id, so the membership check used to be
  -- skipped entirely and the task title reached a lock screen anyway.
  insert into public.devices (profile_id, install_id, platform, push_token)
  values (miguel, gen_random_uuid(), 'ios', 'tok-miguel-leak')
  on conflict do nothing;
  insert into public.task_assignments (task_id, profile_id) values (t_duct, miguel)
  on conflict do nothing;

  -- Miguel is on Depot, not Maple; t_duct is a Maple task.
  assert not app.can_profile_read_task(miguel, t_duct),
    'a non-member cannot read a task on a project they are not on';
  select count(*) into v_count
  from app.notification_recipients('task_status', v_alpine, maple, t_duct, null, wanda, null)
  where profile_id = miguel;
  assert v_count = 0,
    'a stale task assignment does not leak the task to a non-member';

  -- A real member of the project does still get it.
  select count(*) into v_count
  from app.notification_recipients('task_status', v_alpine, maple, t_duct, null, wanda, null)
  where profile_id = frank;
  assert v_count = 1, 'a project member still receives task notifications';

  delete from public.task_assignments where task_id = t_duct and profile_id = miguel;
  delete from public.devices where push_token = 'tok-miguel-leak';

  -- ----------------------------------------------------------- attribution
  -- assigned_by is client-writable and became the push actor, so it could be
  -- used to put someone else's name on a lock screen, or to silence the push
  -- entirely by naming the recipient (the actor is never notified).
  perform tests.impersonate(frank);
  insert into public.task_assignments (task_id, profile_id, assigned_by)
  values (t_duct, miguel, miguel);
  perform tests.reset();
  assert (select assigned_by from public.task_assignments
           where task_id = t_duct and profile_id = miguel) = frank,
    'assigned_by is forced to the actual actor, not the client value';
  delete from public.task_assignments where task_id = t_duct and profile_id = miguel;

  -- ------------------------------------------------------------ thread mute
  insert into public.devices (profile_id, install_id, platform, push_token)
  values (frank, gen_random_uuid(), 'ios', 'tok-frank-mute')
  on conflict do nothing;
  insert into public.thread_read_state (profile_id, thread_id, muted)
  values (frank, maple, true)
  on conflict (profile_id, thread_id) do update set muted = true;

  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'In stummem Thread');
  perform tests.reset();
  select count(*) into v_count
  from app.notification_recipients('chat_message', v_alpine, maple, null, v_msg, wanda, null)
  where profile_id = frank;
  assert v_count = 0, 'muting a thread silences its chat pushes';

  -- ...but a task assignment still breaks through: it is directed at you.
  select count(*) into v_count
  from app.notification_recipients('task_assigned', v_alpine, maple, t_duct, null, wanda, frank)
  where profile_id = frank;
  assert v_count = 1, 'a direct assignment still reaches a muted thread';

  update public.thread_read_state set muted = false
   where profile_id = frank and thread_id = maple;

  -- ------------------------------------------------------------ badge count
  -- Owners read every project through their role, not a project_members row.
  -- The old inner join returned 0 for them, wiping the app icon badge.
  perform tests.impersonate(wanda);
  perform public.send_message(maple, null, 'text', 'Zaehlt fuer den Inhaber');
  perform tests.reset();
  assert app.unread_count(olivia) > 0,
    'an owner without an explicit membership row still gets a real badge';

  -- ------------------------------------------------- device re-registration
  -- A reinstall produces a new install_id for an unchanged token; that used to
  -- raise a unique violation on the legacy (profile_id, push_token) key.
  perform tests.impersonate(wanda);
  perform public.register_device(v_install, 'ios', 'tok-reinstall', 'sandbox', 'de', '0.1.0');
  perform public.register_device(gen_random_uuid(), 'ios', 'tok-reinstall', 'sandbox', 'de', '0.2.0');
  perform tests.reset();
  assert (select count(*) from public.devices where push_token = 'tok-reinstall') = 1,
    'reinstalling with the same token leaves exactly one device row';
  delete from public.devices where push_token = 'tok-reinstall';

  -- ------------------------------------------------ per-device retry safety
  -- A retryable failure on one handset must not re-push to handsets that
  -- already received it.
  perform tests.reset();
  delete from public.notification_deliveries;
  update public.notification_outbox set status = 'skipped', processed_at = now()
   where status in ('pending', 'sending');

  perform tests.impersonate(wanda);
  v_msg := public.send_message(maple, null, 'text', 'Teilweiser Fehlschlag');
  perform tests.reset();

  declare v_batch jsonb; v_first jsonb;
  begin
    v_batch := public.claim_notification_batch(100);
    assert jsonb_array_length(v_batch) >= 1, 'the batch has at least one device';
    v_first := v_batch -> 0;
    -- One device succeeded, and the row is marked retryable overall.
    perform public.settle_notification_batch(jsonb_build_array(
      jsonb_build_object('id', v_first -> 'id', 'device_id', v_first -> 'device_id',
                         'ok', true, 'retryable', false),
      jsonb_build_object('id', v_first -> 'id', 'device_id', v_first -> 'device_id',
                         'ok', false, 'retryable', true, 'error', 'simulated 503')));
    assert (select count(*) from public.notification_deliveries
             where device_id = (v_first ->> 'device_id')::uuid) = 1,
      'a successful delivery is recorded per device';

    -- The retry must now exclude that handset.
    update public.notification_outbox set status = 'pending', next_attempt_at = now()
     where id = (v_first ->> 'id')::uuid;
    v_batch := public.claim_notification_batch(100);
    select count(*) into v_count from jsonb_array_elements(v_batch) e
     where (e ->> 'device_id')::uuid = (v_first ->> 'device_id')::uuid;
    assert v_count = 0, 'a retry does not re-push to a handset that already got it';
  end;

  perform tests.reset();
end;
$$;

select 'RLS TESTS PASSED' as result;
