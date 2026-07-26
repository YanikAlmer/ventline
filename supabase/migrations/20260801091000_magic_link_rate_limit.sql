-- Rate limiting on magic-link resolution.
--
-- The tokens are 256 bits of CSPRNG output, hashed at rest, so guessing one is
-- not a realistic attack and this is not what stops it. What this stops is
-- cheaper and more likely: somebody pointing a script at /r/ and making the
-- database resolve tokens as fast as it can answer, which costs a render-free
-- but very real amount of Postgres and edge-function time. It also puts a
-- ceiling on any *future* weakening of the token — a shorter link format, a
-- customer-friendly code — so the limit is in place before it is needed rather
-- than after.
--
-- **The client is identified by a hash of its IP, never the IP.** An IP is
-- personal data under revDSG, the only operation needed is equality, and a
-- hash supports equality. The same reasoning already coarsens the user agent
-- to a browser family in document_link_views: collect the discriminator, not
-- the identity. The salt is per-deployment so the hashes are not comparable
-- across environments or reversible by a rainbow table over the v4 space.

create table public.document_link_attempts (
  id bigint generated always as identity primary key,
  -- sha256(ip || salt). 32 bytes, no inet column anywhere.
  client_hash bytea not null,
  succeeded boolean not null,
  attempted_at timestamptz not null default now()
);

-- Partial: the limiter only ever counts failures, and successes are kept
-- purely so a support question ("did they open it?") has an answer for a day.
create index document_link_attempts_recent_idx
  on public.document_link_attempts (client_hash, attempted_at desc)
  where not succeeded;

alter table public.document_link_attempts enable row level security;
comment on table public.document_link_attempts is
  'Rate-limit ledger for magic links. Hashed client identifier only, purged daily. No policy: service_role and the cron owner see it, nobody else.';

-- Generated in-database and never returned, same as the renderer secret: a
-- salt that has to be carried between two systems is a salt that gets left
-- somewhere. Absent, hashing falls back to the unsalted digest, which still
-- limits correctly and only loses the cross-environment property.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'link_attempt_salt') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'), 'link_attempt_salt');
  end if;
end $$;

create or replace function app.client_hash(p_client_ip text)
returns bytea
language plpgsql stable security definer set search_path = '' as $$
declare v_salt text;
begin
  select decrypted_secret into v_salt
    from vault.decrypted_secrets where name = 'link_attempt_salt';
  return extensions.digest(coalesce(p_client_ip, 'unknown') || coalesce(v_salt, ''), 'sha256');
end; $$;

-- ============================================ resolve, with a ceiling
-- Twenty wrong tokens in fifteen minutes from one client is not a customer
-- who mistyped; a customer does not type these at all, they tap a link.
create or replace function public.resolve_document_link(
  p_token text,
  p_user_agent_family text default null,
  p_client_ip text default null
)
returns jsonb
language plpgsql security definer
set search_path = ''
as $$
declare
  v_link public.document_links%rowtype;
  v_result jsonb;
  v_client bytea;
  v_recent_failures integer;
begin
  v_client := app.client_hash(p_client_ip);

  select count(*) into v_recent_failures
  from public.document_link_attempts a
  where a.client_hash = v_client
    and not a.succeeded
    and a.attempted_at > now() - interval '15 minutes';

  if v_recent_failures >= 20 then
    -- Deliberately the same reason string as a bad token. A distinct
    -- "rate_limited" would confirm that the *previous* twenty were being
    -- counted, which tells a prober their script is working as intended.
    -- The status code differs so honest clients can back off; the body does
    -- not, so nothing about any token leaks.
    return jsonb_build_object('ok', false, 'reason', 'invalid_or_expired',
                              'retry_after_seconds', 900);
  end if;

  select * into v_link from public.document_links
   where token_hash = extensions.digest(p_token, 'sha256');

  -- One indistinguishable answer for unknown, revoked and expired: a caller
  -- must not be able to tell a wrong token from an expired one.
  if not found or v_link.revoked_at is not null or v_link.expires_at <= now() then
    insert into public.document_link_attempts (client_hash, succeeded)
    values (v_client, false);
    return jsonb_build_object('ok', false, 'reason', 'invalid_or_expired');
  end if;

  insert into public.document_link_attempts (client_hash, succeeded)
  values (v_client, true);

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

revoke execute on function public.resolve_document_link(text, text, text)
  from public, anon, authenticated;
grant execute on function public.resolve_document_link(text, text, text) to service_role;

-- The two-argument version is gone: leaving it callable would leave an
-- unlimited path to the same work.
drop function if exists public.resolve_document_link(text, text);

-- A day is long enough to answer "was this link opened, and from how many
-- places" and short enough that a hashed IP is not a record anyone keeps.
select cron.schedule('ventline-prune-link-attempts', '13 4 * * *',
                     $$delete from public.document_link_attempts
                        where attempted_at < now() - interval '24 hours';$$);
