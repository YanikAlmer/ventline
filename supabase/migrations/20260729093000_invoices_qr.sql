-- Invoices and the Swiss QR-Rechnung.
--
-- Ventline is the issuer of record: it assigns the number, mints the QR
-- reference, and renders the bill the customer pays against. bexio receives a
-- handoff afterwards and must never create a payable document of its own —
-- two documents for one debt, with two references, reconcile to neither.
--
-- Built to SIX Implementation Guidelines v2.3.

create type public.invoice_status as enum ('draft', 'issued', 'sent', 'paid', 'cancelled');

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  project_id uuid not null references public.projects (id) on delete restrict,
  customer_id uuid not null references public.customers (id) on delete restrict,
  -- The Rapport this bill settles. Nullable: not every invoice comes from one.
  report_id uuid references public.reports (id) on delete restrict,

  status public.invoice_status not null default 'draft',

  period_key  text,
  number      bigint,
  number_text text,

  invoice_date date,
  due_date     date,
  service_date_from date,
  service_date_to   date,

  -- Creditor and debtor are SNAPSHOTS, not joins. An invoice states who billed
  -- whom on the day it was issued; a later change of address must not restate
  -- a document the customer already holds.
  creditor_name        varchar(70),
  creditor_street      varchar(70),
  creditor_building_no varchar(16),
  creditor_post_code   varchar(16),
  creditor_town        varchar(35),
  creditor_country     char(2),
  creditor_iban        char(21),
  creditor_uid_digits  char(9),
  creditor_mwst_status public.mwst_status,

  debtor_name        varchar(70),
  debtor_street      varchar(70),
  debtor_building_no varchar(16),
  debtor_post_code   varchar(16),
  debtor_town        varchar(35),
  debtor_country     char(2),

  currency char(3) not null default 'CHF',
  reference_type public.qr_reference_type,
  reference text,

  total_net_rappen   bigint not null default 0,
  total_tax_rappen   bigint not null default 0,
  total_gross_rappen bigint not null default 0,

  -- The exact string encoded into the QR code, kept for reproducibility and
  -- for arguing about a payment that went astray.
  qr_payload text,
  qr_spec_version text not null default '2.3',

  pdf_path text,
  pdf_sha256 bytea,
  pdf_generated_at timestamptz,

  sent_at timestamptz,
  paid_at timestamptz,

  -- bexio handoff bookkeeping. Nullable placeholders: the seam exists, the
  -- integration does not yet.
  bexio_invoice_id bigint,
  bexio_synced_at timestamptz,
  bexio_sync_error text,

  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint invoices_number_pairs check (
    (status = 'draft' and number is null and period_key is null)
    or (status <> 'draft' and number is not null and period_key is not null
        and invoice_date is not null and creditor_iban is not null)
  ),
  constraint invoices_totals_add_up check (
    total_gross_rappen = total_net_rappen + total_tax_rappen
  ),
  -- IG v2.3: 0.01 to 999'999'999.99. Zero is a reserved sentinel for the
  -- "DO NOT USE FOR PAYMENT" variant, which is out of scope, so it is excluded.
  constraint invoices_amount_range check (
    status = 'draft' or total_gross_rappen between 1 and 99999999999
  ),
  constraint invoices_currency check (currency in ('CHF', 'EUR')),
  constraint invoices_iban_shape check (
    creditor_iban is null or creditor_iban ~ '^(CH|LI)[0-9]{2}[A-Z0-9]{17}$'
  ),

  -- The cross-field rule that is violated most often in practice, and the
  -- reason it lives in the database: a QR-IBAN takes QRR and nothing else; a
  -- normal IBAN takes SCOR or NON and never QRR. Both wrong pairings are
  -- accepted by naive code and rejected by the bank.
  constraint invoices_reference_pairing check (
    reference_type is null
    or (reference_type = 'QRR'
        and app.is_qr_iban(creditor_iban)
        and app.is_valid_qrr(reference))
    or (reference_type = 'SCOR'
        and not app.is_qr_iban(creditor_iban)
        and app.is_valid_scor(reference))
    or (reference_type = 'NON'
        and not app.is_qr_iban(creditor_iban)
        and reference is null)
  ),
  -- Forward-compatible with v2.4, harmless today: QRR is CHF-only.
  constraint invoices_qrr_is_chf check (currency = 'CHF' or reference_type is distinct from 'QRR'),
  -- The debtor block is all-or-nothing; a half-filled one renders a broken
  -- payment part.
  constraint invoices_debtor_all_or_nothing check (
    num_nonnulls(debtor_name, debtor_post_code, debtor_town, debtor_country) in (0, 4)
  ),
  constraint invoices_payload_size check (
    qr_payload is null or octet_length(qr_payload) <= 997
  ),
  -- A trailing newline is the single most common cause of a rejected payload.
  constraint invoices_payload_no_trailing_newline check (
    qr_payload is null or qr_payload !~ E'[\r\n]$'
  )
);

create unique index invoices_number_uq
  on public.invoices (company_id, period_key, number) where number is not null;
create index invoices_project_idx on public.invoices (project_id, created_at desc);
create index invoices_company_status_idx on public.invoices (company_id, status);
create unique index invoices_report_uq
  on public.invoices (report_id) where report_id is not null and status <> 'cancelled';

create table public.invoice_lines (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  description text not null,
  quantity_milli bigint not null default 1000,
  unit text not null default 'Stk',
  unit_price_rappen bigint not null default 0,
  net_rappen bigint not null default 0,
  -- Frozen on the line. A reprint of a 2023 invoice must still render 7.7 %,
  -- so the rate is never resolved from a rates table at render time.
  mwst_rate_bp integer not null default 810,
  service_date date,
  sort_order integer not null default 0,

  constraint invoice_lines_rate_known check (
    mwst_rate_bp in (810, 260, 380, 770, 250, 370, 800, 0)
  )
);

create index invoice_lines_invoice_idx on public.invoice_lines (invoice_id, sort_order);

-- The Art. 26 Abs. 2 lit. f recapitulation, persisted rather than recomputed
-- at render time. Tax is computed once per rate group; per-line-then-sum
-- diverges from the federal tax administration's own worked examples.
create table public.invoice_tax_groups (
  invoice_id uuid not null references public.invoices (id) on delete cascade,
  rate_bp integer not null,
  net_rappen bigint not null,
  tax_rappen bigint not null,
  primary key (invoice_id, rate_bp)
);

-- ================================================== QR reference minting
-- Flat zero-padded per-tenant sequence: 26 digits of payload plus the mod-10
-- check digit. The spec forbids an all-zero reference, which a naive counter
-- would produce on its very first row — hence the offset.
create or replace function app.mint_qr_reference(p_company uuid, p_number bigint)
returns text
language sql stable security definer
set search_path = ''
as $$
  select body || app.mod10_recursive(body)::text
  from (
    -- 6-digit per-tenant discriminator + 20-digit invoice number = 26 digits.
    -- The discriminator keeps two companies' references distinct at the same
    -- invoice number, and being >= 100000 it also guarantees the reference is
    -- never all zeros — which the specification forbids and which a naive
    -- zero-padded counter produces on its very first row.
    select (abs(hashtext(p_company::text)) % 900000 + 100000)::text
           || lpad(p_number::text, 20, '0') as body
  ) s;
$$;

grant execute on function app.mint_qr_reference(uuid, bigint) to authenticated;

-- ================================================= issue an invoice
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
  -- sum() over bigint returns numeric; the cast is required for the function
  -- lookup and is exact, since every input is already an integer Rappen value.
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
  -- Allocated into a variable first, because everything below must land in ONE
  -- update: the immutability guard seals the row the moment status leaves
  -- 'draft', so a second pass to fill in number_text and the reference would
  -- be refused by our own trigger.
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
  where id = p_invoice_id
  returning * into v_inv;

  return v_inv;
end; $$;

revoke execute on function public.issue_invoice(uuid) from public, anon;
grant execute on function public.issue_invoice(uuid) to authenticated;

-- ===================================== build the 31-line QR payload
-- Emitted exactly as SIX orders it. Lines that must exist but stay empty are
-- emitted empty: "optional" in the specification means the *line* is
-- mandatory, not the value. The seven ultimate-creditor lines are reserved and
-- must be blank. Separator is CRLF, with no terminator — a trailing newline is
-- the classic rejection.
create or replace function public.qr_bill_payload(p_invoice_id uuid)
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
  if v.company_id <> app.current_company_id() then
    raise exception 'not allowed' using errcode = 'insufficient_privilege';
  end if;
  if v.status = 'draft' then
    raise exception 'eine Entwurfsrechnung hat noch keinen Zahlteil'
      using errcode = 'check_violation';
  end if;

  v_lines := array[
    'SPC',                                        -- 1  QRType
    '0200',                                       -- 2  Version
    '1',                                          -- 3  Coding (UTF-8)
    v.creditor_iban,                              -- 4  IBAN
    'S',                                          -- 5  Cdtr AdrTp
    coalesce(v.creditor_name, ''),                -- 6
    coalesce(v.creditor_street, ''),              -- 7
    coalesce(v.creditor_building_no, ''),         -- 8
    coalesce(v.creditor_post_code, ''),           -- 9
    coalesce(v.creditor_town, ''),                -- 10
    coalesce(v.creditor_country, 'CH'),           -- 11
    '', '', '', '', '', '', '',                   -- 12-18 UltmtCdtr: reserved, must be blank
    to_char(v.total_gross_rappen / 100.0, 'FM9999999990.00'),  -- 19 Amt
    v.currency,                                   -- 20 Ccy
    case when v.debtor_name is null then '' else 'S' end,      -- 21 UltmtDbtr AdrTp
    coalesce(v.debtor_name, ''),                  -- 22
    coalesce(v.debtor_street, ''),                -- 23
    coalesce(v.debtor_building_no, ''),           -- 24
    coalesce(v.debtor_post_code, ''),             -- 25
    coalesce(v.debtor_town, ''),                  -- 26
    coalesce(v.debtor_country, ''),               -- 27
    coalesce(v.reference_type::text, 'NON'),      -- 28 RmtInf Tp
    coalesce(v.reference, ''),                    -- 29 RmtInf Ref
    coalesce('Rechnung ' || v.number_text, ''),   -- 30 Ustrd
    'EPD'                                         -- 31 Trailer
  ];

  return array_to_string(v_lines, E'\r\n');
end; $$;

revoke execute on function public.qr_bill_payload(uuid) from public, anon;
grant execute on function public.qr_bill_payload(uuid) to authenticated;

create trigger set_updated_at before update on public.invoices
  for each row execute function app.set_updated_at();

-- Same shape as reports: sealed columns are simply not writable from the API.
create or replace function app.guard_invoice()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.status <> 'draft' or new.number is not null then
      raise exception 'Rechnungen werden als Entwurf angelegt'
        using errcode = 'check_violation';
    end if;
    select p.company_id into strict new.company_id
    from public.projects p where p.id = new.project_id;
    new.created_by := (select auth.uid());
    return new;
  end if;

  if old.status <> 'draft' then
    if new.status = 'draft'
       or new.number is distinct from old.number
       or new.reference is distinct from old.reference
       or new.reference_type is distinct from old.reference_type
       or new.total_gross_rappen is distinct from old.total_gross_rappen
       or new.creditor_iban is distinct from old.creditor_iban
    then
      raise exception 'Rechnung % ist ausgestellt und kann nicht geaendert werden',
        coalesce(old.number_text, old.id::text) using errcode = 'check_violation';
    end if;
  end if;
  return new;
end; $$;

create trigger guard_invoice before insert or update on public.invoices
  for each row execute function app.guard_invoice();

-- ================================================================ RLS
alter table public.invoices          enable row level security;
alter table public.invoice_lines     enable row level security;
alter table public.invoice_tax_groups enable row level security;

grant select, insert, delete on public.invoices to authenticated;
grant update (status, customer_id, report_id, due_date, service_date_from,
              service_date_to, sent_at, paid_at, pdf_path, bexio_invoice_id,
              bexio_synced_at, bexio_sync_error)
  on public.invoices to authenticated;
grant select, insert, update, delete on public.invoice_lines to authenticated;
grant select on public.invoice_tax_groups to authenticated;

-- Invoices are office-only, full stop. A worker has no business reading what
-- the shop charges, and a customer receives a PDF by link rather than a row.
create policy invoices_all_office on public.invoices
  for all to authenticated
  using (company_id = app.current_company_id() and app.is_office())
  with check (company_id = app.current_company_id() and app.is_office());

create policy invoice_lines_all_office on public.invoice_lines
  for all to authenticated
  using (exists (select 1 from public.invoices i
                  where i.id = invoice_id and i.company_id = app.current_company_id())
         and app.is_office())
  with check (exists (select 1 from public.invoices i
                       where i.id = invoice_id and i.company_id = app.current_company_id())
              and app.is_office());

create policy invoice_tax_groups_select on public.invoice_tax_groups
  for select to authenticated
  using (exists (select 1 from public.invoices i
                  where i.id = invoice_id and i.company_id = app.current_company_id())
         and app.is_office());
