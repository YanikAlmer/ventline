-- Time capture and material lines: what was actually done on site.
--
-- Two properties drive the whole design.
--
-- 1. A time record is a labour-law document, not an app row. ArG Art. 46 and
--    ArGV 1 Art. 73 require the *Lage* — when work began and ended, not merely
--    how long it lasted — so duration is derived and never stored on its own.
--
-- 2. It must be correctable without becoming rewritable. Payroll legitimately
--    needs to fix an entry weeks later; an inspection needs to see that it was
--    fixed, by whom, and what it said before. So: entries are mutable, every
--    change appends to a log nobody can write to directly, and deletion does
--    not exist — an entry is voided, with a reason.

create type public.time_entry_kind as enum (
  'work',
  -- Travel is recorded working time under the GAV, not an expense line.
  'travel',
  'standby'
);

create table public.time_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  -- Optional: hours may be booked to the job as a whole or to one work package.
  task_id uuid references public.tasks (id) on delete set null,

  -- Whose hours these are, and who typed them in. An inspectorate reads
  -- foreman-entered time differently from self-reported time, so the two are
  -- never collapsed into one column.
  profile_id  uuid not null references public.profiles (id) on delete restrict,
  recorded_by uuid references public.profiles (id) on delete set null,

  kind public.time_entry_kind not null default 'work',

  -- Local calendar day, derived from started_at in Europe/Zurich by trigger —
  -- never client-supplied, or a device in another timezone books to the wrong
  -- day. Not a generated column because the timezone conversion is STABLE
  -- (it depends on the tz database), and generated columns require IMMUTABLE.
  work_date date not null,
  started_at timestamptz not null,
  -- Null while the clock is still running.
  ended_at   timestamptz,
  break_minutes integer not null default 0,

  -- Derived, so it can never disagree with the times it comes from.
  worked_minutes integer generated always as (
    case
      when ended_at is null then null
      else greatest(
        0,
        (extract(epoch from (ended_at - started_at)) / 60)::integer - break_minutes
      )
    end
  ) stored,

  note text,

  -- Bumped by the logging trigger; the frozen report line records which
  -- revision it copied, which is what makes later divergence detectable.
  revision integer not null default 1,

  -- Deletion is a state, not an operation.
  voided_at     timestamptz,
  voided_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint time_entries_ends_after_start check (ended_at is null or ended_at > started_at),
  constraint time_entries_break_nonneg check (break_minutes >= 0),
  -- A break cannot exceed the span it sits inside.
  constraint time_entries_break_fits check (
    ended_at is null
    or break_minutes <= (extract(epoch from (ended_at - started_at)) / 60)::integer
  ),
  constraint time_entries_void_has_reason check (
    voided_at is null or voided_reason is not null
  ),
  -- A day longer than the ArG Art. 10 time frame is a typo, not a shift.
  constraint time_entries_sane_span check (
    ended_at is null or ended_at <= started_at + interval '16 hours'
  )
);

create index time_entries_project_date_idx
  on public.time_entries (project_id, work_date desc) where voided_at is null;
create index time_entries_profile_date_idx
  on public.time_entries (profile_id, work_date desc) where voided_at is null;
create index time_entries_company_idx on public.time_entries (company_id);
create index time_entries_task_idx
  on public.time_entries (task_id) where task_id is not null;
-- One running clock per person: a second open entry means the first was never
-- stopped, and the resulting overlap is unreconstructable after the fact.
create unique index time_entries_one_open_per_profile
  on public.time_entries (profile_id) where ended_at is null and voided_at is null;

-- Scope and stamps are all server-derived. company_id from the project,
-- work_date from the start time in Zurich, recorded_by from the session.
create or replace function app.sync_time_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select p.company_id into strict new.company_id
  from public.projects p where p.id = new.project_id;

  if new.task_id is not null and not exists (
    select 1 from public.tasks t
    where t.id = new.task_id and t.project_id = new.project_id
  ) then
    raise exception 'task % does not belong to project %', new.task_id, new.project_id;
  end if;

  new.work_date := (new.started_at at time zone 'Europe/Zurich')::date;

  if tg_op = 'INSERT' and (select auth.uid()) is not null then
    new.recorded_by := (select auth.uid());
  end if;

  return new;
end; $$;

create trigger sync_time_entry before insert or update on public.time_entries
  for each row execute function app.sync_time_entry();

-- ============================================== append-only revision log
-- The API roles get SELECT and nothing else. The only writer is the SECURITY
-- DEFINER trigger below, so there is no path — not even for an owner — to
-- rewrite history from a client.
create table public.time_entry_revisions (
  id bigserial primary key,
  company_id uuid not null references public.companies (id) on delete cascade,
  time_entry_id uuid not null references public.time_entries (id) on delete restrict,
  revision integer not null,
  op text not null check (op in ('INSERT', 'UPDATE', 'VOID')),
  reason text,
  changed_by uuid references public.profiles (id) on delete set null,
  changed_at timestamptz not null default now(),
  before jsonb,
  after  jsonb,
  unique (time_entry_id, revision)
);

create index time_entry_revisions_entry_idx
  on public.time_entry_revisions (time_entry_id, revision);

-- Split across two timings, and the split is forced rather than stylistic.
--
-- INSERT must log AFTER: the log row carries a foreign key to the entry, and
-- in a BEFORE trigger that entry does not exist yet.
--
-- UPDATE must log BEFORE: it sets new.revision, and an AFTER trigger cannot
-- change the row being written.
create or replace function app.log_time_entry_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.time_entry_revisions
    (company_id, time_entry_id, revision, op, changed_by, before, after)
  values (new.company_id, new.id, new.revision, 'INSERT',
          (select auth.uid()), null, to_jsonb(new));
  return null;
end; $$;

create trigger zz_log_time_entry_insert after insert on public.time_entries
  for each row execute function app.log_time_entry_insert();

create or replace function app.log_time_entry_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_op text;
  v_reason text := nullif(current_setting('ventline.correction_reason', true), '');
begin
  -- A no-op UPDATE writes no history.
  --
  -- Three columns are excluded. revision and updated_at are what this trigger
  -- and set_updated_at are about to change. worked_minutes is excluded because
  -- it is GENERATED: Postgres computes generated columns *after* BEFORE
  -- triggers, so NEW.worked_minutes is still null here while OLD holds the
  -- real value — comparing them makes every update look like a change, and
  -- every no-op would manufacture a revision. Its inputs (started_at,
  -- ended_at, break_minutes) are compared anyway, so nothing is lost.
  if to_jsonb(new) - 'revision' - 'updated_at' - 'worked_minutes'
   = to_jsonb(old) - 'revision' - 'updated_at' - 'worked_minutes' then
    return new;
  end if;

  v_op := case when new.voided_at is not null and old.voided_at is null
               then 'VOID' else 'UPDATE' end;

  new.revision := old.revision + 1;
  insert into public.time_entry_revisions
    (company_id, time_entry_id, revision, op, reason, changed_by, before, after)
  values (new.company_id, new.id, new.revision, v_op,
          coalesce(v_reason, new.voided_reason),
          (select auth.uid()), to_jsonb(old), to_jsonb(new));

  return new;
end; $$;

-- Named to sort after sync_time_entry: the log must record the derived
-- company_id and work_date, not the client's unresolved values.
create trigger zz_log_time_entry_update before update on public.time_entries
  for each row execute function app.log_time_entry_update();

-- ==================================================== material lines
create table public.material_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete cascade,
  task_id uuid references public.tasks (id) on delete set null,

  description text not null check (char_length(description) between 1 and 300),
  -- Integer thousandths: 2.5 m is 2500. Materials come in fractional
  -- quantities and no float may touch a quantity that will be multiplied by a
  -- price.
  quantity_milli bigint not null check (quantity_milli > 0),
  unit text not null default 'Stk',
  unit_price_rappen bigint not null default 0 check (unit_price_rappen >= 0),

  recorded_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index material_lines_project_idx on public.material_lines (project_id, created_at desc);
create index material_lines_company_idx on public.material_lines (company_id);

create or replace function app.sync_material_line()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  select p.company_id into strict new.company_id
  from public.projects p where p.id = new.project_id;

  if new.task_id is not null and not exists (
    select 1 from public.tasks t
    where t.id = new.task_id and t.project_id = new.project_id
  ) then
    raise exception 'task % does not belong to project %', new.task_id, new.project_id;
  end if;

  if tg_op = 'INSERT' and (select auth.uid()) is not null then
    new.recorded_by := (select auth.uid());
  end if;

  return new;
end; $$;

create trigger sync_material_line before insert or update on public.material_lines
  for each row execute function app.sync_material_line();

create trigger set_updated_at before update on public.time_entries
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.material_lines
  for each row execute function app.set_updated_at();

-- ================================================================ RLS
alter table public.time_entries          enable row level security;
alter table public.time_entry_revisions  enable row level security;
alter table public.material_lines        enable row level security;

-- No DELETE grant on time_entries at all: voiding is the only removal, so the
-- revision log can never be orphaned.
grant select, insert, update on public.time_entries to authenticated;
grant select on public.time_entry_revisions to authenticated;
grant select, insert, update, delete on public.material_lines to authenticated;

-- A worker sees and books their own hours; office and foremen see the whole
-- project. Customers never see labour records — not even on a project they
-- belong to, because hours are an internal cost, and what they are entitled to
-- see is the Rapport once it is shared with them.
create policy time_entries_select on public.time_entries
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and app.current_member_role() <> 'customer'
    and (
      profile_id = (select auth.uid())
      or app.is_office()
      or (app.current_member_role() = 'foreman' and app.is_member_of_project(project_id))
    )
  );

create policy time_entries_insert on public.time_entries
  for insert to authenticated
  with check (
    app.can_write_project(project_id)
    and (
      -- Book your own time, or — as a foreman/office — someone else's.
      profile_id = (select auth.uid())
      or app.is_office()
      or app.current_member_role() = 'foreman'
    )
  );

create policy time_entries_update on public.time_entries
  for update to authenticated
  using (
    app.can_write_project(project_id)
    and (
      profile_id = (select auth.uid())
      or app.is_office()
      or (app.current_member_role() = 'foreman' and app.is_member_of_project(project_id))
    )
  )
  with check (app.can_write_project(project_id));

-- You may read the history of an entry you may read.
create policy time_entry_revisions_select on public.time_entry_revisions
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and app.current_member_role() <> 'customer'
    and exists (
      select 1 from public.time_entries t
      where t.id = time_entry_id
        and (t.profile_id = (select auth.uid())
             or app.is_office()
             or (app.current_member_role() = 'foreman'
                 and app.is_member_of_project(t.project_id)))
    )
  );

create policy material_lines_select on public.material_lines
  for select to authenticated
  using (
    app.is_member_of_project(project_id)
    and app.current_member_role() <> 'customer'
  );

create policy material_lines_insert on public.material_lines
  for insert to authenticated
  with check (app.can_write_project(project_id));

create policy material_lines_update on public.material_lines
  for update to authenticated
  using (app.can_write_project(project_id))
  with check (app.can_write_project(project_id));

create policy material_lines_delete on public.material_lines
  for delete to authenticated
  using (
    app.can_write_project(project_id)
    and (recorded_by = (select auth.uid()) or app.is_office()
         or app.current_member_role() = 'foreman')
  );

-- ============================================ correction reason plumbing
-- A correction without a reason is not an audit trail. The client sets the
-- reason for the current transaction through this RPC, and the logging trigger
-- reads it. set_config with is_local = true scopes it to the transaction, so
-- it cannot leak into the next request on a pooled connection.
create or replace function public.set_correction_reason(p_reason text)
returns void
language sql
set search_path = ''
as $$
  select set_config('ventline.correction_reason', coalesce(p_reason, ''), true);
  select null::void;
$$;

grant execute on function public.set_correction_reason(text) to authenticated;
