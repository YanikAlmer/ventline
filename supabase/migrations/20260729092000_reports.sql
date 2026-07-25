-- The Rapport: work performed, acknowledged by the customer, frozen forever.
--
-- Three hard problems, solved here rather than in application code:
--
-- 1. **Gapless numbering per company.** Swiss bookkeeping expects an unbroken
--    series. Postgres sequences are explicitly NOT gapless — they survive
--    rollback — so the counter is a row, incremented inside the caller's
--    transaction, and the number is allocated only on the draft→signed
--    transition. A deleted draft must not burn a number.
--
-- 2. **Immutability after signing**, including children. A customer signed a
--    specific set of lines; those lines must never change afterwards.
--
-- 3. **...while the underlying time record stays correctable.** Payroll may
--    legitimately fix an entry weeks later. The reconciliation is that a
--    report line is a frozen *copy*, not a live reference — plus a view that
--    surfaces where the two have since diverged, as office work rather than
--    as a silent inconsistency.

create type public.document_type as enum ('rapport', 'invoice');

create type public.report_status as enum ('draft', 'signed', 'sent', 'cancelled');

-- ================================================= 1. the number counter
-- In the `app` schema so PostgREST never exposes it, and with no grants at
-- all: the only way to reach it is the allocator below, which is itself only
-- called from a trigger.
create table app.document_counters (
  company_id uuid not null references public.companies (id) on delete cascade,
  doc_type   public.document_type not null,
  -- 'YYYY' in Europe/Zurich. The series resets each calendar year.
  period_key text not null,
  next_number bigint not null default 1,
  primary key (company_id, doc_type, period_key)
);

-- One statement. The UPSERT takes the row lock itself, handles the cold start,
-- and is transactional — so a rollback returns the number to the pool, which
-- is exactly what "gapless" requires. It locks one row per (company, type,
-- year), so two tenants never serialise against each other.
create or replace function app.next_document_number(
  p_company uuid,
  p_doc_type public.document_type,
  p_period text
)
returns bigint
language sql security definer
set search_path = ''
as $$
  insert into app.document_counters as c (company_id, doc_type, period_key, next_number)
  values (p_company, p_doc_type, p_period, 2)
  on conflict (company_id, doc_type, period_key)
  do update set next_number = c.next_number + 1
  returning c.next_number - 1;
$$;

-- Deliberately NOT granted to authenticated: only the assignment trigger calls it.
revoke execute on function app.next_document_number(uuid, public.document_type, text)
  from public, anon, authenticated;

-- ======================================================== 2. the report
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  -- restrict, not cascade: a signed document pins its own context.
  project_id uuid not null references public.projects (id) on delete restrict,
  customer_id uuid references public.customers (id) on delete restrict,

  doc_type public.document_type not null default 'rapport',
  status   public.report_status not null default 'draft',

  title text,
  summary text,
  period_from date,
  period_to   date,

  -- Assigned server-side at signing. Null for every draft.
  period_key  text,
  number      bigint,
  number_text text,

  -- The full render input, frozen at signing. This is what the PDF was made
  -- from and what a dispute is argued against.
  snapshot jsonb,
  -- sha256 of the canonical snapshot; printed on the customer's PDF so the
  -- document carries its own external anchor.
  content_hash bytea,

  -- Money, frozen at signing. Never recomputed, so a later rate change or a
  -- corrected time entry cannot silently restate a signed document.
  total_net_rappen bigint,

  pdf_path text,
  pdf_sha256 bytea,
  pdf_generated_at timestamptz,

  signature_path text,
  signer_name text,
  signed_at timestamptz,

  sent_at timestamptz,

  -- A signed report is never edited; it is superseded by a correcting one.
  corrects_report_id uuid references public.reports (id) on delete restrict,

  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- A half-assigned state is unrepresentable: either it is a draft with no
  -- number and no signature, or it is issued with all of them.
  constraint reports_number_pairs check (
    (status = 'draft'
       and number is null and period_key is null
       and signed_at is null and snapshot is null)
    or
    (status <> 'draft'
       and number is not null and period_key is not null
       and snapshot is not null and signed_at is not null)
  ),
  constraint reports_correction_is_other check (corrects_report_id is distinct from id),
  constraint reports_period_ordered check (
    period_from is null or period_to is null or period_to >= period_from
  )
);

-- Partial unique index: unlimited drafts (number is null), one holder per
-- allocated number.
create unique index reports_number_uq
  on public.reports (company_id, doc_type, period_key, number)
  where number is not null;

create index reports_project_idx on public.reports (project_id, created_at desc);
create index reports_company_status_idx on public.reports (company_id, status);
create index reports_customer_idx
  on public.reports (customer_id) where customer_id is not null;

-- ============================================== 3. the frozen child lines
-- Copies, not references. `source_revision` records which revision of the
-- time entry was on the paper, which is what makes divergence detectable.
create table public.report_time_lines (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  time_entry_id uuid references public.time_entries (id) on delete restrict,
  source_revision integer,

  performed_on date not null,
  profile_id uuid references public.profiles (id) on delete set null,
  -- Denormalised on purpose: the name printed on a signed document must not
  -- change because somebody later edited their profile.
  performed_by_name text,
  description text,
  minutes integer not null check (minutes >= 0),
  rate_rappen bigint not null default 0 check (rate_rappen >= 0),
  sort_order integer not null default 0
);

create index report_time_lines_report_idx on public.report_time_lines (report_id, sort_order);
create index report_time_lines_entry_idx
  on public.report_time_lines (time_entry_id) where time_entry_id is not null;

create table public.report_material_lines (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete cascade,
  material_line_id uuid references public.material_lines (id) on delete set null,

  description text not null,
  quantity_milli bigint not null,
  unit text not null default 'Stk',
  unit_price_rappen bigint not null default 0 check (unit_price_rappen >= 0),
  sort_order integer not null default 0
);

create index report_material_lines_report_idx
  on public.report_material_lines (report_id, sort_order);

create table public.report_photos (
  report_id uuid not null references public.reports (id) on delete cascade,
  attachment_id uuid not null references public.attachments (id) on delete restrict,
  sort_order integer not null default 0,
  primary key (report_id, attachment_id)
);

-- ================================ 4. photos on a signed report are evidence
-- An attachment could previously hang off a message or a task. A message can
-- be purged (messages.expires_at drives purge_expired_messages), and its
-- attachments cascade — which would delete a photo out from under a signed
-- Rapport, or, with the RESTRICT above, make the purge throw on every signed
-- report that used a chat photo.
--
-- So a report photo is *copied* into its own attachment row owned by the
-- report. The chat message keeps its own row and may still be purged.
alter table public.attachments
  add column report_id uuid references public.reports (id) on delete cascade;

alter table public.attachments
  drop constraint attachments_single_owner;

alter table public.attachments
  add constraint attachments_single_owner
    check (num_nonnulls(message_id, task_id, report_id) = 1);

create index attachments_report_idx
  on public.attachments (report_id) where report_id is not null;

-- ===================================== 5. numbering + immutability trigger
create or replace function app.assign_report_number()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_period text;
begin
  if old.status = 'draft' and new.status <> 'draft' then
    -- The number is not the client's to propose.
    if new.number is not null or new.period_key is not null then
      raise exception 'the document number is assigned server-side'
        using errcode = 'check_violation';
    end if;

    v_period := to_char(timezone('Europe/Zurich', now()), 'YYYY');
    new.period_key  := v_period;
    new.number      := app.next_document_number(new.company_id, new.doc_type, v_period);
    new.number_text := v_period || '-' || lpad(new.number::text, 4, '0');
    new.signed_at   := coalesce(new.signed_at, now());

  elsif old.status <> 'draft' then
    -- Already issued. Everything that constitutes the document is sealed.
    -- Only the delivery state may still advance.
    if new.status = 'draft'
       or new.number         is distinct from old.number
       or new.period_key     is distinct from old.period_key
       or new.number_text    is distinct from old.number_text
       or new.snapshot       is distinct from old.snapshot
       or new.content_hash   is distinct from old.content_hash
       or new.signature_path is distinct from old.signature_path
       or new.signer_name    is distinct from old.signer_name
       or new.signed_at      is distinct from old.signed_at
       or new.total_net_rappen is distinct from old.total_net_rappen
       or new.project_id     is distinct from old.project_id
       or new.company_id     is distinct from old.company_id
    then
      raise exception 'Rapport % ist unterschrieben und kann nicht geaendert werden',
        coalesce(old.number_text, old.id::text)
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end; $$;

create trigger assign_report_number before update on public.reports
  for each row execute function app.assign_report_number();

-- The UPDATE trigger cannot see a row that is born signed. Without this, a
-- forged INSERT carrying status='signed', number=9999 goes straight through.
create or replace function app.guard_report_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    return new; -- service role / internal
  end if;
  if new.status <> 'draft'
     or new.number is not null or new.period_key is not null
     or new.signed_at is not null or new.signature_path is not null
     or new.snapshot is not null
  then
    raise exception 'Rapporte werden als Entwurf angelegt; die Nummer wird beim Unterschreiben vergeben'
      using errcode = 'check_violation';
  end if;

  select p.company_id into strict new.company_id
  from public.projects p where p.id = new.project_id;

  new.created_by := (select auth.uid());
  return new;
end; $$;

create trigger guard_report_insert before insert on public.reports
  for each row execute function app.guard_report_insert();

create trigger set_updated_at before update on public.reports
  for each row execute function app.set_updated_at();

-- ====================================== 6. child freeze (belt and braces)
-- RLS alone would not stop a SECURITY DEFINER path, and column grants would
-- not stop a DELETE. One function, reused on all three child tables, checking
-- both OLD and NEW so a line cannot be *moved into* a frozen report either.
create or replace function app.freeze_report_children()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_report uuid;
begin
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

create trigger freeze_when_signed before insert or update or delete on public.report_time_lines
  for each row execute function app.freeze_report_children();
create trigger freeze_when_signed before insert or update or delete on public.report_material_lines
  for each row execute function app.freeze_report_children();
create trigger freeze_when_signed before insert or update or delete on public.report_photos
  for each row execute function app.freeze_report_children();

-- ============================================================ 7. helpers
create or replace function app.can_read_report(p_report_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id
      and r.company_id = app.current_company_id()
      and (
        app.current_member_role() <> 'customer'
        -- A customer sees a report only once it has actually been sent to
        -- them, and only for a project they belong to.
        or (r.status = 'sent' and app.is_member_of_project(r.project_id))
      )
      and (app.current_member_role() = 'customer' or app.is_member_of_project(r.project_id))
  );
$$;

create or replace function app.can_write_report(p_report_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id and app.can_write_project(r.project_id)
  );
$$;

create or replace function app.report_is_frozen(p_report_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.reports r
    where r.id = p_report_id and r.status <> 'draft'
  );
$$;

grant execute on function
  app.can_read_report(uuid), app.can_write_report(uuid), app.report_is_frozen(uuid)
to authenticated;

-- ================================================================ 8. RLS
alter table public.reports               enable row level security;
alter table public.report_time_lines     enable row level security;
alter table public.report_material_lines enable row level security;
alter table public.report_photos         enable row level security;

grant select, insert, delete on public.reports to authenticated;
-- Column-level UPDATE grants are checked before RLS and before triggers, and
-- cannot be bypassed from the API. The sealed columns are simply not writable.
grant update (status, title, summary, period_from, period_to, customer_id,
              signer_name, signature_path, sent_at)
  on public.reports to authenticated;

grant select, insert, update, delete on public.report_time_lines to authenticated;
grant select, insert, update, delete on public.report_material_lines to authenticated;
grant select, insert, update, delete on public.report_photos to authenticated;

create policy reports_select on public.reports
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and (
      (app.current_member_role() <> 'customer' and app.is_member_of_project(project_id))
      or (app.current_member_role() = 'customer'
          and status = 'sent'
          and app.is_member_of_project(project_id))
    )
  );

create policy reports_insert on public.reports
  for insert to authenticated
  with check (app.can_write_project(project_id));

create policy reports_update on public.reports
  for update to authenticated
  using (app.can_write_project(project_id))
  with check (app.can_write_project(project_id));

-- Only a draft can be deleted, and only by someone who could have created it.
create policy reports_delete on public.reports
  for delete to authenticated
  using (status = 'draft' and app.can_write_project(project_id));

-- Child policies: membership in USING so the row stays visible and the freeze
-- trigger gets to speak. Putting the frozen test in USING would turn a
-- forbidden update into a silent 0-row no-op, which reads as success.
create policy report_time_lines_select on public.report_time_lines
  for select to authenticated using (app.can_read_report(report_id));
create policy report_time_lines_insert on public.report_time_lines
  for insert to authenticated
  with check (app.can_write_report(report_id) and not app.report_is_frozen(report_id));
create policy report_time_lines_update on public.report_time_lines
  for update to authenticated
  using (app.can_write_report(report_id))
  with check (app.can_write_report(report_id) and not app.report_is_frozen(report_id));
create policy report_time_lines_delete on public.report_time_lines
  for delete to authenticated using (app.can_write_report(report_id));

create policy report_material_lines_select on public.report_material_lines
  for select to authenticated using (app.can_read_report(report_id));
create policy report_material_lines_insert on public.report_material_lines
  for insert to authenticated
  with check (app.can_write_report(report_id) and not app.report_is_frozen(report_id));
create policy report_material_lines_update on public.report_material_lines
  for update to authenticated
  using (app.can_write_report(report_id))
  with check (app.can_write_report(report_id) and not app.report_is_frozen(report_id));
create policy report_material_lines_delete on public.report_material_lines
  for delete to authenticated using (app.can_write_report(report_id));

create policy report_photos_select on public.report_photos
  for select to authenticated using (app.can_read_report(report_id));
create policy report_photos_insert on public.report_photos
  for insert to authenticated
  with check (app.can_write_report(report_id) and not app.report_is_frozen(report_id));
create policy report_photos_delete on public.report_photos
  for delete to authenticated using (app.can_write_report(report_id));

-- Attachments owned by a report follow the report's own visibility.
drop policy attachments_select on public.attachments;
create policy attachments_select on public.attachments
  for select to authenticated
  using (
    (message_id is not null and app.can_read_message(message_id))
    or (task_id is not null and app.can_read_task(task_id))
    or (report_id is not null and app.can_read_report(report_id))
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
    or (report_id is not null and app.can_write_report(report_id)
        and not app.report_is_frozen(report_id))
  );

-- ==================================================== 9. the divergence view
-- The office work item that reconciles "the report must not change" with "the
-- underlying record may need to". Anything listed here is a signed Rapport
-- whose source hours have since been corrected — which is a conversation to
-- have, not a number to silently restate.
create or replace view public.report_divergences
with (security_invoker = on) as
select
  r.id            as report_id,
  r.number_text,
  r.project_id,
  l.time_entry_id,
  l.minutes       as minutes_on_paper,
  t.minutes_now,
  t.minutes_now - l.minutes as delta_minutes,
  t.voided_at is not null   as source_was_voided,
  r.corrects_report_id is not null as is_already_a_correction,
  exists (select 1 from public.reports c where c.corrects_report_id = r.id) as has_correction
from public.reports r
join public.report_time_lines l on l.report_id = r.id
join lateral (
  select te.revision, te.voided_at, te.worked_minutes as minutes_now
  from public.time_entries te where te.id = l.time_entry_id
) t on true
where r.status <> 'draft'
  and (t.revision > coalesce(l.source_revision, 0) or t.voided_at is not null)
  and (t.minutes_now is distinct from l.minutes or t.voided_at is not null);

grant select on public.report_divergences to authenticated;

-- Read-only gap audit, so a Treuhänder can check the Nummernkreis without a
-- database session. A gap here is a bug, not a business event.
create or replace view public.number_series_audit
with (security_invoker = on) as
select
  company_id,
  doc_type,
  period_key,
  count(*)::int          as issued,
  min(number)            as lowest,
  max(number)            as highest,
  (max(number) - min(number) + 1)::int - count(*)::int as missing
from public.reports
where number is not null
group by company_id, doc_type, period_key;

grant select on public.number_series_audit to authenticated;
