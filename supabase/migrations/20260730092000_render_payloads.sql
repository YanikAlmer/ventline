-- Everything the PDF renderer needs, as two SECURITY DEFINER calls.
--
-- The renderer was the only edge function reading tables directly, and it
-- failed on deploy with `permission denied for table reports` — service_role
-- has never been granted anything in this schema, not even on tables from the
-- first migration. notify-push and open-document never noticed because both go
-- through definer RPCs.
--
-- The fix is to make the renderer match rather than to open the tables up.
-- Granting service_role broad SELECT would work, but it would hand every row
-- of every table to anything holding the service key; these functions hand
-- over exactly one document's render inputs. The narrower surface is also the
-- one already established by open-document — "Postgres decides, the function
-- draws" — so this removes an inconsistency rather than adding a mechanism.

-- ========================= 1. the QR payload, minus the caller's identity
-- public.qr_bill_payload guards on app.current_company_id(), which is null for
-- service_role — so the guard silently passed rather than protecting anything.
-- The construction moves to the app schema where no guard is implied, and the
-- public wrapper keeps the check for real callers.
create or replace function app.qr_bill_payload(p_invoice_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v public.invoices%rowtype;
  v_lines text[];
begin
  select * into v from public.invoices where id = p_invoice_id;
  if not found then
    raise exception 'invoice % not found', p_invoice_id using errcode = 'no_data_found';
  end if;
  if v.status = 'draft' then
    raise exception 'eine Entwurfsrechnung hat noch keinen Zahlteil'
      using errcode = 'check_violation';
  end if;

  v_lines := array[
    'SPC', '0200', '1',
    v.creditor_iban,
    'S', coalesce(v.creditor_name, ''), coalesce(v.creditor_street, ''),
    coalesce(v.creditor_building_no, ''), coalesce(v.creditor_post_code, ''),
    coalesce(v.creditor_town, ''), coalesce(v.creditor_country, 'CH'),
    '', '', '', '', '', '', '',
    to_char(v.total_gross_rappen / 100.0, 'FM9999999990.00'),
    v.currency,
    case when v.debtor_name is null then '' else 'S' end,
    coalesce(v.debtor_name, ''), coalesce(v.debtor_street, ''),
    coalesce(v.debtor_building_no, ''), coalesce(v.debtor_post_code, ''),
    coalesce(v.debtor_town, ''), coalesce(v.debtor_country, ''),
    coalesce(v.reference_type::text, 'NON'), coalesce(v.reference, ''),
    coalesce('Rechnung ' || v.number_text, ''),
    'EPD'
  ];
  return array_to_string(v_lines, E'\r\n');
end; $$;

create or replace function public.qr_bill_payload(p_invoice_id uuid)
returns text
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.invoices i
    where i.id = p_invoice_id
      and i.company_id = app.current_company_id()
      and app.is_office()
  ) then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  return app.qr_bill_payload(p_invoice_id);
end; $$;

revoke execute on function public.qr_bill_payload(uuid) from public, anon;
grant execute on function public.qr_bill_payload(uuid) to authenticated;

-- ==================================================== 2. render payloads
create or replace function public.report_render_payload(p_report_id uuid)
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'report', to_jsonb(r) - 'snapshot'
      || jsonb_build_object('content_hash_hex', encode(r.content_hash, 'hex')),
    'company', jsonb_build_object('name', c.name),
    'time_lines', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.performed_on, l.sort_order, l.id)
      from public.report_time_lines l where l.report_id = r.id), '[]'::jsonb),
    'material_lines', coalesce((
      select jsonb_agg(to_jsonb(m) order by m.sort_order, m.id)
      from public.report_material_lines m where m.report_id = r.id), '[]'::jsonb),
    -- Bucket and path only. The renderer fetches the bytes itself; handing it
    -- a list of paths is narrower than handing it the attachments table.
    'photos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'bucket', a.storage_bucket, 'path', a.storage_path)
             order by p.sort_order, a.id)
      from public.report_photos p
      join public.attachments a on a.id = p.attachment_id
      where p.report_id = r.id), '[]'::jsonb)
  )
  from public.reports r
  join public.companies c on c.id = r.company_id
  where r.id = p_report_id and r.status <> 'draft';
$$;

revoke execute on function public.report_render_payload(uuid)
  from public, anon, authenticated;
grant execute on function public.report_render_payload(uuid) to service_role;

create or replace function public.invoice_render_payload(p_invoice_id uuid)
returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'invoice', to_jsonb(i) || jsonb_build_object('qr_payload', app.qr_bill_payload(i.id)),
    'company', jsonb_build_object('name', c.name),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.sort_order, l.id)
      from public.invoice_lines l where l.invoice_id = i.id), '[]'::jsonb),
    'tax_groups', coalesce((
      select jsonb_agg(to_jsonb(g) order by g.rate_bp)
      from public.invoice_tax_groups g where g.invoice_id = i.id), '[]'::jsonb)
  )
  from public.invoices i
  join public.companies c on c.id = i.company_id
  where i.id = p_invoice_id and i.status <> 'draft';
$$;

revoke execute on function public.invoice_render_payload(uuid)
  from public, anon, authenticated;
grant execute on function public.invoice_render_payload(uuid) to service_role;

-- ================================================= 3. the write-back
-- The only column the renderer may touch, on the only two tables it renders.
-- Note this deliberately does NOT go through the reports column grants, which
-- exclude pdf_path: those exist to stop a *client* writing it, and the
-- renderer is not a client.
create or replace function public.record_rendered_pdf(
  p_kind text,
  p_id uuid,
  p_path text,
  p_sha256 text
)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  if p_kind = 'report' then
    update public.reports
       set pdf_path = p_path,
           pdf_sha256 = decode(p_sha256, 'hex'),
           pdf_generated_at = now()
     where id = p_id and status <> 'draft';
  elsif p_kind = 'invoice' then
    update public.invoices
       set pdf_path = p_path,
           pdf_sha256 = decode(p_sha256, 'hex'),
           pdf_generated_at = now()
     where id = p_id and status <> 'draft';
  else
    raise exception 'unknown document kind %', p_kind
      using errcode = 'invalid_parameter_value';
  end if;
end; $$;

revoke execute on function public.record_rendered_pdf(text, uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.record_rendered_pdf(text, uuid, text, text) to service_role;
