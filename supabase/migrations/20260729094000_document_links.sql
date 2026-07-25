-- Magic links: a customer opens their Rapport or invoice without an account.
--
-- The serving model, stated once so it is not re-litigated: **Postgres decides,
-- the edge function signs.** A SECURITY DEFINER RPC takes the token, validates
-- it, and returns the exact storage paths that token entitles the holder to.
-- One thin edge function mints short-TTL signed URLs for precisely those paths
-- and nothing else. The service-role key never enters web/ or ios/.
--
-- The token is hashed at rest. A database backup, a leaked read replica or an
-- over-broad SELECT therefore yields no working links — the plaintext exists
-- only in the response that created it and in the URL the customer holds.

create type public.document_link_kind as enum ('report', 'invoice');

create table public.document_links (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,

  kind public.document_link_kind not null,
  report_id  uuid references public.reports (id) on delete cascade,
  invoice_id uuid references public.invoices (id) on delete cascade,

  -- sha256 of the plaintext token. Never the token itself.
  token_hash bytea not null,

  expires_at timestamptz not null,
  revoked_at timestamptz,

  view_count integer not null default 0,
  last_viewed_at timestamptz,

  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),

  -- Single-document scope, enforced rather than assumed.
  constraint document_links_one_target check (
    (kind = 'report'  and report_id is not null and invoice_id is null)
    or (kind = 'invoice' and invoice_id is not null and report_id is null)
  )
);

create unique index document_links_token_uq on public.document_links (token_hash);
create index document_links_report_idx
  on public.document_links (report_id) where report_id is not null;
create index document_links_invoice_idx
  on public.document_links (invoice_id) where invoice_id is not null;

-- Who opened it, and when. A customer claiming they never received the Rapport
-- is a conversation this table settles.
create table public.document_link_views (
  id bigserial primary key,
  link_id uuid not null references public.document_links (id) on delete cascade,
  viewed_at timestamptz not null default now(),
  -- Coarse only. No IP address: it is personal data with no purpose here
  -- beyond curiosity, and revDSG Art. 6 makes "we might want it later" not a
  -- purpose.
  user_agent_family text
);

create index document_link_views_link_idx on public.document_link_views (link_id, viewed_at desc);

-- ============================================================== issue
-- Returns the plaintext token EXACTLY ONCE. It is not recoverable afterwards;
-- losing it means issuing a new link, which is the correct behaviour.
create or replace function public.create_document_link(
  p_kind public.document_link_kind,
  p_document_id uuid,
  p_valid_days integer default 90
)
returns table (link_id uuid, token text, expires_at timestamptz)
language plpgsql security definer
set search_path = ''
as $$
declare
  v_company uuid;
  v_token text;
  v_id uuid;
  v_expires timestamptz;
begin
  if p_valid_days is null or p_valid_days < 1 or p_valid_days > 365 then
    raise exception 'die Gueltigkeit muss zwischen 1 und 365 Tagen liegen'
      using errcode = 'check_violation';
  end if;

  if p_kind = 'report' then
    select r.company_id into v_company from public.reports r
     where r.id = p_document_id and app.can_write_report(r.id) and r.status <> 'draft';
    if v_company is null then
      raise exception 'Rapport nicht gefunden oder noch nicht unterschrieben'
        using errcode = 'insufficient_privilege';
    end if;
  else
    select i.company_id into v_company from public.invoices i
     where i.id = p_document_id
       and i.company_id = app.current_company_id() and app.is_office()
       and i.status <> 'draft';
    if v_company is null then
      raise exception 'Rechnung nicht gefunden oder noch nicht ausgestellt'
        using errcode = 'insufficient_privilege';
    end if;
  end if;

  -- 32 bytes of CSPRNG, base64url. gen_random_bytes comes from pgcrypto.
  v_token := translate(encode(extensions.gen_random_bytes(32), 'base64'), '+/=', '-_');
  v_expires := now() + make_interval(days => p_valid_days);

  insert into public.document_links
    (company_id, kind, report_id, invoice_id, token_hash, expires_at, created_by)
  values (
    v_company, p_kind,
    case when p_kind = 'report'  then p_document_id end,
    case when p_kind = 'invoice' then p_document_id end,
    extensions.digest(v_token, 'sha256'),
    v_expires,
    (select auth.uid())
  )
  returning id into v_id;

  return query select v_id, v_token, v_expires;
end; $$;

revoke execute on function public.create_document_link(public.document_link_kind, uuid, integer)
  from public, anon;
grant execute on function public.create_document_link(public.document_link_kind, uuid, integer)
  to authenticated;

create or replace function public.revoke_document_link(p_link_id uuid)
returns void
language plpgsql security definer
set search_path = ''
as $$
begin
  update public.document_links
     set revoked_at = now()
   where id = p_link_id
     and company_id = app.current_company_id()
     and revoked_at is null
     and (app.is_office()
          or (report_id is not null and app.can_write_report(report_id)));
end; $$;

revoke execute on function public.revoke_document_link(uuid) from public, anon;
grant execute on function public.revoke_document_link(uuid) to authenticated;

-- ============================================================= redeem
-- Granted to service_role ONLY. `anon` must never reach this: a token is a
-- bearer credential, and letting the public API resolve one turns a leaked
-- URL into a queryable oracle. The edge function holds the service role and
-- does nothing except sign the paths this returns.
create or replace function public.resolve_document_link(
  p_token text,
  p_user_agent_family text default null
)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_link public.document_links%rowtype;
  v_result jsonb;
begin
  select * into v_link from public.document_links
   where token_hash = extensions.digest(p_token, 'sha256');

  -- One indistinguishable answer for unknown, revoked and expired: a caller
  -- must not be able to tell a wrong token from an expired one.
  if not found or v_link.revoked_at is not null or v_link.expires_at <= now() then
    return jsonb_build_object('ok', false, 'reason', 'invalid_or_expired');
  end if;

  update public.document_links
     set view_count = view_count + 1, last_viewed_at = now()
   where id = v_link.id;
  insert into public.document_link_views (link_id, user_agent_family)
  values (v_link.id, left(p_user_agent_family, 60));

  if v_link.kind = 'report' then
    select jsonb_build_object(
      'ok', true,
      'kind', 'report',
      'company_name', c.name,
      'number', r.number_text,
      'signed_at', r.signed_at,
      'signer_name', r.signer_name,
      'project_name', p.name,
      'summary', r.summary,
      -- The ONLY storage path the edge function is entitled to sign.
      'pdf', jsonb_build_object('bucket', 'documents', 'path', r.pdf_path)
    ) into v_result
    from public.reports r
    join public.companies c on c.id = r.company_id
    join public.projects  p on p.id = r.project_id
    where r.id = v_link.report_id;
  else
    select jsonb_build_object(
      'ok', true,
      'kind', 'invoice',
      'company_name', c.name,
      'number', i.number_text,
      'invoice_date', i.invoice_date,
      'due_date', i.due_date,
      'total_gross_rappen', i.total_gross_rappen,
      'currency', i.currency,
      'pdf', jsonb_build_object('bucket', 'documents', 'path', i.pdf_path)
    ) into v_result
    from public.invoices i
    join public.companies c on c.id = i.company_id
    where i.id = v_link.invoice_id;
  end if;

  return coalesce(v_result, jsonb_build_object('ok', false, 'reason', 'invalid_or_expired'));
end; $$;

revoke execute on function public.resolve_document_link(text, text)
  from public, anon, authenticated;
grant execute on function public.resolve_document_link(text, text) to service_role;

-- ================================================================ RLS
alter table public.document_links      enable row level security;
alter table public.document_link_views enable row level security;

-- SELECT only, and never the hash — the office needs to see that a link
-- exists, when it expires and whether it was opened. Creation and revocation
-- go through the definer RPCs above.
grant select (id, company_id, kind, report_id, invoice_id, expires_at,
              revoked_at, view_count, last_viewed_at, created_by, created_at)
  on public.document_links to authenticated;
grant select on public.document_link_views to authenticated;

create policy document_links_select on public.document_links
  for select to authenticated
  using (
    company_id = app.current_company_id()
    and app.current_member_role() <> 'customer'
  );

create policy document_link_views_select on public.document_link_views
  for select to authenticated
  using (
    exists (
      select 1 from public.document_links l
      where l.id = link_id
        and l.company_id = app.current_company_id()
        and app.current_member_role() <> 'customer'
    )
  );

-- ==================================================== documents bucket
-- Rendered deliverables live apart from source media: a customer may read a
-- PDF they hold a link to, but must never be able to enumerate jobsite photos.
-- Nothing is readable directly — every read is a signed URL minted by the edge
-- function after the RPC above approved the exact path.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('documents', 'documents', false, 25 * 1024 * 1024, array['application/pdf'])
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('signatures', 'signatures', false, 2 * 1024 * 1024, array['image/png'])
on conflict (id) do nothing;

-- Signature images: written by the crew on site, read by anyone who can read
-- the Rapport. Never deletable — a signature that can be removed proves
-- nothing. Note this relies on the bucket-scoped own-object policies from
-- 20260728090000, which deliberately do NOT list these two buckets.
create policy signatures_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'signatures'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.can_write_project(app.safe_uuid((storage.foldername(name))[2]))
  );

create policy signatures_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'signatures'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.current_member_role() <> 'customer'
  );

-- Generated PDFs are written by the renderer (service role) and read by the
-- office. Customers reach them only through a signed URL.
create policy documents_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = app.current_company_id()::text
    and app.current_member_role() <> 'customer'
  );
