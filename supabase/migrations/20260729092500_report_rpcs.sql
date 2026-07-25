-- The two operations that must not be client-driven: pulling recorded time
-- onto a Rapport, and signing it.
--
-- Note that `snapshot`, `content_hash` and `number` are absent from the
-- column-level UPDATE grants in the previous migration. That is deliberate and
-- it is what forces signing through here: a client physically cannot write the
-- frozen content, so the frozen content is always the server's account of what
-- happened rather than the app's.

-- ================================================ 1. pull time onto a draft
-- Copies from time_entries server-side, so the minutes on the Rapport are the
-- minutes that were recorded — a client cannot inflate a line and then have
-- the customer sign it. The revision is captured with the copy, which is what
-- makes later divergence detectable.
create or replace function public.attach_time_to_report(
  p_report_id uuid,
  p_time_entry_ids uuid[]
)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_report public.reports%rowtype;
  v_rate bigint;
  v_count integer;
begin
  select * into v_report from public.reports where id = p_report_id;
  if not found then
    raise exception 'report % not found', p_report_id using errcode = 'no_data_found';
  end if;
  if not app.can_write_report(p_report_id) then
    raise exception 'not allowed to edit this Rapport' using errcode = 'insufficient_privilege';
  end if;
  if v_report.status <> 'draft' then
    raise exception 'Rapport ist unterschrieben und kann nicht geaendert werden'
      using errcode = 'check_violation';
  end if;

  select coalesce(b.default_hourly_rate_rappen, 9500) into v_rate
  from public.company_billing_settings b
  where b.company_id = v_report.company_id;
  v_rate := coalesce(v_rate, 9500);

  insert into public.report_time_lines
    (report_id, time_entry_id, source_revision, performed_on, profile_id,
     performed_by_name, description, minutes, rate_rappen, sort_order)
  select
    p_report_id, t.id, t.revision, t.work_date, t.profile_id,
    pr.full_name,
    coalesce(nullif(trim(t.note), ''), tk.title),
    t.worked_minutes,
    v_rate,
    row_number() over (order by t.work_date, t.started_at)
  from public.time_entries t
  join public.profiles pr on pr.id = t.profile_id
  left join public.tasks tk on tk.id = t.task_id
  where t.id = any (p_time_entry_ids)
    and t.project_id = v_report.project_id
    and t.voided_at is null
    and t.ended_at is not null
    -- Idempotent: re-running with the same ids adds nothing.
    and not exists (
      select 1 from public.report_time_lines l
      where l.report_id = p_report_id and l.time_entry_id = t.id
    );

  get diagnostics v_count = row_count;
  return v_count;
end; $$;

revoke execute on function public.attach_time_to_report(uuid, uuid[]) from public, anon;
grant execute on function public.attach_time_to_report(uuid, uuid[]) to authenticated;

-- ============================================= 2. the canonical serialisation
-- The hash printed on the customer's PDF is the document's external anchor, so
-- it must be reproducible years later. It is built from an explicit string
-- rather than from snapshot::text, because jsonb's text rendering is
-- deterministic only *within* a Postgres major version — a chain hashed on
-- PG 17 could fail to verify after an upgrade, which is precisely when you
-- would want to check it.
create or replace function app.report_canonical_text(p_report_id uuid)
returns text
language sql stable security definer
set search_path = ''
as $$
  select concat_ws(E'\n',
    'ventline-rapport-v1',
    r.id::text,
    r.company_id::text,
    r.project_id::text,
    coalesce(r.customer_id::text, ''),
    coalesce(r.title, ''),
    coalesce(r.summary, ''),
    coalesce(r.period_from::text, ''),
    coalesce(r.period_to::text, ''),
    coalesce((
      select string_agg(
        concat_ws('|', l.performed_on::text, coalesce(l.performed_by_name, ''),
                  coalesce(l.description, ''), l.minutes::text, l.rate_rappen::text),
        E'\n' order by l.performed_on, l.sort_order, l.id)
      from public.report_time_lines l where l.report_id = r.id), ''),
    coalesce((
      select string_agg(
        concat_ws('|', m.description, m.quantity_milli::text, m.unit,
                  m.unit_price_rappen::text),
        E'\n' order by m.sort_order, m.id)
      from public.report_material_lines m where m.report_id = r.id), ''),
    coalesce((
      select string_agg(a.storage_path, E'\n' order by p.sort_order, a.id)
      from public.report_photos p
      join public.attachments a on a.id = p.attachment_id
      where p.report_id = r.id), '')
  )
  from public.reports r where r.id = p_report_id;
$$;

-- ========================================================== 3. sign it
create or replace function public.sign_report(
  p_report_id uuid,
  p_signer_name text,
  p_signature_path text default null
)
returns public.reports
language plpgsql security definer
set search_path = ''
as $$
declare
  v_report public.reports%rowtype;
  v_canonical text;
  v_net bigint;
begin
  select * into v_report from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'report % not found', p_report_id using errcode = 'no_data_found';
  end if;
  if not app.can_write_report(p_report_id) then
    raise exception 'not allowed to sign this Rapport' using errcode = 'insufficient_privilege';
  end if;
  if v_report.status <> 'draft' then
    raise exception 'Rapport % ist bereits unterschrieben',
      coalesce(v_report.number_text, v_report.id::text)
      using errcode = 'check_violation';
  end if;
  if coalesce(trim(p_signer_name), '') = '' then
    raise exception 'der Name der unterzeichnenden Person fehlt'
      using errcode = 'check_violation';
  end if;
  if not exists (select 1 from public.report_time_lines where report_id = p_report_id)
     and not exists (select 1 from public.report_material_lines where report_id = p_report_id)
  then
    raise exception 'ein leerer Rapport kann nicht unterschrieben werden'
      using errcode = 'check_violation';
  end if;

  -- Net total, integer throughout: minutes * Rappen-per-hour / 60 rounds once
  -- per line, and quantity is thousandths.
  select
      coalesce((select sum((l.minutes::bigint * l.rate_rappen + 30) / 60)
                  from public.report_time_lines l where l.report_id = p_report_id), 0)
    + coalesce((select sum((m.quantity_milli * m.unit_price_rappen + 500) / 1000)
                  from public.report_material_lines m where m.report_id = p_report_id), 0)
  into v_net;

  v_canonical := app.report_canonical_text(p_report_id);

  update public.reports set
    status         = 'signed',
    signer_name    = trim(p_signer_name),
    signature_path = p_signature_path,
    signed_at      = now(),
    total_net_rappen = v_net,
    content_hash   = extensions.digest(v_canonical, 'sha256'),
    snapshot       = jsonb_build_object(
      'version', 1,
      'canonical_sha256', encode(extensions.digest(v_canonical, 'sha256'), 'hex'),
      'report', to_jsonb(v_report) - 'snapshot' - 'content_hash',
      'time_lines', coalesce((
        select jsonb_agg(to_jsonb(l) order by l.performed_on, l.sort_order, l.id)
        from public.report_time_lines l where l.report_id = p_report_id), '[]'::jsonb),
      'material_lines', coalesce((
        select jsonb_agg(to_jsonb(m) order by m.sort_order, m.id)
        from public.report_material_lines m where m.report_id = p_report_id), '[]'::jsonb),
      'photos', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'attachment_id', a.id,
                 'storage_bucket', a.storage_bucket,
                 'storage_path', a.storage_path) order by p.sort_order, a.id)
        from public.report_photos p
        join public.attachments a on a.id = p.attachment_id
        where p.report_id = p_report_id), '[]'::jsonb),
      'total_net_rappen', v_net
    )
  where id = p_report_id
  returning * into v_report;

  return v_report;
end; $$;

revoke execute on function public.sign_report(uuid, text, text) from public, anon;
grant execute on function public.sign_report(uuid, text, text) to authenticated;

-- ================================================= 4. verify a signature
-- Recomputes the canonical text and compares it to what was stored. Anyone who
-- can read the report can check that its content still matches its hash.
create or replace function public.verify_report_hash(p_report_id uuid)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
declare
  v_stored bytea;
  v_now bytea;
begin
  if not app.can_read_report(p_report_id) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  select content_hash into v_stored from public.reports where id = p_report_id;
  if v_stored is null then
    return null;
  end if;
  v_now := extensions.digest(app.report_canonical_text(p_report_id), 'sha256');
  return v_stored = v_now;
end; $$;

revoke execute on function public.verify_report_hash(uuid) from public, anon;
grant execute on function public.verify_report_hash(uuid) to authenticated;
