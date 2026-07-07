-- Extensions and the internal `app` schema (helpers only — never exposed via the API).

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app;

-- API roles may execute app.* helpers referenced from RLS policies, but the
-- schema itself is not in PostgREST's exposed list, so nothing here becomes
-- an endpoint.
grant usage on schema app to authenticated, anon;
