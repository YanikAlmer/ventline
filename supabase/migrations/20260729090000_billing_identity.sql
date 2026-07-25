-- Billing identity: who is being billed, who is billing, and the Swiss
-- primitives that make a QR-Rechnung either valid or rejected by a bank.
--
-- Everything verifiable is verified here, in the database, as a CHECK
-- constraint. A wrong check digit or an illegal IBAN/reference-type pairing
-- must be unrepresentable, not merely unlikely: by the time a bad reference
-- reaches a PDF it has already been handed to a customer.
--
-- Built to Swiss Implementation Guidelines **v2.3** (in force). v2.4 applies
-- from Nov 2026 and changes nothing for CHF billing except widening the
-- language set; the one forward-compatible rule (QRR is CHF-only) is already
-- encoded below.

-- ==================================================== 1. QR check digits
-- Modulo-10 recursive, per SIX Annex B. The table is published only as an
-- image in the specification PDF, so it cannot be extracted — it is
-- transcribed here and pinned by the regression tests, which reproduce SIX's
-- own three worked examples.
create or replace function app.mod10_recursive(p_digits text)
returns integer
language plpgsql immutable strict
set search_path = ''
as $$
declare
  -- Row = carry, column = digit. 1-indexed, so both are offset by one below.
  k constant integer[][] := array[
    [0,9,4,6,8,2,7,1,3,5],
    [9,4,6,8,2,7,1,3,5,0],
    [4,6,8,2,7,1,3,5,0,9],
    [6,8,2,7,1,3,5,0,9,4],
    [8,2,7,1,3,5,0,9,4,6],
    [2,7,1,3,5,0,9,4,6,8],
    [7,1,3,5,0,9,4,6,8,2],
    [1,3,5,0,9,4,6,8,2,7],
    [3,5,0,9,4,6,8,2,7,1],
    [5,0,9,4,6,8,2,7,1,3]
  ];
  v_carry integer := 0;
  v_digit integer;
  i integer;
begin
  if p_digits !~ '^[0-9]*$' then
    raise exception 'mod10_recursive expects digits only, got %', p_digits
      using errcode = 'invalid_parameter_value';
  end if;

  for i in 1 .. length(p_digits) loop
    v_digit := substr(p_digits, i, 1)::integer;
    v_carry := k[v_carry + 1][v_digit + 1];
  end loop;

  return (10 - v_carry) % 10;
end;
$$;

comment on function app.mod10_recursive(text) is
  'SIX modulo-10 recursive check digit. Feed the first 26 digits of a QR reference; returns digit 27.';

-- A QR reference is exactly 27 digits: 26 payload + 1 check digit. The spec
-- also forbids an all-zero reference, which a naive zero-padded counter hits
-- on its very first row.
create or replace function app.is_valid_qrr(p_reference text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_reference is not null
     and p_reference ~ '^[0-9]{27}$'
     and p_reference !~ '^0{27}$'
     and substr(p_reference, 27, 1)::integer
         = app.mod10_recursive(substr(p_reference, 1, 26));
$$;

-- Creditor Reference (ISO 11649), used with a normal IBAN. "RF" + 2 check
-- digits + up to 21 alphanumerics, validated mod-97-10: rotate the first four
-- characters to the end, map A-Z to 10-35, take mod 97, expect 1.
create or replace function app.mod97_10(p_reference text)
returns integer
language plpgsql immutable strict
set search_path = ''
as $$
declare
  v_rotated text;
  v_numeric text := '';
  v_char    text;
  v_acc     bigint := 0;
  i integer;
begin
  v_rotated := substr(p_reference, 5) || substr(p_reference, 1, 4);

  for i in 1 .. length(v_rotated) loop
    v_char := upper(substr(v_rotated, i, 1));
    if v_char ~ '[0-9]' then
      v_numeric := v_numeric || v_char;
    elsif v_char ~ '[A-Z]' then
      v_numeric := v_numeric || (ascii(v_char) - 55)::text;
    else
      raise exception 'mod97_10: illegal character % in %', v_char, p_reference
        using errcode = 'invalid_parameter_value';
    end if;
  end loop;

  -- Chunked to stay inside bigint: the expanded string is far wider than 19
  -- digits, so a single ::numeric cast would be the only alternative.
  for i in 1 .. length(v_numeric) loop
    v_acc := (v_acc * 10 + substr(v_numeric, i, 1)::integer) % 97;
  end loop;

  return v_acc::integer;
end;
$$;

create or replace function app.is_valid_scor(p_reference text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_reference is not null
     and p_reference ~ '^RF[0-9]{2}[A-Za-z0-9]{1,21}$'
     and app.mod97_10(p_reference) = 1;
$$;

-- A QR-IBAN is a normal-looking CH/LI IBAN whose institution identification
-- (positions 5-9) falls in the reserved 30000-31999 range. This is derived,
-- never stored as a flag: a stored boolean drifts from the IBAN beside it, and
-- the pairing rule below depends on the two agreeing.
create or replace function app.is_qr_iban(p_iban text)
returns boolean
language sql immutable
set search_path = ''
as $$
  select p_iban is not null
     and p_iban ~ '^(CH|LI)[0-9]{2}[0-9]{5}[A-Z0-9]{12}$'
     and substr(p_iban, 5, 5)::integer between 30000 and 31999;
$$;

grant execute on function
  app.mod10_recursive(text),
  app.is_valid_qrr(text),
  app.mod97_10(text),
  app.is_valid_scor(text),
  app.is_qr_iban(text)
to authenticated;

-- ============================================================ 2. MWST
-- Swiss VAT, rounded to 5 Rappen half-up, applied **per rate group** and never
-- per line. Per-line-then-sum diverges by up to ~15 Rappen on a six-line
-- invoice and does not match the federal tax administration's own worked
-- examples; 1-Rappen rounding reproduces none of them.
--
-- The sign wrapper is load-bearing: Postgres integer division truncates toward
-- zero, so a credit note would otherwise round the wrong way and a reversal
-- would not cancel its original exactly.
create or replace function app.mwst_rappen(p_net_rappen bigint, p_rate_bp integer)
returns bigint
language sql immutable strict
set search_path = ''
as $$
  select (case when p_net_rappen < 0 then -1 else 1 end)::bigint
       * ((abs(p_net_rappen) * p_rate_bp + 25000) / 50000) * 5;
$$;

comment on function app.mwst_rappen(bigint, integer) is
  'Swiss VAT in Rappen, 5-Rappen half-up. Call once per rate group, never per line.';

grant execute on function app.mwst_rappen(bigint, integer) to authenticated;

-- ========================================================== 3. enums
-- 'not_registered' is a status, not a rate. A business below the turnover
-- threshold must show no rate, no tax column and no recapitulation at all —
-- modelling it as 0 % would print a tax statement it is not entitled to make,
-- and under MWSTG Art. 27 tax shown is tax owed.
create type public.mwst_status as enum (
  'registered_effective', 'registered_saldo', 'not_registered'
);

create type public.qr_reference_type as enum ('QRR', 'SCOR', 'NON');

-- Regie = time and materials, billed as worked. Pauschal = fixed price, where
-- the Rapport still records hours for internal costing but must never turn
-- into an hourly invoice.
create type public.billing_mode as enum ('regie', 'pauschal');

-- ======================================= 4. the tenant's billing identity
-- Structured address columns mirror the QR payload exactly, because v2.3
-- removed the combined address type: "the address of the parties involved can
-- only be delivered in a structured way". Lengths are the payload's, so a
-- value that fits here always fits there.
create table public.company_billing_settings (
  company_id uuid primary key references public.companies (id) on delete cascade,

  creditor_name          varchar(70) not null,
  creditor_street        varchar(70),
  creditor_building_no   varchar(16),
  creditor_post_code     varchar(16) not null,
  creditor_town          varchar(35) not null,
  creditor_country       char(2)     not null default 'CH',

  -- Unformatted, 21 characters, no spaces. Display grouping is the renderer's
  -- job; storing it grouped would break every comparison.
  iban char(21),

  mwst_status   public.mwst_status not null default 'not_registered',
  -- Canonical 9 digits: no "CHE-" prefix, no dots. Rendered as
  -- CHE-123.456.789 MWST at output time.
  uid_digits    char(9),
  saldo_rate_bp integer,

  -- A signed Rapport that states an amount is already an invoice under
  -- MWSTG Art. 3 lit. k. Default off keeps the Rapport an acknowledgement of
  -- work rather than a second, unnumbered invoice series.
  show_prices_on_rapport boolean not null default false,

  default_mwst_rate_bp integer not null default 810,
  default_hourly_rate_rappen bigint not null default 9500,
  payment_terms_days integer not null default 30,

  logo_path text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint cbs_iban_shape check (
    iban is null or iban ~ '^(CH|LI)[0-9]{2}[A-Z0-9]{17}$'
  ),
  constraint cbs_country_shape check (creditor_country ~ '^[A-Z]{2}$'),
  -- Postal code must never carry a country prefix — "CH-8000" is a very common
  -- Swiss data-entry habit and it corrupts the payload.
  constraint cbs_post_code_no_prefix check (creditor_post_code !~ '^[A-Za-z]{2}-'),
  constraint cbs_uid_shape check (uid_digits is null or uid_digits ~ '^[0-9]{9}$'),
  -- MWSTG Art. 26 Abs. 2 lit. a: the number must appear whenever tax is shown.
  constraint cbs_registered_has_uid check (
    mwst_status = 'not_registered' or uid_digits is not null
  ),
  constraint cbs_saldo_rate_only_for_saldo check (
    saldo_rate_bp is null or mwst_status = 'registered_saldo'
  ),
  constraint cbs_rate_known check (
    default_mwst_rate_bp in (810, 260, 380, 770, 250, 370, 800, 0)
  )
);

-- ==================================================== 5. the customer
-- Projects carry a free-text customer_display_name today, which is fine for a
-- portal heading and useless as a bill-to address. A customer is its own
-- entity because one is billed across many jobs.
create table public.customers (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,

  name varchar(70) not null,
  -- Structured, same lengths as the payload. Either the whole postal address
  -- is present or none of it is: a half-filled debtor block renders a broken
  -- payment part, so the constraint is table-level rather than per column.
  street        varchar(70),
  building_no   varchar(16),
  post_code     varchar(16),
  town          varchar(35),
  country       char(2) default 'CH',

  email text,
  phone text,
  notes text,

  -- Placeholder for the bexio handoff: filled once a contact has been matched
  -- or created over there. Never used as a key on this side.
  bexio_contact_id bigint,

  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customers_address_all_or_nothing check (
    num_nonnulls(post_code, town, country) in (0, 3)
  ),
  constraint customers_post_code_no_prefix check (
    post_code is null or post_code !~ '^[A-Za-z]{2}-'
  ),
  constraint customers_country_shape check (country is null or country ~ '^[A-Z]{2}$')
);

create index customers_company_idx on public.customers (company_id, name);
create unique index customers_bexio_uq
  on public.customers (company_id, bexio_contact_id)
  where bexio_contact_id is not null;

-- Projects gain a billing customer and a billing mode. Nullable: existing
-- projects have neither, and a project is perfectly usable without being
-- billable.
alter table public.projects
  add column customer_id uuid references public.customers (id) on delete set null,
  add column billing_mode public.billing_mode not null default 'regie';

create index projects_customer_idx
  on public.projects (customer_id) where customer_id is not null;

-- ================================================================ 6. RLS
alter table public.company_billing_settings enable row level security;
alter table public.customers               enable row level security;

grant select, insert, update on public.company_billing_settings to authenticated;
grant select, insert, update, delete on public.customers to authenticated;

-- Billing identity is office-only to read as well as write: it carries the
-- company's bank details, and a worker has no reason to see them.
create policy cbs_select on public.company_billing_settings
  for select to authenticated
  using (company_id = app.current_company_id() and app.is_office());

create policy cbs_insert on public.company_billing_settings
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.is_office());

create policy cbs_update on public.company_billing_settings
  for update to authenticated
  using (company_id = app.current_company_id() and app.is_office())
  with check (company_id = app.current_company_id() and app.is_office());

-- Customers are readable by anyone working the company's projects — a foreman
-- needs the name and phone number — but only office roles may edit them.
-- Customers themselves must never enumerate the customer list.
create policy customers_select on public.customers
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and app.current_member_role() <> 'customer'
  );

create policy customers_insert on public.customers
  for insert to authenticated
  with check (company_id = app.current_company_id() and app.is_office());

create policy customers_update on public.customers
  for update to authenticated
  using (company_id = app.current_company_id() and app.is_office())
  with check (company_id = app.current_company_id() and app.is_office());

create policy customers_delete on public.customers
  for delete to authenticated
  using (company_id = app.current_company_id() and app.is_office());

create trigger set_updated_at before update on public.company_billing_settings
  for each row execute function app.set_updated_at();
create trigger set_updated_at before update on public.customers
  for each row execute function app.set_updated_at();
