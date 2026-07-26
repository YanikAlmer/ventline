-- Make the PDF actually happen.
--
-- The renderer worked from the day it was deployed, but nothing ever called
-- it. Every path that hands a customer a document — the magic link, the
-- office's own copy — reads `pdf_path`, and `pdf_path` was only ever populated
-- by invoking the function by hand. A signed Rapport therefore resolved to a
-- link with no PDF behind it, and the failure was silent on both sides: the
-- customer saw a page without a document, and nothing anywhere recorded that
-- a render had been expected.
--
-- The fix follows the pattern push already uses: the database nudges, the
-- edge function does the work.
--
--   * A row leaving 'draft' fires a pg_net POST. Fire-and-forget, after
--     commit, so a slow or dead renderer can never block a signature.
--   * A sweeper picks up anything that has no PDF a few minutes later —
--     because fire-and-forget means exactly that, and a dropped nudge must
--     not cost a document.
--
-- Also persists `qr_payload`, which the invoice table has always had a column
-- and two CHECK constraints for and which nothing ever wrote.

-- ============================================ 1. persist the QR payload
-- The column is documented as "the exact string encoded into the QR code,
-- kept for reproducibility and for arguing about a payment that went astray",
-- and it was null on every row. The renderer recomputed the payload on each
-- run, so the printed bill was right — but there was no stored artefact to
-- argue *from*, and the two CHECK constraints guarding payload size and the
-- trailing-newline trap were dead code that had never once been evaluated.
--
-- Written in a second UPDATE rather than the first: app.qr_bill_payload reads
-- the row, so it must run after the number, reference and totals have landed.
-- The immutability guard permits this — it seals number, reference, totals and
-- the IBAN, and qr_payload is none of those.
create or replace function public.issue_invoice(p_invoice_id uuid)
returns public.invoices
language plpgsql security definer
set search_path = ''
as $$
declare
  v_inv public.invoices%rowtype;
  v_bill public.company_billing_settings%rowtype;
  v_cust public.customers%rowtype;
  v_period text;
  v_net bigint;
  v_tax bigint;
  v_number bigint;
  v_is_qr_iban boolean;
begin
  select * into v_inv from public.invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'invoice % not found', p_invoice_id using errcode = 'no_data_found';
  end if;
  if v_inv.company_id <> app.current_company_id() or not app.is_office() then
    raise exception 'only the office can issue invoices' using errcode = 'insufficient_privilege';
  end if;
  if v_inv.status <> 'draft' then
    raise exception 'Rechnung % ist bereits ausgestellt',
      coalesce(v_inv.number_text, v_inv.id::text) using errcode = 'check_violation';
  end if;

  select * into v_bill from public.company_billing_settings where company_id = v_inv.company_id;
  if not found or v_bill.iban is null then
    raise exception 'die Zahlungsangaben des Betriebs fehlen (IBAN)'
      using errcode = 'check_violation';
  end if;
  select * into v_cust from public.customers where id = v_inv.customer_id;

  if not exists (select 1 from public.invoice_lines where invoice_id = p_invoice_id) then
    raise exception 'eine Rechnung ohne Positionen kann nicht ausgestellt werden'
      using errcode = 'check_violation';
  end if;

  -- Net per line, then tax ONCE PER RATE GROUP.
  delete from public.invoice_tax_groups where invoice_id = p_invoice_id;
  insert into public.invoice_tax_groups (invoice_id, rate_bp, net_rappen, tax_rappen)
  select p_invoice_id, l.mwst_rate_bp, sum(l.net_rappen)::bigint,
         case when v_bill.mwst_status = 'not_registered' then 0
              else app.mwst_rappen(sum(l.net_rappen)::bigint, l.mwst_rate_bp) end
  from public.invoice_lines l
  where l.invoice_id = p_invoice_id
  group by l.mwst_rate_bp;

  select coalesce(sum(net_rappen), 0), coalesce(sum(tax_rappen), 0)
    into v_net, v_tax
  from public.invoice_tax_groups where invoice_id = p_invoice_id;

  v_period := to_char(timezone('Europe/Zurich', now()), 'YYYY');
  v_number := app.next_document_number(v_inv.company_id, 'invoice', v_period);
  v_is_qr_iban := app.is_qr_iban(v_bill.iban);

  update public.invoices set
    status      = 'issued',
    period_key  = v_period,
    number      = v_number,
    number_text = v_period || '-' || lpad(v_number::text, 4, '0'),
    reference_type = case when v_is_qr_iban then 'QRR'::public.qr_reference_type
                          else 'NON'::public.qr_reference_type end,
    reference = case when v_is_qr_iban
                     then app.mint_qr_reference(v_inv.company_id, v_number)
                     else null end,
    invoice_date = current_date,
    creditor_name        = v_bill.creditor_name,
    creditor_street      = v_bill.creditor_street,
    creditor_building_no = v_bill.creditor_building_no,
    creditor_post_code   = v_bill.creditor_post_code,
    creditor_town        = v_bill.creditor_town,
    creditor_country     = v_bill.creditor_country,
    creditor_iban        = v_bill.iban,
    creditor_uid_digits  = v_bill.uid_digits,
    creditor_mwst_status = v_bill.mwst_status,
    debtor_name        = v_cust.name,
    debtor_street      = v_cust.street,
    debtor_building_no = v_cust.building_no,
    debtor_post_code   = v_cust.post_code,
    debtor_town        = v_cust.town,
    debtor_country     = v_cust.country,
    total_net_rappen   = v_net,
    total_tax_rappen   = v_tax,
    total_gross_rappen = v_net + v_tax,
    due_date = current_date + coalesce(v_bill.payment_terms_days, 30)
  where id = p_invoice_id;

  update public.invoices
     set qr_payload = app.qr_bill_payload(p_invoice_id)
   where id = p_invoice_id
  returning * into v_inv;

  return v_inv;
end; $$;

revoke execute on function public.issue_invoice(uuid) from public, anon;
grant execute on function public.issue_invoice(uuid) to authenticated;

-- Backfill the rows issued before the column was written. Safe because the
-- payload is derived entirely from frozen columns: recomputing it today on a
-- bill issued yesterday yields the same 31 lines it was printed with.
update public.invoices
   set qr_payload = app.qr_bill_payload(id)
 where status <> 'draft' and qr_payload is null;

-- ==================================================== 2. the nudge
-- Same shape as app.nudge_notifier: read the endpoint and the shared secret
-- from the vault, POST, and swallow everything. A renderer that is down, slow
-- or misconfigured must never stop a Rapport from being signed — the sweeper
-- below is what makes the delivery reliable, not this call.
create or replace function app.nudge_renderer(p_kind text, p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_url text; v_secret text;
begin
  select decrypted_secret into v_url
    from vault.decrypted_secrets where name = 'render_document_url';
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'render_document_secret';
  if v_url is null or v_secret is null then return; end if;

  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object('Content-Type', 'application/json',
                                  'x-ventline-secret', v_secret),
    body    := jsonb_build_object('kind', p_kind, 'id', p_id),
    -- Generous: a Rapport with twenty site photos is a real amount of work,
    -- and a timeout here only abandons the response, not the render.
    timeout_milliseconds := 20000);
exception when others then
  return;
end; $$;

-- Fires on the transition out of 'draft' and nowhere else. record_rendered_pdf
-- updates the same row to store pdf_path, so a trigger keyed on "the row
-- changed" rather than "the status left draft" would nudge itself forever.
create or replace function app.nudge_renderer_report()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'draft' and new.status <> 'draft' then
    perform app.nudge_renderer('report', new.id);
  end if;
  return null;
end; $$;

create or replace function app.nudge_renderer_invoice()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status = 'draft' and new.status <> 'draft' then
    perform app.nudge_renderer('invoice', new.id);
  end if;
  return null;
end; $$;

drop trigger if exists nudge_renderer on public.reports;
create trigger nudge_renderer after update of status on public.reports
  for each row execute function app.nudge_renderer_report();

drop trigger if exists nudge_renderer on public.invoices;
create trigger nudge_renderer after update of status on public.invoices
  for each row execute function app.nudge_renderer_invoice();

-- ================================================= 3. the sweeper
-- pg_net is fire-and-forget by design, so the nudge is a latency optimisation
-- and this is the actual guarantee. Anything non-draft that still has no PDF
-- after a couple of minutes gets another push.
--
-- Bounded twice over: p_limit per run, and a 7-day horizon. A document that
-- cannot be rendered at all — a corrupt photo, a bug — retries for a week and
-- then stops shouting, with render_runs recording that it never landed.
create table if not exists public.render_runs (
  id bigint generated always as identity primary key,
  ran_at timestamptz not null default now(),
  nudged integer not null,
  stuck integer not null
);

alter table public.render_runs enable row level security;
comment on table public.render_runs is
  'Sweeper bookkeeping. No policy: readable by service_role and the cron owner only.';

create or replace function public.render_pending_documents(p_limit integer default 20)
returns integer
language plpgsql security definer
set search_path = ''
as $$
declare
  v_nudged integer := 0;
  v_stuck integer;
  r record;
begin
  for r in
    select 'report'::text as kind, id from public.reports
     where status <> 'draft' and pdf_path is null
       and updated_at < now() - interval '2 minutes'
       and updated_at > now() - interval '7 days'
    union all
    select 'invoice', id from public.invoices
     where status <> 'draft' and pdf_path is null
       and updated_at < now() - interval '2 minutes'
       and updated_at > now() - interval '7 days'
    order by 1, 2
    limit p_limit
  loop
    perform app.nudge_renderer(r.kind, r.id);
    v_nudged := v_nudged + 1;
  end loop;

  -- Past the horizon: no longer retried, so it is recorded instead. A
  -- non-zero value here is the signal that something needs a human.
  select count(*) into v_stuck from (
    select 1 from public.reports
     where status <> 'draft' and pdf_path is null
       and updated_at <= now() - interval '7 days'
    union all
    select 1 from public.invoices
     where status <> 'draft' and pdf_path is null
       and updated_at <= now() - interval '7 days'
  ) s;

  insert into public.render_runs (nudged, stuck) values (v_nudged, v_stuck);
  return v_nudged;
end; $$;

revoke execute on function public.render_pending_documents(integer)
  from public, anon, authenticated;

select cron.schedule('ventline-render-sweep', '*/5 * * * *',
                     $$select public.render_pending_documents();$$);

select cron.schedule('ventline-prune-render-runs', '41 3 * * *',
                     $$delete from public.render_runs
                        where ran_at < now() - interval '30 days';$$);
