-- Row Level Security. Default deny: enabling RLS with no matching policy
-- blocks everything; each policy below opens one deliberate path.
--
-- Column-level rules that RLS cannot express (old-vs-new comparisons, e.g.
-- "workers may only change task status") live in the triggers migration.

alter table public.companies            enable row level security;
alter table public.profiles             enable row level security;
alter table public.invites              enable row level security;
alter table public.projects             enable row level security;
alter table public.project_members      enable row level security;
alter table public.tasks                enable row level security;
alter table public.task_assignments     enable row level security;
alter table public.messages             enable row level security;
alter table public.attachments          enable row level security;
alter table public.photo_annotations    enable row level security;
alter table public.message_reads        enable row level security;
alter table public.devices              enable row level security;
alter table public.media_deletion_queue enable row level security;
-- media_deletion_queue: no policies and no grants => service role only.

-- ---------------------------------------------------------------- companies

create policy companies_select on public.companies
  for select to authenticated
  using (id = app.current_company_id());

create policy companies_update_owner on public.companies
  for update to authenticated
  using (id = app.current_company_id() and app.current_member_role() = 'owner')
  with check (id = app.current_company_id());

-- insert/delete: only via create_company() RPC (definer) / service role.

-- ----------------------------------------------------------------- profiles

create policy profiles_select_same_company on public.profiles
  for select to authenticated
  using (company_id = app.current_company_id());

-- Self-edit (name/phone/avatar) or office managing people. Which columns may
-- change is enforced by enforce_profile_update() trigger.
create policy profiles_update on public.profiles
  for update to authenticated
  using (
    id = (select auth.uid())
    or (app.is_office() and company_id = app.current_company_id())
  )
  with check (company_id = app.current_company_id());

-- insert: only via handle_new_user() trigger / RPCs (definer).
-- delete: admin/service-role territory (cascade from auth.users).

-- ------------------------------------------------------------------ invites

create policy invites_select_office on public.invites
  for select to authenticated
  using (app.is_office() and company_id = app.current_company_id());

-- Managers cannot mint owner invites; only owners can.
create policy invites_insert_office on public.invites
  for insert to authenticated
  with check (
    app.is_office()
    and company_id = app.current_company_id()
    and (role <> 'owner' or app.current_member_role() = 'owner')
    and redeemed_by is null
    and redeemed_at is null
  );

create policy invites_delete_office on public.invites
  for delete to authenticated
  using (app.is_office() and company_id = app.current_company_id());

-- update: redemption happens inside redeem_invite() (definer).

-- ----------------------------------------------------------------- projects

create policy projects_select_member on public.projects
  for select to authenticated
  using (app.is_member_of_project(id));

create policy projects_insert_office on public.projects
  for insert to authenticated
  with check (app.is_office() and company_id = app.current_company_id());

create policy projects_update on public.projects
  for update to authenticated
  using (
    (app.is_office() and company_id = app.current_company_id())
    or (app.current_member_role() = 'foreman' and app.is_member_of_project(id))
  )
  with check (company_id = app.current_company_id());

create policy projects_delete_owner on public.projects
  for delete to authenticated
  using (app.current_member_role() = 'owner' and company_id = app.current_company_id());

-- ---------------------------------------------------------- project_members

-- The roster is visible to working members (not customers).
create policy project_members_select on public.project_members
  for select to authenticated
  using (app.can_write_project(project_id));

-- Office adds anyone in the company; a foreman may add workers to their own
-- projects.
create policy project_members_insert on public.project_members
  for insert to authenticated
  with check (
    exists (
      select 1 from public.profiles pr
      where pr.id = profile_id and pr.company_id = app.current_company_id()
    )
    and (
      (app.is_office() and app.is_member_of_project(project_id))
      or (
        app.current_member_role() = 'foreman'
        and app.is_member_of_project(project_id)
        and exists (
          select 1 from public.profiles pr
          where pr.id = profile_id and pr.role = 'worker'
        )
      )
    )
  );

create policy project_members_delete on public.project_members
  for delete to authenticated
  using (
    (app.is_office() and app.is_member_of_project(project_id))
    or (
      app.current_member_role() = 'foreman'
      and app.is_member_of_project(project_id)
      and exists (
        select 1 from public.profiles pr
        where pr.id = profile_id and pr.role = 'worker'
      )
    )
  );

-- -------------------------------------------------------------------- tasks

-- Working members see all tasks; customers only curated ones.
create policy tasks_select on public.tasks
  for select to authenticated
  using (
    app.is_member_of_project(project_id)
    and (app.current_member_role() <> 'customer' or visible_to_customer)
  );

create policy tasks_insert on public.tasks
  for insert to authenticated
  with check (
    app.can_write_project(project_id)
    and company_id = app.current_company_id()
  );

-- Workers are further restricted (assigned tasks, status-only changes) by
-- the enforce_task_transition() trigger.
create policy tasks_update on public.tasks
  for update to authenticated
  using (app.can_write_project(project_id))
  with check (
    app.can_write_project(project_id)
    and company_id = app.current_company_id()
  );

create policy tasks_delete on public.tasks
  for delete to authenticated
  using (
    (app.is_office() and company_id = app.current_company_id())
    or (app.current_member_role() = 'foreman' and app.is_member_of_project(project_id))
  );

-- --------------------------------------------------------- task_assignments

create policy task_assignments_select on public.task_assignments
  for select to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_id and app.is_member_of_project(t.project_id)
    )
    and app.current_member_role() <> 'customer'
  );

-- Foremen and office assign; workers may self-assign (grab an open task).
create policy task_assignments_insert on public.task_assignments
  for insert to authenticated
  with check (
    exists (
      select 1 from public.tasks t
      where t.id = task_id and app.can_write_project(t.project_id)
    )
    and (
      app.is_office()
      or app.current_member_role() = 'foreman'
      or profile_id = (select auth.uid())
    )
    and exists (
      select 1 from public.profiles pr
      where pr.id = profile_id
        and pr.company_id = app.current_company_id()
        and pr.role <> 'customer'
    )
  );

create policy task_assignments_delete on public.task_assignments
  for delete to authenticated
  using (
    exists (
      select 1 from public.tasks t
      where t.id = task_id and app.can_write_project(t.project_id)
    )
    and (
      app.is_office()
      or app.current_member_role() = 'foreman'
      or profile_id = (select auth.uid())
    )
  );

-- ----------------------------------------------------------------- messages

create policy messages_select on public.messages
  for select to authenticated
  using (
    app.is_member_of_project(project_id)
    and deleted_at is null
    and (expires_at is null or expires_at > now())
    and (app.current_member_role() <> 'customer' or shared_with_customer)
  );

create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    app.can_write_project(project_id)
    and sender_id = (select auth.uid())
    and company_id = app.current_company_id()
    and deleted_at is null
  );

-- Sender edits their message; office moderates. What may actually change
-- (edit window, immutable columns, who may soft-delete) is enforced by the
-- enforce_message_update() trigger.
create policy messages_update on public.messages
  for update to authenticated
  using (
    (sender_id = (select auth.uid()) and app.can_write_project(project_id))
    or (app.is_office() and company_id = app.current_company_id())
  )
  with check (company_id = app.current_company_id());

-- delete: no policy — hard deletes only via purge (service role).

-- -------------------------------------------------------------- attachments

create policy attachments_select on public.attachments
  for select to authenticated
  using (app.can_read_message(message_id));

create policy attachments_insert on public.attachments
  for insert to authenticated
  with check (
    exists (
      select 1 from public.messages m
      where m.id = message_id and m.sender_id = (select auth.uid())
    )
  );

--.......................................................... photo_annotations

create policy photo_annotations_select on public.photo_annotations
  for select to authenticated
  using (
    exists (
      select 1 from public.attachments a
      where a.id = attachment_id and app.can_read_message(a.message_id)
    )
  );

create policy photo_annotations_insert on public.photo_annotations
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and app.current_member_role() <> 'customer'
    and exists (
      select 1 from public.attachments a
      where a.id = attachment_id
        and a.kind = 'photo'
        and app.can_read_message(a.message_id)
    )
  );

-- ------------------------------------------------------------ message_reads

create policy message_reads_select on public.message_reads
  for select to authenticated
  using (
    profile_id = (select auth.uid())
    or (
      app.is_office()
      and exists (
        select 1 from public.messages m
        where m.id = message_id and m.company_id = app.current_company_id()
      )
    )
  );

create policy message_reads_insert on public.message_reads
  for insert to authenticated
  with check (
    profile_id = (select auth.uid())
    and app.can_read_message(message_id)
  );

-- ------------------------------------------------------------------- devices

create policy devices_all_self on public.devices
  for all to authenticated
  using (profile_id = (select auth.uid()))
  with check (profile_id = (select auth.uid()));
