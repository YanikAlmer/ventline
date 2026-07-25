-- Task hierarchy (Arbeitspaket / Arbeitsschritt) and attachments that belong to
-- the work rather than to a chat message.
--
-- Naming, fixed here and used verbatim in both clients:
--   parent  = Arbeitspaket (short: Paket)   EN: work package
--   child   = Arbeitsschritt (short: Schritt) EN: step
-- "Position" is deliberately left unused — it is the invoice line item.
--
-- Additive by construction: every existing row becomes a work package with
-- parent_id = null, so no data migration and no changed meaning for anything
-- that already counts tasks.

-- ============================================== 1. the two new task columns
-- Both added up front, because the structural trigger below reads them.
alter table public.tasks
  add column parent_id uuid references public.tasks (id) on delete cascade,
  -- A date alone cannot express "Kundentermin 08:00", and a reminder that only
  -- knows the day can only ever fire at a fixed hour. Kept as a separate
  -- `time` rather than widening due_date to timestamptz: "due end of day"
  -- means end of day in Zurich, and a timestamptz would force that to be
  -- pinned at write time by whichever device happened to create the task.
  add column due_time time,
  add constraint tasks_due_time_needs_date
    check (due_time is null or due_date is not null);

comment on column public.tasks.parent_id is
  'Null = Arbeitspaket (work package). Set = Arbeitsschritt (step) of that package. Exactly two levels.';

-- The board reads "packages of this project, in order" and then "steps of this
-- package, in order"; both are covered here.
create index tasks_project_parent_sort_idx
  on public.tasks (project_id, parent_id, sort_order);
create index tasks_parent_idx
  on public.tasks (parent_id) where parent_id is not null;

-- ============================================== 2. structural rules (trigger)
-- A check constraint cannot see the parent row, so the shape of the tree is a
-- trigger. SECURITY DEFINER: the parent lookup must not be filtered by the
-- tasks policy mid-write, or re-parenting under a package the writer cannot
-- currently SELECT would report "parent does not exist" instead of the truth.
create or replace function app.enforce_task_hierarchy()
returns trigger
language plpgsql security definer
set search_path = ''
as $$
declare
  v_parent public.tasks%rowtype;
begin
  -- The worker denylist for the two columns this migration adds lives here
  -- rather than in enforce_task_transition(). That function has been rewritten
  -- whole twice already; restating it a third time to append two lines is how
  -- a stale copy silently reverts an earlier fix. Each migration guards its
  -- own columns. Wording matches so the client sees one message either way.
  if tg_op = 'UPDATE'
     and (select auth.uid()) is not null
     and app.current_member_role() = 'worker'
     and (new.parent_id is distinct from old.parent_id
          or new.due_time is distinct from old.due_time)
  then
    raise exception 'workers can only change task status';
  end if;

  -- project_id is immutable, for everyone.
  --
  -- The hierarchy rule alone would only need "a step cannot move project", but
  -- moving ANY task between projects was already unsound: its chat thread
  -- (messages.project_id, thread_id) stays behind, so the task and its own
  -- history would answer to two different projects' visibility rules. Nothing
  -- in either client offers the operation. Closing it here means "parent and
  -- child share a project" holds forever rather than being re-checked.
  if tg_op = 'UPDATE' and new.project_id is distinct from old.project_id then
    raise exception 'a task cannot be moved to another project'
      using errcode = 'check_violation';
  end if;

  if new.parent_id is null then
    return new;
  end if;

  if new.parent_id = new.id then
    raise exception 'a task cannot be its own work package'
      using errcode = 'check_violation';
  end if;

  select * into v_parent from public.tasks where id = new.parent_id;
  if not found then
    raise exception 'work package % does not exist', new.parent_id
      using errcode = 'foreign_key_violation';
  end if;

  if v_parent.project_id <> new.project_id then
    raise exception 'a step must belong to the same project as its work package'
      using errcode = 'check_violation';
  end if;

  -- Two levels, from both directions: the parent must be a root, and a task
  -- that already has steps cannot itself become one.
  if v_parent.parent_id is not null then
    raise exception 'steps cannot have steps of their own'
      using errcode = 'check_violation';
  end if;

  if exists (select 1 from public.tasks c where c.parent_id = new.id) then
    raise exception 'a work package with steps cannot become a step'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger enforce_task_hierarchy before insert or update on public.tasks
  for each row execute function app.enforce_task_hierarchy();

-- ======================================= 3. effective customer visibility
-- A step is visible to a customer only if its package is too. Without this,
-- hiding a package from the portal would leave its steps on display — the
-- customer would see the work items of something they are not supposed to
-- know about.
--
-- SECURITY DEFINER is load-bearing: a subquery against public.tasks inside a
-- policy on public.tasks recurses. Definer reads the parent directly.
create or replace function app.package_visible_to_customer(p_parent_id uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select p_parent_id is null
      or exists (
        select 1 from public.tasks t
        where t.id = p_parent_id and t.visible_to_customer
      );
$$;

grant execute on function app.package_visible_to_customer(uuid) to authenticated;

drop policy tasks_select on public.tasks;
create policy tasks_select on public.tasks
  for select to authenticated
  using (
    app.is_member_of_project(project_id)
    and (
      app.current_member_role() <> 'customer'
      or (visible_to_customer and app.package_visible_to_customer(parent_id))
    )
  );

-- Same rule for the push audience, which resolves visibility for a named
-- profile rather than the caller. One definition of "may this person see this
-- task" is the point; this is the second half of it.
create or replace function app.can_profile_read_task(p_profile_id uuid, p_task_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.tasks t
    join public.profiles pr on pr.id = p_profile_id
    where t.id = p_task_id
      and pr.company_id = t.company_id
      and (
        exists (select 1 from public.project_members pm
                 where pm.project_id = t.project_id and pm.profile_id = pr.id)
        or pr.role in ('owner', 'manager')
      )
      and (
        pr.role <> 'customer'
        or (t.visible_to_customer and app.package_visible_to_customer(t.parent_id))
      )
  );
$$;

-- The caller-scoped form, defined in terms of the profile-scoped one so the
-- two can never drift.
create or replace function app.can_read_task(p_task_id uuid)
returns boolean language sql stable set search_path = '' as $$
  select app.can_profile_read_task((select auth.uid()), p_task_id);
$$;

create or replace function app.can_write_task(p_task_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.tasks t
    where t.id = p_task_id and app.can_write_project(t.project_id)
  );
$$;

grant execute on function
  app.can_read_task(uuid),
  app.can_write_task(uuid)
to authenticated;

-- ================================================ 4. attachments on tasks
-- An attachment now belongs to exactly one of: a chat message (as before), or
-- a task. The plan photo for "Kondensatpumpe montieren" belongs to the step,
-- not to whichever conversation it was first pasted into.
alter table public.attachments
  alter column message_id drop not null,
  add column task_id uuid references public.tasks (id) on delete cascade,
  add column uploaded_by uuid references public.profiles (id) on delete set null,
  add column caption text,
  add constraint attachments_single_owner
    check (num_nonnulls(message_id, task_id) = 1);

create index attachments_task_idx
  on public.attachments (task_id, created_at desc) where task_id is not null;

-- A message attachment has messages.sender_id; a task attachment has nobody,
-- so record the uploader. Server-derived, like every other stamp.
create or replace function app.stamp_attachment_uploader()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select auth.uid()) is not null then
    new.uploaded_by := (select auth.uid());
  end if;
  return new;
end; $$;

create trigger stamp_attachment_uploader before insert on public.attachments
  for each row execute function app.stamp_attachment_uploader();

grant delete on public.attachments to authenticated;

-- One predicate for "may the caller see this attachment", whichever owner it
-- hangs off. photo_annotations reuses it rather than repeating the branch.
create or replace function app.can_read_attachment(p_attachment_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.attachments a
    where a.id = p_attachment_id
      and (
        (a.message_id is not null and app.can_read_message(a.message_id))
        or (a.task_id is not null and app.can_read_task(a.task_id))
      )
  );
$$;

grant execute on function app.can_read_attachment(uuid) to authenticated;

drop policy attachments_select on public.attachments;
create policy attachments_select on public.attachments
  for select to authenticated
  using (
    (message_id is not null and app.can_read_message(message_id))
    or (task_id is not null and app.can_read_task(task_id))
  );

drop policy attachments_insert on public.attachments;
create policy attachments_insert on public.attachments
  for insert to authenticated
  with check (
    (
      message_id is not null
      and exists (
        select 1 from public.messages m
        where m.id = message_id and m.sender_id = (select auth.uid())
      )
    )
    or (task_id is not null and app.can_write_task(task_id))
  );

-- Deleting a task attachment is a real operation (wrong photo, wrong step).
-- Message attachments stay undeletable on their own — the message is the unit,
-- and chat history keeps its "edit within 15 minutes, then it stands" story.
create policy attachments_delete on public.attachments
  for delete to authenticated
  using (
    task_id is not null
    and app.can_write_task(task_id)
    and (uploaded_by = (select auth.uid()) or app.is_office())
  );

drop policy photo_annotations_select on public.photo_annotations;
create policy photo_annotations_select on public.photo_annotations
  for select to authenticated
  using (app.can_read_attachment(attachment_id));

drop policy photo_annotations_insert on public.photo_annotations;
create policy photo_annotations_insert on public.photo_annotations
  for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and app.current_member_role() <> 'customer'
    and exists (
      select 1 from public.attachments a
      where a.id = attachment_id
        and a.kind = 'photo'
        and app.can_read_attachment(a.id)
    )
  );

-- A chat message may reference a photo that hangs off a task in the same
-- project ("wie auf dem Bild bei Schritt 3"), which the message-only join
-- could not express.
create or replace function app.sync_ref_scope()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select m.company_id, m.project_id into strict new.company_id, new.project_id
  from public.messages m where m.id = new.message_id;

  if new.kind = 'task' and not exists (
    select 1 from public.tasks t where t.id = new.task_id and t.project_id = new.project_id
  ) then
    raise exception 'referenced task % is not in project %', new.task_id, new.project_id;
  end if;

  if new.kind = 'attachment' and not exists (
    select 1 from public.attachments a
    where a.id = new.attachment_id
      and (
        exists (select 1 from public.messages tm
                 where tm.id = a.message_id and tm.project_id = new.project_id)
        or exists (select 1 from public.tasks tt
                    where tt.id = a.task_id and tt.project_id = new.project_id)
      )
  ) then
    raise exception 'referenced attachment % is not in project %', new.attachment_id, new.project_id;
  end if;

  return new;
end; $$;

-- ========================================== 5. storage read gate for tasks
-- A customer-visible task with a photo showed a broken image, because the
-- customer storage gate only ever reached objects through shared messages.
create or replace function app.customer_can_read_object(p_bucket text, p_name text)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.attachments a
    where (
        (a.storage_bucket = p_bucket and a.storage_path = p_name)
        or (
          p_bucket = 'photos'
          and exists (
            select 1 from public.photo_annotations pa
            where pa.attachment_id = a.id and pa.rendered_path = p_name
          )
        )
      )
      and (
        exists (
          select 1 from public.messages m
          where m.id = a.message_id
            and m.deleted_at is null
            and (m.expires_at is null or m.expires_at > now())
            and m.shared_with_customer
            and app.is_member_of_project(m.project_id)
        )
        or exists (
          select 1 from public.tasks t
          where t.id = a.task_id
            and t.visible_to_customer
            and app.package_visible_to_customer(t.parent_id)
            and app.is_member_of_project(t.project_id)
        )
      )
  );
$$;

-- Brought forward from slice 4's must-fix list, because task attachments make
-- it reachable: the own-object policies were not bucket-scoped, so an uploader
-- could update or delete their own object in ANY bucket on the project —
-- including buckets added later for signatures and rendered documents.
drop policy media_objects_update_own on storage.objects;
create policy media_objects_update_own on storage.objects
  for update to authenticated
  using (
    owner_id = (select auth.uid())::text
    and bucket_id in ('photos', 'voice', 'video', 'avatars')
  )
  with check (
    owner_id = (select auth.uid())::text
    and bucket_id in ('photos', 'voice', 'video', 'avatars')
  );

drop policy media_objects_delete_own on storage.objects;
create policy media_objects_delete_own on storage.objects
  for delete to authenticated
  using (
    owner_id = (select auth.uid())::text
    and bucket_id in ('photos', 'voice', 'video', 'avatars')
  );

-- ============================================ 6. overview counts packages
-- Every "x/y Aufgaben erledigt" figure in both clients reads this view. If
-- steps counted here, adding steps to one package would silently inflate the
-- project's totals and every existing number would change meaning overnight.
-- The board counts packages; a package's own progress chip counts its steps.
create or replace view public.project_overview
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
left join public.tasks t
  on t.project_id = p.id and t.parent_id is null
group by p.id;

-- ==================================== 7. reminders that know the time of day
-- Was: one pass at 06:00 for "due tomorrow" and "overdue". Now also an
-- appointment window, so a task with a due_time is announced shortly before it
-- rather than at dawn. The daily block keeps its own dedupe keys, so running
-- the function four times an hour is idempotent.
create or replace function public.enqueue_due_reminders()
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_now_local timestamp := (now() at time zone 'Europe/Zurich');
  v_today date := v_now_local::date;
  v_count integer := 0;
begin
  if extract(hour from v_now_local) = 6 then
    insert into public.notification_outbox
      (kind, company_id, project_id, task_id, dedupe_key, payload)
    select 'task_due_soon', t.company_id, t.project_id, t.id,
           'due:' || t.id::text || ':' || t.due_date::text,
           jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
      from public.tasks t
     where t.status in ('todo', 'in_progress', 'blocked')
       and t.due_date = v_today + 1
    on conflict (dedupe_key) do nothing;
    get diagnostics v_count = row_count;

    insert into public.notification_outbox
      (kind, company_id, project_id, task_id, dedupe_key, payload)
    select 'task_overdue', t.company_id, t.project_id, t.id,
           'overdue:' || t.id::text || ':' || v_today::text,
           jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
      from public.tasks t
     where t.status in ('todo', 'in_progress', 'blocked')
       and t.due_date < v_today
       and t.due_date >= v_today - 14
    on conflict (dedupe_key) do nothing;
  end if;

  -- Appointment window: a stated time of day now within 90 minutes. Its own
  -- dedupe key, so it does not cancel the morning reminder.
  --
  -- The date range spans today AND tomorrow, and the timestamp comparison
  -- decides. Pinning it to today would silently drop every appointment in the
  -- first 90 minutes after midnight: at 23:40 the lookahead reaches 01:10
  -- tomorrow, but such a task carries tomorrow's date. The range is only here
  -- to keep the scan bounded — the `between` is the actual rule.
  insert into public.notification_outbox
    (kind, company_id, project_id, task_id, dedupe_key, payload)
  select 'task_due_soon', t.company_id, t.project_id, t.id,
         'appt:' || t.id::text || ':' || t.due_date::text,
         jsonb_build_object('due_date', t.due_date, 'due_time', t.due_time)
    from public.tasks t
   where t.status in ('todo', 'in_progress', 'blocked')
     and t.due_time is not null
     and t.due_date between v_today and v_today + 1
     and (t.due_date + t.due_time) between v_now_local
                                       and v_now_local + interval '90 minutes'
  on conflict (dedupe_key) do nothing;

  perform app.nudge_notifier();
  return v_count;
end; $$;

revoke execute on function public.enqueue_due_reminders() from public, anon, authenticated;

-- Hourly could miss a 90-minute window only by luck; quarter-hourly makes the
-- appointment reminder land 60-90 minutes ahead rather than 0-90.
select cron.schedule('ventline-due-reminders', '*/15 * * * *',
                     $$select public.enqueue_due_reminders();$$);
