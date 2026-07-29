-- The bexio handoff, as far as it can go without credentials.
--
-- Ventline stays the issuer of record: it assigns the number, mints the QR
-- reference and renders the bill the customer pays against. bexio receives the
-- invoice afterwards for the books. A draft created in bexio would give the
-- customer two payable documents with two references for one debt.
--
-- What is built here is everything that does not require an OAuth app: the
-- per-company configuration the API demands, and a function that assembles the
-- exact JSON body POST /2.0/kb_invoice expects. What is NOT built is the call
-- itself. That needs an OAuth client id and secret from bexio, a redirect flow,
-- and token storage — none of which can be written blind, and all of which is
-- the easy half once the mapping below is right.
--
-- The mapping is the hard half, because of one thing that is easy to miss
-- until an import fails: **bexio identifies tax by `tax_id`, not by a rate.**
-- That id refers to a row in the *customer's own* bexio account, so 8.1 % is a
-- different number in every installation. Nothing can be hardcoded, and any
-- integration that assumes otherwise books the wrong VAT into somebody's
-- ledger. Hence a per-company map rather than a constant.

create table public.company_bexio_settings (
  company_id uuid primary key references public.companies (id) on delete cascade,

  -- The contact in bexio the invoice is billed to comes from
  -- customers.bexio_contact_id; this is the fallback used when a customer has
  -- not been matched yet, so an export still produces a valid body.
  default_contact_id bigint,

  -- kb_item_status_id: bexio's document status. Account-specific like
  -- everything else here. A draft status is the safe default — the handoff
  -- should land in bexio for a human to look at, not post itself.
  draft_status_id bigint,

  -- Ventline MWST rate in basis points -> bexio tax_id.
  -- e.g. {"810": 17, "260": 19, "380": 21, "0": 23}
  tax_ids jsonb not null default '{}'::jsonb,

  -- Set once the operator has actually confirmed these against their account.
  -- Until then an export is a preview, and says so.
  verified_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint company_bexio_tax_ids_is_object check (jsonb_typeof(tax_ids) = 'object')
);

create trigger set_updated_at before update on public.company_bexio_settings
  for each row execute function app.set_updated_at();

alter table public.company_bexio_settings enable row level security;

grant select, insert, update, delete on public.company_bexio_settings to authenticated;

create policy company_bexio_settings_all_office on public.company_bexio_settings
  for all to authenticated
  using (company_id = app.current_company_id() and app.is_office())
  with check (company_id = app.current_company_id() and app.is_office());

-- ============================================== the outbound payload
-- Returns the body of POST https://api.bexio.com/2.0/kb_invoice.
--
-- Assembled in Postgres rather than in a client for the same reason
-- qr_bill_payload is: the numbers that go to the accounting system must be the
-- numbers on the document the customer received, and the only way to guarantee
-- that is to read them from the same frozen row.
--
-- Positions are KbPositionCustom — bexio's line type that carries its own
-- amount and tax rather than referencing an article. Ventline's lines are free
-- text, so there is no article to reference.
create or replace function public.bexio_invoice_payload(p_invoice_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_inv public.invoices%rowtype;
  v_cfg public.company_bexio_settings%rowtype;
  v_contact bigint;
  v_positions jsonb;
  v_missing text[] := '{}';
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if not found then
    raise exception 'invoice % not found', p_invoice_id using errcode = 'no_data_found';
  end if;
  if v_inv.company_id <> app.current_company_id() or not app.is_office() then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  if v_inv.status = 'draft' then
    raise exception 'eine Entwurfsrechnung wird nicht uebergeben'
      using errcode = 'check_violation';
  end if;

  select * into v_cfg from public.company_bexio_settings
   where company_id = v_inv.company_id;

  select c.bexio_contact_id into v_contact
    from public.customers c where c.id = v_inv.customer_id;
  v_contact := coalesce(v_contact, v_cfg.default_contact_id);

  -- Collected rather than raised: the point of a preview is to show the
  -- operator every gap at once, not to fail on the first one and make them
  -- discover the rest one round trip at a time.
  if v_contact is null then
    v_missing := v_missing || 'contact_id';
  end if;
  if v_cfg.draft_status_id is null then
    v_missing := v_missing || 'kb_item_status_id';
  end if;

  select jsonb_agg(
           jsonb_build_object(
             'type', 'KbPositionCustom',
             'amount', to_char(l.quantity_milli / 1000.0, 'FM9999999990.000'),
             'unit_price', to_char(l.unit_price_rappen / 100.0, 'FM9999999990.00'),
             'text', l.description,
             -- Null when unmapped, and reported below. Sending a wrong id is
             -- worse than sending none: it books real VAT against the wrong
             -- rate and nothing downstream will question it.
             'tax_id', (v_cfg.tax_ids ->> l.mwst_rate_bp::text)::bigint
           ) order by l.sort_order, l.id)
    into v_positions
    from public.invoice_lines l
   where l.invoice_id = p_invoice_id;

  if exists (
    select 1 from public.invoice_lines l
     where l.invoice_id = p_invoice_id
       and (v_cfg.tax_ids ->> l.mwst_rate_bp::text) is null
  ) then
    v_missing := v_missing || 'tax_id';
  end if;

  return jsonb_build_object(
    'endpoint', 'POST https://api.bexio.com/2.0/kb_invoice',
    'ready', v_missing = '{}' and v_cfg.verified_at is not null,
    'missing', to_jsonb(v_missing),
    'ventline_invoice', v_inv.number_text,
    'body', jsonb_strip_nulls(jsonb_build_object(
      'contact_id', v_contact,
      'kb_item_status_id', v_cfg.draft_status_id,
      'is_valid_from', v_inv.invoice_date,
      'is_valid_to', v_inv.due_date,
      'currency_id', null,
      -- The number the customer is paying against. bexio must not mint its
      -- own, or the two documents disagree about what is owed and under which
      -- reference.
      'reference', v_inv.number_text,
      'api_reference', v_inv.id::text,
      'positions', coalesce(v_positions, '[]'::jsonb)
    ))
  );
end; $$;

revoke execute on function public.bexio_invoice_payload(uuid) from public, anon;
grant execute on function public.bexio_invoice_payload(uuid) to authenticated;

-- ============================================== recording the handoff
-- Called once an invoice really has been created in bexio, by whatever means —
-- the eventual API client, or a person pasting the payload today. Idempotent
-- on purpose: the seam has to tolerate being told twice.
create or replace function public.mark_bexio_synced(
  p_invoice_id uuid,
  p_bexio_invoice_id bigint
)
returns public.invoices
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inv public.invoices%rowtype;
begin
  select * into v_inv from public.invoices where id = p_invoice_id for update;
  if not found then
    raise exception 'invoice % not found', p_invoice_id using errcode = 'no_data_found';
  end if;
  if v_inv.company_id <> app.current_company_id() or not app.is_office() then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;

  if v_inv.bexio_invoice_id is not null then
    if v_inv.bexio_invoice_id <> p_bexio_invoice_id then
      raise exception 'Rechnung % wurde bereits als bexio-Beleg % uebergeben',
        v_inv.number_text, v_inv.bexio_invoice_id using errcode = 'check_violation';
    end if;
    return v_inv;
  end if;

  update public.invoices
     set bexio_invoice_id = p_bexio_invoice_id,
         bexio_synced_at = now(),
         bexio_sync_error = null
   where id = p_invoice_id
  returning * into v_inv;

  return v_inv;
end; $$;

revoke execute on function public.mark_bexio_synced(uuid, bigint) from public, anon;
grant execute on function public.mark_bexio_synced(uuid, bigint) to authenticated;
