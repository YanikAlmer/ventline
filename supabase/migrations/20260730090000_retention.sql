-- Five-year retention on the working-time record.
--
-- ArGV 1 Art. 73 Abs. 2 requires time records to be kept five years, and
-- revDSG Art. 6 Abs. 4 makes keeping personal data beyond its purpose unlawful
-- — so five years is a ceiling as well as a floor, and a purge is a duty
-- rather than a nicety.
--
-- WHAT THIS DOES NOT PURGE, and why that is not a hedge:
--
-- A time entry is a labour record. Once it has been frozen onto a signed
-- Rapport it has ALSO become part of an accounting record, and those carry
-- their own floors — OR 958f says ten years for a Buchungsbeleg, MWSTG Art. 70
-- Abs. 3 says twenty where immovable property is involved, which for an HLKS
-- installation is the normal case rather than the exception.
--
-- The two obligations attach to two different things, so they are satisfied
-- separately: the labour record is deleted at five years, and the frozen copy
-- on the signed Rapport survives untouched. Nothing that a Rapport states is
-- lost; what is lost is the separate, live, per-employee record behind it —
-- which is precisely the thing ArGV 1 Art. 73 is about.
--
-- Deleting signed Rapporte or invoices on a five-year clock would destroy
-- accounting records, so this job does not touch them. If that is wanted it is
-- a separate, deliberate decision with a Treuhänder's name on it.

-- ============================================================= 1. the clock
-- Anchored to the end of the calendar year the work fell in, which is the
-- reading of "Ablauf der Gültigkeit" a Swiss bookkeeping year makes natural:
-- work done in 2026 is retained until 2031-12-31.
alter table public.time_entries
  add column retain_until date
    generated always as (
      make_date(extract(year from work_date)::integer + 5, 12, 31)
    ) stored;

comment on column public.time_entries.retain_until is
  'ArGV 1 Art. 73 Abs. 2: five years from the end of the year the work fell in. Derived, never set by a client.';

create index time_entries_retain_until_idx
  on public.time_entries (retain_until);

-- ============================ 1a. stop generated columns breaking the log
-- Adding retain_until immediately broke the revision log's no-op detection, in
-- exactly the way worked_minutes did: Postgres computes generated columns
-- AFTER before-row triggers, so NEW holds null while OLD holds the real value,
-- every update looks like a change, and every no-op manufactures a revision.
--
-- The previous fix named worked_minutes explicitly, and this is what that
-- costs — the next generated column silently reintroduces the bug. So the
-- exclusion is now derived from the catalog instead of maintained by hand.
create or replace function app.strip_generated(p_table regclass, p_row jsonb)
returns jsonb
language sql stable
set search_path = ''
as $$
  select p_row - array(
    select a.attname::text
    from pg_catalog.pg_attribute a
    where a.attrelid = p_table
      and a.attnum > 0
      and not a.attisdropped
      and a.attgenerated <> ''
  );
$$;

create or replace function app.log_time_entry_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_op text;
  v_reason text := nullif(current_setting('ventline.correction_reason', true), '');
begin
  -- A no-op UPDATE writes no history. Generated columns are excluded because
  -- they are not yet computed here (see above); revision and updated_at
  -- because they are what this trigger and set_updated_at are about to change.
  if app.strip_generated(tg_relid::regclass, to_jsonb(new)) - 'revision' - 'updated_at'
   = app.strip_generated(tg_relid::regclass, to_jsonb(old)) - 'revision' - 'updated_at'
  then
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

-- ==================================================== 2. purge bookkeeping
-- A deletion that leaves no trace is indistinguishable from a deletion that
-- never happened. This records what the job did, so an inspection can see the
-- policy running rather than take it on faith.
create table public.retention_runs (
  id bigserial primary key,
  ran_at timestamptz not null default now(),
  cutoff date not null,
  entries_deleted integer not null,
  revisions_deleted integer not null,
  report_lines_detached integer not null
);

alter table public.retention_runs enable row level security;
grant select on public.retention_runs to authenticated;

create policy retention_runs_select on public.retention_runs
  for select to authenticated
  using (app.is_office());

-- ======================= 2a. the one thing the freeze must let through
-- The purge has to clear a signed line's pointer to the labour record it is
-- about to delete, and the freeze trigger — correctly — refuses any change to
-- a signed line.
--
-- The exemption is narrow and principled rather than a bypass: what is frozen
-- is what the customer signed, and app.report_canonical_text covers the date,
-- the name, the description, the minutes and the rate. It does NOT cover
-- time_entry_id or source_revision, which are provenance bookkeeping. Clearing
-- them therefore cannot change the content hash — and the regression test
-- asserts the Rapport still verifies afterwards, which is what makes that
-- claim checkable rather than merely stated.
--
-- Everything else about a signed line remains immutable, including setting
-- those columns to any non-null value.
create or replace function app.freeze_report_children()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_report uuid;
  v_only_detaching boolean := false;
begin
  if tg_op = 'UPDATE' and tg_table_name = 'report_time_lines' then
    v_only_detaching :=
      new.time_entry_id is null
      and new.source_revision is null
      and (old.time_entry_id is not null or old.source_revision is not null)
      -- Nothing else may move.
      and to_jsonb(new) - 'time_entry_id' - 'source_revision'
        = to_jsonb(old) - 'time_entry_id' - 'source_revision';
    if v_only_detaching then
      return new;
    end if;
  end if;

  foreach v_report in array array_remove(array[
    case when tg_op <> 'INSERT' then old.report_id end,
    case when tg_op <> 'DELETE' then new.report_id end
  ], null)
  loop
    if exists (
      select 1 from public.reports r
      where r.id = v_report and r.status <> 'draft'
    ) then
      raise exception 'Rapport ist unterschrieben; Positionen koennen nicht geaendert werden'
        using errcode = 'check_violation';
    end if;
  end loop;

  return case when tg_op = 'DELETE' then old else new end;
end; $$;

-- ================================================================ 3. purge
create or replace function public.purge_expired_time_entries()
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_cutoff date := (now() at time zone 'Europe/Zurich')::date;
  v_entries integer := 0;
  v_revisions integer := 0;
  v_detached integer := 0;
begin
  -- The frozen line on a signed Rapport keeps its content — the date, the
  -- name, the minutes and the rate were copied at signing. What it loses is
  -- the pointer back to a labour record that no longer exists, which is what
  -- makes the delete possible at all: the foreign key is ON DELETE RESTRICT,
  -- deliberately, so a signed document can never be silently hollowed out.
  update public.report_time_lines l
     set time_entry_id = null,
         source_revision = null
   where l.time_entry_id in (
     select t.id from public.time_entries t where t.retain_until < v_cutoff
   );
  get diagnostics v_detached = row_count;

  delete from public.time_entry_revisions r
   where r.time_entry_id in (
     select t.id from public.time_entries t where t.retain_until < v_cutoff
   );
  get diagnostics v_revisions = row_count;

  delete from public.time_entries t where t.retain_until < v_cutoff;
  get diagnostics v_entries = row_count;

  insert into public.retention_runs
    (cutoff, entries_deleted, revisions_deleted, report_lines_detached)
  values (v_cutoff, v_entries, v_revisions, v_detached);

  return v_entries;
end;
$$;

-- Not callable from the API: a client must not be able to trigger a deletion
-- sweep, and nothing legitimate needs to.
revoke execute on function public.purge_expired_time_entries()
  from public, anon, authenticated;

-- Monthly, not daily. Retention is measured in years; a sweep that runs every
-- night is 365 chances a year for a bug to delete something early.
select cron.schedule('ventline-retention-purge', '0 4 1 * *',
                     $$select public.purge_expired_time_entries();$$);

-- ================================= 4. the divergence view survives a purge
-- The view inner-joins the source entry, so a purged entry simply drops out —
-- which is correct: a record that no longer exists cannot have diverged. Left
-- as an explicit note because the behaviour is load-bearing and silent.
