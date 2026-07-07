# Supabase setup

The entire backend lives in this repo as migrations. You create an empty
hosted project once, link it, and push.

## 1. Create the project

1. Go to [supabase.com](https://supabase.com) → New project.
2. Pick a name (e.g. `ventline-prod`), a strong database password, and a
   region close to your crews.

## 2. Link and push the schema

From the repo root:

```sh
npm install
npx supabase login                       # opens the browser once
npx supabase link --project-ref <ref>    # ref = the id in your project URL
npx supabase db push                     # applies every migration in order
```

`db push` creates all tables, roles/permissions (RLS), storage buckets,
triggers, and RPC functions. It is idempotent — rerun it after pulling new
migrations.

## 3. Configure auth

Dashboard → Authentication → Sign In / Up:

- **Email** provider: enabled (it is by default).
- Recommended for field crews: disable "Confirm email" so workers can sign
  in immediately after signing up with an invite code
  (Authentication → Sign In / Up → Email → uncheck *Confirm email*).

No OAuth providers are needed — Ventline uses email + password + invite codes.

## 4. Collect the client credentials

Dashboard → Project Settings → API:

- **Project URL** → `NEXT_PUBLIC_SUPABASE_URL` (web) / `SUPABASE_URL` (iOS)
- **anon public key** → `NEXT_PUBLIC_SUPABASE_ANON_KEY` (web) / `SUPABASE_ANON_KEY` (iOS)

The anon key is safe to ship in clients: every table is protected by
row-level security; the anon key grants nothing by itself.

## 5. First user

The first person signs up in either client choosing **New company** — that
makes them the **owner**. Everyone else joins via invite codes created in
the People screen.

## Local development without Docker

`npm run db:validate` spins up a scratch Postgres 16 (no Docker needed),
applies every migration plus seed data, and runs the RLS permission test
suite (`scripts/rls-tests.sql`). Run it after any schema change.

`npm run db:types` regenerates the TypeScript and Swift model types from the
schema. Commit the regenerated files together with the migration that
changed them.

## Milestone 2 (not yet active)

- `supabase/functions/notify-push` — APNs push notifications (stub).
- `supabase/functions/cleanup-expired-media` — purges expired disappearing
  messages (`public.purge_expired_messages()`) and drains
  `media_deletion_queue` (stub).

Deploy them later with `npx supabase functions deploy <name>`.
