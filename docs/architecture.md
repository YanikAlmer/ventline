# Architecture

Ventline replaces WhatsApp-based job-site coordination with one structured
channel: **projects → tasks → task-scoped chat**, plus an at-a-glance
overview for the office. Work chat stays in the work app.

```
┌─────────────┐     ┌──────────────┐
│  iOS app    │     │ Web dashboard │        clients
│  SwiftUI    │     │ Next.js 16    │
└──────┬──────┘     └──────┬───────┘
       │  supabase-swift    │  @supabase/supabase-js + @supabase/ssr
       ▼                    ▼
┌───────────────────────────────────────────┐
│                Supabase                    │
│  Auth (email+password, invite codes)       │
│  Postgres (RLS = the authorization layer)  │
│  Storage (private buckets, signed URLs)    │
│  Realtime (postgres_changes on messages)   │
│  Edge functions (M2: push, media cleanup)  │
└───────────────────────────────────────────┘
```

## Key decisions

- **No app server.** Both clients talk to Supabase directly. All
  authorization is row-level security plus `BEFORE` triggers in Postgres —
  a single enforcement point that both clients (and any future client)
  inherit. See [schema.md](schema.md).
- **Invite-code onboarding.** Companies are closed teams. A manager mints an
  8-char code (optionally pre-scoped to projects, e.g. for customers);
  workers sign up with the code and land in the right company with the right
  role. No email round-trips on a job site.
- **Task-scoped chat.** Every message belongs to a project and optionally a
  task. Marking a task done posts a system message into its thread, so
  completion conversations happen where the work is.
- **Customer portal is curation, not access.** Customers are `profiles` with
  role `customer` and a membership row on their project. They see only
  `visible_to_customer` tasks and `shared_with_customer` messages/photos —
  enforced in RLS, rendered read-only in both clients.
- **Milestone-2-ready schema.** Video attachments, disappearing messages
  (`expires_at`), read receipts, and push-notification device tokens are in
  the schema now, so shipping those features later is client work plus two
  edge functions — no migration churn.
- **Media pipeline.** Clients downscale photos (≤2048 px JPEG), upload to a
  private bucket under `{company}/{project}/…`, then call the atomic
  `send_message` RPC with the storage paths. Reads go through short-lived
  signed URLs.
- **Photo markup, twice.** Annotations store PencilKit vector strokes in
  image-pixel space (re-editable on iOS) *and* a flattened JPEG render
  (displayable anywhere, including the customer portal).

## Verification without Docker or Xcode

- `npm run db:validate` — real Postgres 16 scratch cluster + an auth/storage
  shim (`scripts/auth-shim.sql`), every migration, seed data, and
  `scripts/rls-tests.sql`: per-role allow **and deny** assertions, including
  cross-tenant isolation, using the same `request.jwt.claims` mechanism
  PostgREST uses.
- `npm run db:types` — TypeScript and Swift models are generated from the
  live scratch schema (`scripts/gen-types.mjs`, using @supabase/postgres-meta
  directly — no Docker). Schema drift becomes a compile error.
- Web: `npm run build` + `tsc --noEmit` + eslint.
- iOS: written against the pinned supabase-swift **2.50.0** source; built and
  run from Xcode on a Mac (see [ios-setup.md](ios-setup.md)).

## Milestones

**M1 (this repo):** projects, tasks with the done→approved flow, chat with
text/photos/voice, photo markup, invites & people management, customer
portal, manager overview — iOS + web.

**M2:** video messages, disappearing-message UI + scheduled purge, APNs push
(`notify-push` edge function + device registration), read receipts, web
voice recording, offline outbox.
