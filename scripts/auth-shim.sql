-- Minimal stand-in for the Supabase platform schemas, letting the real
-- migrations run against a plain Postgres 16 during validation. Mirrors the
-- exact surface our migrations and policies touch — nothing more.
--
-- NEVER apply this to a real Supabase project.

-- API roles ------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end;
$$;

grant usage on schema public to anon, authenticated, service_role;

create schema if not exists extensions;
grant usage on schema extensions to anon, authenticated, service_role;

-- auth schema ----------------------------------------------------------
create schema auth;

create table auth.users (
  id uuid primary key,
  email text unique,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Same mechanism PostgREST/Supabase use: claims arrive via the
-- request.jwt.claims GUC.
-- Guard the empty string BEFORE the cast, exactly as the real Supabase
-- auth.uid() does (and as auth.jwt() below already did). tests.reset() sets the
-- claims GUC to '' rather than NULL, and ''::jsonb throws — so casting first
-- made auth.uid() explode in any service-role write path that reaches a trigger.
create function auth.uid()
returns uuid
language sql stable
as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid;
$$;

create function auth.jwt()
returns jsonb
language sql stable
as $$
  select nullif(current_setting('request.jwt.claims', true), '')::jsonb;
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant execute on function auth.uid(), auth.jwt() to anon, authenticated, service_role;

-- storage schema -------------------------------------------------------
create schema storage;

create table storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz not null default now()
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner_id text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table storage.objects enable row level security;

-- Matches Supabase's storage.foldername(): all path segments except the last.
create function storage.foldername(name text)
returns text[]
language sql immutable
as $$
  select (string_to_array(name, '/'))[1 : array_length(string_to_array(name, '/'), 1) - 1];
$$;

grant usage on schema storage to anon, authenticated, service_role;
grant select on storage.buckets to anon, authenticated, service_role;
grant select, insert, update, delete on storage.objects to authenticated, service_role;
grant execute on function storage.foldername(text) to anon, authenticated, service_role;

-- platform extensions ---------------------------------------------------
-- Supabase provides pg_net, pg_cron and Vault; a plain Postgres does not.
-- Stub the surface the migrations touch so they apply unchanged locally and
-- the RLS suite exercises the real trigger/enqueue paths. Every stub is inert:
-- nudges go nowhere, cron jobs are recorded and never run, and the secrets
-- view is empty, which is exactly the "not configured" branch in production.

create schema net;

create table net.sent (
  id bigserial primary key,
  url text,
  headers jsonb,
  body jsonb,
  sent_at timestamptz not null default now()
);

create function net.http_post(
  url text,
  body jsonb default '{}',
  params jsonb default '{}',
  headers jsonb default '{}',
  timeout_milliseconds integer default 5000
) returns bigint
language sql
as $$
  insert into net.sent (url, headers, body) values (url, headers, body)
  returning id;
$$;

create schema cron;

create table cron.job (
  jobid bigserial primary key,
  jobname text unique,
  schedule text,
  command text
);

create function cron.schedule(job_name text, schedule text, command text)
returns bigint
language sql
as $$
  insert into cron.job (jobname, schedule, command)
  values (job_name, schedule, command)
  on conflict (jobname) do update set schedule = excluded.schedule,
                                      command = excluded.command
  returning jobid;
$$;

create schema vault;

-- Empty on purpose: app.nudge_notifier() must take its "not configured"
-- branch locally rather than attempting a real HTTP call.
create view vault.decrypted_secrets as
  select null::text as name, null::text as decrypted_secret where false;
