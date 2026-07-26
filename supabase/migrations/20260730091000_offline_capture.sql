-- Offline capture: record the work in a Heizungskeller, sync when there is
-- signal again.
--
-- The objection to offline signing was never the plumbing. It was this: the
-- Rapport number, the content hash and the render are all server-side, so a
-- Rapport signed offline is signed before it has a number — and "the customer
-- signed *this* document" stops being provable.
--
-- The answer is that the number was never what the customer signs. They sign a
-- statement of work performed: the hours, the materials, the description. The
-- number is bookkeeping the issuer assigns, and on paper it is pre-printed
-- purely as an artefact of paper.
--
-- So the device computes the SAME canonical hash the server would, at the
-- moment the pad is signed, and sends it along at sync. The server recomputes
-- and compares. If they match, the document now stored is provably the document
-- the customer was shown. If they do not, the sync is refused.
--
-- That is stronger than the online path, not weaker: it produces a device-side
-- attestation of what was on screen, which the online flow never had.

-- ========================================== 1. what the device attested to
alter table public.reports
  add column signed_offline boolean not null default false,
  -- The hash the device computed over its own rendering of the content, at the
  -- moment of signing. Kept even after verification, because it is the
  -- attestation — content_hash alone only proves the server's arithmetic.
  add column client_content_hash bytea,
  -- When the customer actually signed, as opposed to when the row reached us.
  add column signed_at_device timestamptz;

comment on column public.reports.client_content_hash is
  'SHA-256 the signing device computed over the canonical text, before sync. Verified against content_hash on arrival.';

-- ============================================ 2. idempotent, offline-aware sign
-- Replayed by a client that synced but never saw the response. Signing an
-- already-signed Rapport with the same signer and hash therefore returns the
-- existing row rather than raising: a retry must be safe, and making the
-- client guess which errors mean "already done" is how duplicates appear.
create or replace function public.sign_report(
  p_report_id uuid,
  p_signer_name text,
  p_signature_path text default null,
  -- Offline: when the pad was actually signed, and what the device hashed then.
  p_signed_at_device timestamptz default null,
  p_client_content_hash text default null
)
returns public.reports
language plpgsql security definer
set search_path = ''
as $$
declare
  v_report public.reports%rowtype;
  v_canonical text;
  v_hash bytea;
  v_client bytea := case
    when p_client_content_hash is null then null
    else decode(p_client_content_hash, 'hex')
  end;
  v_net bigint;
  v_signed_at timestamptz;
begin
  select * into v_report from public.reports where id = p_report_id for update;
  if not found then
    raise exception 'report % not found', p_report_id using errcode = 'no_data_found';
  end if;
  if not app.can_write_report(p_report_id) then
    raise exception 'not allowed to sign this Rapport' using errcode = 'insufficient_privilege';
  end if;

  if v_report.status <> 'draft' then
    -- Idempotent replay: same signer, same attestation, same answer.
    if v_report.signer_name = trim(p_signer_name)
       and (v_client is null or v_report.client_content_hash = v_client)
    then
      return v_report;
    end if;
    raise exception 'Rapport % ist bereits unterschrieben',
      coalesce(v_report.number_text, v_report.id::text)
      using errcode = 'check_violation';
  end if;

  if coalesce(trim(p_signer_name), '') = '' then
    raise exception 'der Name der unterzeichnenden Person fehlt' using errcode = 'check_violation';
  end if;
  if not exists (select 1 from public.report_time_lines where report_id = p_report_id)
     and not exists (select 1 from public.report_material_lines where report_id = p_report_id) then
    raise exception 'ein leerer Rapport kann nicht unterschrieben werden' using errcode = 'check_violation';
  end if;

  v_canonical := app.report_canonical_text(p_report_id);
  v_hash := extensions.digest(v_canonical, 'sha256');

  -- The whole point of the offline path. A mismatch means the content changed
  -- between the pad and the sync, so what is about to be stored is not what
  -- was signed — and storing it would launder that difference into a document
  -- bearing the customer's signature.
  if v_client is not null and v_client <> v_hash then
    raise exception
      'der Inhalt hat sich seit der Unterschrift geaendert; dieser Rapport kann nicht synchronisiert werden'
      using errcode = 'check_violation';
  end if;

  -- A device clock is not trusted, only used.
  --
  -- created_at is NOT a valid lower bound here, which is the trap: for a draft
  -- built offline it records when the row reached the server, not when it was
  -- made, so clamping against it would drag every offline signature forward to
  -- its own sync time and quietly erase the fact that it happened earlier.
  --
  -- The bound is a plausibility window instead. Thirty days is deliberately
  -- generous — a phone left in a van over a shutdown is a real thing — while
  -- still refusing a signature dated from a device whose clock is years out.
  -- Whatever the device claimed is preserved verbatim in signed_at_device
  -- regardless, so the clamp narrows the working value without destroying the
  -- evidence of what was asserted.
  v_signed_at := least(
    greatest(coalesce(p_signed_at_device, now()), now() - interval '30 days'),
    now()
  );

  select
      coalesce((select sum((l.minutes::bigint * l.rate_rappen + 30) / 60)
                  from public.report_time_lines l where l.report_id = p_report_id), 0)
    + coalesce((select sum((m.quantity_milli * m.unit_price_rappen + 500) / 1000)
                  from public.report_material_lines m where m.report_id = p_report_id), 0)
  into v_net;

  update public.reports set
    status              = 'signed',
    signer_name         = trim(p_signer_name),
    signature_path      = p_signature_path,
    signed_at           = v_signed_at,
    signed_at_device    = p_signed_at_device,
    signed_offline      = p_client_content_hash is not null,
    client_content_hash = v_client,
    total_net_rappen    = v_net,
    content_hash        = v_hash,
    snapshot = jsonb_build_object(
      'version', 1,
      'canonical_sha256', encode(v_hash, 'hex'),
      'signed_offline', p_client_content_hash is not null,
      'signed_at_device', p_signed_at_device,
      'report', to_jsonb(v_report) - 'snapshot' - 'content_hash',
      'time_lines', coalesce((select jsonb_agg(to_jsonb(l) order by l.performed_on, l.sort_order, l.id)
        from public.report_time_lines l where l.report_id = p_report_id), '[]'::jsonb),
      'material_lines', coalesce((select jsonb_agg(to_jsonb(m) order by m.sort_order, m.id)
        from public.report_material_lines m where m.report_id = p_report_id), '[]'::jsonb),
      'photos', coalesce((select jsonb_agg(jsonb_build_object(
          'attachment_id', a.id, 'storage_bucket', a.storage_bucket,
          'storage_path', a.storage_path) order by p.sort_order, a.id)
        from public.report_photos p join public.attachments a on a.id = p.attachment_id
        where p.report_id = p_report_id), '[]'::jsonb),
      'total_net_rappen', v_net)
  where id = p_report_id
  returning * into v_report;

  return v_report;
end; $$;

revoke execute on function
  public.sign_report(uuid, text, text, timestamptz, text) from public, anon;
grant execute on function
  public.sign_report(uuid, text, text, timestamptz, text) to authenticated;

-- The three-argument overload from 20260729092500 would now be ambiguous with
-- the defaulted one, and PostgREST resolves overloads by argument names — two
-- candidates matching the same call is an error rather than a preference.
drop function if exists public.sign_report(uuid, text, text);

-- ==================================== 3. the canonical text, for the device
-- The device must hash exactly what the server will. Rather than reimplement
-- the serialisation in Swift and hope the two stay aligned, the client asks
-- for the canonical text and hashes the bytes it is given.
--
-- That is not a weakening: the device is attesting to what it displayed and
-- hashed, and the server independently recomputes the same text from its own
-- rows at sync. A divergence still fails. What it removes is an entire class
-- of false mismatch caused by two implementations of one string format.
create or replace function public.report_canonical_text(p_report_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not app.can_read_report(p_report_id) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  return app.report_canonical_text(p_report_id);
end; $$;

revoke execute on function public.report_canonical_text(uuid) from public, anon;
grant execute on function public.report_canonical_text(uuid) to authenticated;

-- =============================== 4. idempotent creation for a replayed queue
-- A client that syncs and loses the response will replay. Every offline write
-- therefore carries an id the device generated, and a replay must be a no-op
-- rather than a duplicate.
--
-- These return the existing row on conflict instead of raising, so the queue
-- never has to interpret a unique-violation as success.
create or replace function public.sync_time_entry(
  p_id uuid,
  p_project_id uuid,
  p_profile_id uuid,
  p_started_at timestamptz,
  p_ended_at timestamptz default null,
  p_break_minutes integer default 0,
  p_note text default null,
  p_kind public.time_entry_kind default 'work',
  p_task_id uuid default null
)
returns public.time_entries
language plpgsql security definer
set search_path = ''
as $$
declare
  v_row public.time_entries%rowtype;
begin
  select * into v_row from public.time_entries where id = p_id;
  if found then
    -- Already synced. Not an error, and deliberately not an update either:
    -- a replay must not overwrite a correction made in the meantime.
    return v_row;
  end if;

  if not app.can_write_project(p_project_id) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  if p_profile_id <> (select auth.uid())
     and not app.is_office()
     and app.current_member_role() <> 'foreman' then
    raise exception 'not allowed to record time for someone else'
      using errcode = 'insufficient_privilege';
  end if;

  insert into public.time_entries
    (id, company_id, project_id, task_id, profile_id, kind,
     work_date, started_at, ended_at, break_minutes, note)
  values
    (p_id, '00000000-0000-0000-0000-000000000000', p_project_id, p_task_id,
     p_profile_id, p_kind,
     -- Placeholders; sync_time_entry() derives both before anything sees them.
     current_date, p_started_at, p_ended_at, coalesce(p_break_minutes, 0), p_note)
  returning * into v_row;

  return v_row;
end; $$;

revoke execute on function public.sync_time_entry(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  public.time_entry_kind, uuid) from public, anon;
grant execute on function public.sync_time_entry(
  uuid, uuid, uuid, timestamptz, timestamptz, integer, text,
  public.time_entry_kind, uuid) to authenticated;

create or replace function public.sync_material_line(
  p_id uuid,
  p_project_id uuid,
  p_description text,
  p_quantity_milli bigint,
  p_unit text default 'Stk',
  p_unit_price_rappen bigint default 0,
  p_task_id uuid default null
)
returns public.material_lines
language plpgsql security definer
set search_path = ''
as $$
declare
  v_row public.material_lines%rowtype;
begin
  select * into v_row from public.material_lines where id = p_id;
  if found then
    return v_row;
  end if;
  if not app.can_write_project(p_project_id) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;

  insert into public.material_lines
    (id, company_id, project_id, task_id, description, quantity_milli, unit, unit_price_rappen)
  values
    (p_id, '00000000-0000-0000-0000-000000000000', p_project_id, p_task_id,
     p_description, p_quantity_milli, coalesce(p_unit, 'Stk'),
     coalesce(p_unit_price_rappen, 0))
  returning * into v_row;

  return v_row;
end; $$;

revoke execute on function public.sync_material_line(
  uuid, uuid, text, bigint, text, bigint, uuid) from public, anon;
grant execute on function public.sync_material_line(
  uuid, uuid, text, bigint, text, bigint, uuid) to authenticated;

create or replace function public.sync_report_draft(
  p_id uuid,
  p_project_id uuid,
  p_title text default null,
  p_summary text default null
)
returns public.reports
language plpgsql security definer
set search_path = ''
as $$
declare
  v_row public.reports%rowtype;
begin
  select * into v_row from public.reports where id = p_id;
  if found then
    return v_row;
  end if;
  if not app.can_write_project(p_project_id) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;

  insert into public.reports (id, company_id, project_id, title, summary)
  values (p_id, '00000000-0000-0000-0000-000000000000', p_project_id, p_title, p_summary)
  returning * into v_row;

  return v_row;
end; $$;

revoke execute on function public.sync_report_draft(uuid, uuid, text, text)
  from public, anon;
grant execute on function public.sync_report_draft(uuid, uuid, text, text)
  to authenticated;
