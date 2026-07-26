-- One secret, one home.
--
-- The renderer's shared secret was going to live in two places: the vault, so
-- app.nudge_renderer can send it, and the function's RENDER_SECRET env var, so
-- the function can check it. Keeping two copies of a secret in sync means it
-- has to be carried between them, and every carrier — a shell history, a CI
-- log, a chat transcript — is a place it can be left behind.
--
-- So it is generated inside Postgres, stored once in the vault, and never
-- returned to anyone. The function does not hold a copy; it presents the
-- header it received and asks whether it is right. An attacker who cannot
-- produce the header is refused, and there is no second copy to leak.
--
-- The cost is one round trip per request, against a render measured in
-- seconds. The benefit is that nobody — not the operator, not a deploy
-- script, not this transcript — ever has to see the value.

-- Generated, never printed. gen_random_bytes is pgcrypto's CSPRNG.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'render_document_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'), 'render_document_secret');
  end if;
end $$;

-- Verifies, never reveals. Granted to service_role alone: the renderer is the
-- only caller, and a function that *returned* the secret would put a copy back
-- on the wire, which is the thing this design exists to avoid.
--
-- Compared as digests rather than as text. The timing signal on a 256-bit
-- random value is not realistically exploitable over HTTP, but comparing
-- fixed-length hashes costs nothing and removes the question.
create or replace function public.verify_render_secret(p_secret text)
returns boolean
language plpgsql stable security definer
set search_path = ''
as $$
declare v_secret text;
begin
  if p_secret is null or length(p_secret) = 0 then
    return false;
  end if;
  select decrypted_secret into v_secret
    from vault.decrypted_secrets where name = 'render_document_secret';
  if v_secret is null then
    return false;
  end if;
  return extensions.digest(p_secret, 'sha256') = extensions.digest(v_secret, 'sha256');
end; $$;

revoke execute on function public.verify_render_secret(text)
  from public, anon, authenticated;
grant execute on function public.verify_render_secret(text) to service_role;

-- The endpoint is configuration, not a secret, and it is per-deployment: a
-- migration must not hardcode one project's ref. Set it once per environment:
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/render-document',
--     'render_document_url');
--
-- app.nudge_renderer returns silently while it is absent, so a fresh
-- environment degrades to "no PDFs yet" rather than to errors on signing.
