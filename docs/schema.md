# Schema & permissions

One Postgres schema (`public`) plus an internal `app` schema for RLS helper
functions. Multi-tenant: every row hangs off a `company_id`.

## Entities

```
companies ─┬─ profiles (1:1 auth.users; role: owner/manager/foreman/worker/customer)
           ├─ invites (8-char codes; optional auto-membership project list)
           └─ projects ─┬─ project_members (explicit access for foreman/worker/customer)
                        ├─ tasks ─ task_assignments
                        └─ messages (task_id null ⇒ project thread)
                             ├─ attachments (photo/voice/video; storage paths)
                             │    └─ photo_annotations (PencilKit vectors + rendered JPEG)
                             ├─ message_reads   (M2: read receipts)
                             └─ devices         (M2: APNs push targets)
```

- `tasks.status`: `todo → in_progress → done → approved` (+ `blocked`).
  Workers move their own tasks up to `done`; foreman/office `approve`.
  Stamps (`completed_by/at`, `approved_by/at`) are set by a trigger — clients
  cannot forge them.
- `messages.expires_at`: disappearing messages. RLS hides expired rows
  immediately; hard deletion is a scheduled job (M2).
- `messages.shared_with_customer` / `tasks.visible_to_customer`: the curated
  customer portal — customers see nothing unless explicitly shared.
- `project_overview` view: per-project task counts, last activity, member
  count, latest photo. Runs as `security_invoker`, so every caller sees
  RLS-filtered numbers.

## Role capabilities (enforced by RLS + triggers, not just the UI)

| | Owner | Manager | Foreman | Worker | Customer |
|---|---|---|---|---|---|
| See all company projects | ✓ | ✓ | membership | membership | membership |
| Create/edit projects | ✓ | ✓ | edit if member | — | — |
| Manage people & roles | ✓ | ✓ (not owners) | — | — | — |
| Create invites | ✓ | ✓ (not owner invites) | — | — | — |
| Add project members | ✓ | ✓ | workers only | — | — |
| Create/edit tasks | ✓ | ✓ | ✓ | status only, assigned tasks | — |
| Approve tasks | ✓ | ✓ | ✓ | — | — |
| Send messages/media | ✓ | ✓ | ✓ | ✓ | — |
| Edit own message | ≤15 min | ≤15 min | ≤15 min | ≤15 min | — |
| Delete messages | any (soft) | any (soft) | own | own | — |
| See tasks/messages | all | all | project | project | only items shared with them |

Cross-tenant isolation is absolute: no query path returns another company's
rows (asserted in `scripts/rls-tests.sql`).

## RPC functions (the API surface beyond plain tables)

| Function | Security | Purpose |
|---|---|---|
| `create_company(name, full_name)` | definer | bootstrap: first user founds a company as owner |
| `redeem_invite(code, full_name)` | definer | join a company with an invite code |
| `create_invite(role, full_name, project_ids)` | invoker | mint an 8-char invite code (office only via RLS) |
| `send_message(project, task, kind, body, attachments, shared, expires)` | invoker | atomic message + attachments insert |
| `delete_message(id)` | definer | soft delete (sender/office; definer needed because deleted rows become invisible to their own writer under the select policy) |
| `purge_expired_messages()` | definer, service-role only | hard-delete expired disappearing messages |

## Storage

Private buckets; all reads via short-lived signed URLs.

| Bucket | Path convention | Limit |
|---|---|---|
| `photos` | `{company_id}/{project_id}/{group}/{uuid}.jpg` | 10 MB |
| `voice` | same, `.m4a` | 20 MB |
| `video` | same, `.mp4` (uploads are M2) | 200 MB |
| `avatars` | `{profile_id}.jpg` | 5 MB |

Policies check path segment 1 = uploader's company and segment 2 = a project
the user can write to. Customers can only read objects referenced by a
message shared with them.

## Why some rules are triggers, not RLS

RLS cannot compare the old and new row in an UPDATE. Everything of the form
"workers may only change the status column" or "role changes involving owner
require an owner" lives in `BEFORE UPDATE` triggers
(`supabase/migrations/20260707000900_triggers.sql`). The RLS policies decide
*which rows* someone may touch; the triggers decide *what kind of change* is
allowed.

## Changing the schema

1. Add a new migration file under `supabase/migrations/` (timestamp prefix).
2. `npm run db:validate` — applies everything to a scratch Postgres and runs
   the permission tests. Extend `scripts/rls-tests.sql` for new rules.
3. `npm run db:types` — regenerate TS + Swift models; fix compile fallout.
4. `npx supabase db push` to the hosted project.
