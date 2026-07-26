# Roadmap

Everything requested, in the order I would build it. Each slice is shippable on
its own and leaves the app in a working state.

Status legend: **DONE** · **PARTIAL** · **TODO**

---

## Where we are

| Capability | Status |
|---|---|
| Companies, invites, 5 roles, RLS | DONE |
| Projects, tasks (flat), approval workflow | DONE |
| Chat: project + task threads, photo, voice, markup, customer sharing | DONE |
| Customer portal (read-only, curated) | DONE |
| de/en localization, German default, Swiss conventions | DONE |
| Chat overview **schema** (threads, read cursor, mentions, refs, search) | DONE (`20260726090000`) |
| Chat overview **read model + UI** | DONE (`20260726100000`) |
| Push notifications | DONE — needs an Apple p8 key to actually deliver |
| Task hierarchy, task attachments | DONE (`20260728090000`) |
| Time capture, materials, Rapport, signature, PDF | TODO |
| Magic links, QR-Rechnung | TODO |

Decisions already made and locked in:

- **Naming**: `Arbeitspaket` (parent) / `Arbeitsschritt` (child); short forms
  **Paket** / **Schritt**. EN: Work package / Step. `Position` is deliberately
  left free for the invoice line item.
- **Money** is integer Rappen, **time** is integer minutes, **MWST rates** are
  integer basis points. No float ever touches money or tax.
- **Swiss German**: never "ß".
- RLS stays the single enforcement point. The service-role key never enters
  `web/` or `ios/`.

---

## Slice 1 — Chat overview — **DONE**

Goal: stop chat being a set of isolated threads you can only read one at a time.

**Done** (`supabase/migrations/20260726090000_chat_overview.sql`)

- `thread_id` generated column = `coalesce(task_id, project_id)`
- `thread_state` — trigger-maintained per-thread summary (preview, count, last sender)
- `thread_read_state` — per-person read cursor + `mark_thread_read()`
- `message_mentions` (+ `app.can_mention`), `message_refs` (task / attachment)
- German FTS (`german_unaccent`) + trigram fallback; `has_photo/voice/video` flags
- `send_message` v2 takes `p_mentions` / `p_refs`

**TODO — read model (RPCs)**

| RPC | Purpose |
|---|---|
| `inbox_page(...)` | Paged thread list with unread counts. Ordered by `thread_state.last_message_at` so the LIMIT short-circuits the per-thread count. |
| `inbox_attention()` | "Braucht deine Aufmerksamkeit" — unacknowledged mentions, unanswered questions. Bounded by construction. |
| `search_messages(...)` | FTS + filters: project, person, date range, has-photo, has-voice. Must also query a de-transliterated variant, because `unaccent` folds `ü`→`u`, not `ü`→`ue`. |
| `conversation_with(person, project?)` | The "what did I send that person, in this project" view. |
| `messages_around(message_id)` | Jump-to-context from a search hit. |

**TODO — UI (web + iOS)**

- **Kommunikation** screen. Not a flat list: grouped by project, task threads
  nested under their project, each row showing unread count and last preview.
- Pivot control: **nach Projekt / nach Person / nach Aufgabe**.
- Person view: pick a person → all threads you share, optionally narrowed to one
  project. This is the "don't mix up people across projects" ask.
- Search bar with the filter chips above.
- `@` autocomplete in the composer (writes `p_mentions`).
- `#` to reference an Arbeitspaket / Schritt, and a picker to reference an
  existing photo (writes `p_refs`).
- Mark-read on thread open; unread badges from `thread_read_state`.

**Realtime**: exactly two extra channels — `thread_state` filtered by
`company_id`, `message_mentions` filtered by `mentioned_profile_id`. Never
subscribe to `messages` company-wide.

---

## Slice 2 — Push notifications

Goal: the chat that already exists stops being invisible. **Highest
value-per-effort item on this list.**

**Architecture**: transactional outbox + `pg_net` nudge + `pg_cron` safety net.
Row triggers insert into `notification_outbox` *inside the writing transaction*
(never sent for a rolled-back write, never lost). A statement-level trigger fires
one payload-free nudge at the edge function; `pg_cron` drains every minute if the
nudge fails. Deadline reminders are scheduled by the same cron, so there is one
code path rather than two.

Rejected: raw Database Webhooks (fire-and-forget, no retry/dedupe, cannot express
deadline reminders) and polling (0–60 s latency is unacceptable on a jobsite).

**Tables**: `notification_outbox`, `notification_preferences` (quiet hours),
`project_mutes` (with optional expiry — "stumm bis Montag").

**Events**: new message in a thread you belong to · `@mention` · Arbeitspaket
assigned to you · status change (for foreman/office) · deadline approaching.

**Recipient resolution** must reuse the RLS visibility rules — a customer must
never receive an internal message. Single source of truth, one query.

**iOS**: two-stage permission. Stage 1 requests `.provisional` the moment
`AppState.phase` becomes `.ready` — **no system dialog at all**, notifications
arrive silently in Notification Centre. Stage 2 promotes to a real prompt at a
moment of proven value, not on first launch. Then register the APNs token into
the existing (currently unused) `devices` table, handle refresh, and prune on
APNs 410 Unregistered.

**Web push: skipped for MVP.** Managers sit at a desk with the tab open; Safari
and iOS-PWA support is disproportionate work.

> **Blocker**: needs an Apple Developer account — APNs **p8 key**, Team ID, Key
> ID. Nothing here can be finished without it.

---

## Slice 3 — Task hierarchy and task attachments — **DONE**

Goal: bigger work units with steps underneath, and media attached to the work
rather than only to a chat message.

Shipped in `supabase/migrations/20260728090000_task_hierarchy.sql` (plus
`20260728093000` for the appointment-window fix below):

- `tasks.parent_id` self-reference. **Additive**: existing rows became
  Arbeitspakete with `parent_id = null`. No data migration.
- `app.enforce_task_hierarchy()`: two levels only (checked from both
  directions), parent and child share a project, no self-parenting. It also
  makes `project_id` immutable for everyone — moving a task left its own chat
  thread behind, so the task and its history answered to two different
  projects' visibility rules.
- Effective customer visibility: a step is visible to a customer only if its
  package is. `app.package_visible_to_customer()` is used by the `tasks` policy,
  by `app.can_profile_read_task` (push), and by the storage gate, so all three
  agree by construction.
- `project_overview` counts **work packages only**; the progress chip
  (`4/7 Schritte`) counts steps per package.
- Attachments hang off a task or a message, never both
  (`num_nonnulls(message_id, task_id) = 1`), with `uploaded_by` stamped
  server-side. The customer storage gate now reaches objects through tasks, so
  a customer-visible task no longer shows a broken image.
- `due_time` + an appointment reminder 60–90 minutes ahead, on a quarter-hourly
  cron. **A bug found in testing**: the window pinned `due_date` to today while
  looking 90 minutes ahead, so every appointment in the first 90 minutes after
  midnight was silently skipped.
- Brought forward from slice 4's must-fix list: the own-object storage policies
  are now bucket-scoped.
- Video upload is wired for task attachments on both clients (200 MB, MP4/MOV,
  limits mirrored client-side).

**UI**: the project board groups work packages only; steps appear inside their
package behind a disclosure, never as peers. Both customer portals nest the
same way — a flat list would read as twice as much outstanding work. On iOS,
"My Tasks" labels each step with its package, so someone on five sites cannot
mix them up.

**Still open from this slice**

- Video in the **chat** composer. The bucket, enum and policies are used now,
  but only from the task-files path; the chat composer is still photo-only.
- The `+ Schritt` / `Add step` flow does not let you reorder steps; they are
  ordered by `sort_order` then `created_at` and nothing writes `sort_order`.

---

## Slice 4 — The Rapport loop

Goal: work performed → a signed document. This is the piece that creates a reason
to pay for the product.

- `time_entries` — start/stop plus manual correction, breaks, per person, linked
  to project and optionally to a work package. Swiss HLKS firms are under a
  **double** obligation (ArG Art. 46 / ArGV 1 Art. 73 *and* the universally
  binding GAV Gebäudetechnik), and the simplified regimes are effectively
  unavailable to installers — so full recording of start, end and breaks ≥30 min
  is the requirement.
- `time_entry_revisions` — append-only correction log. The model that survives an
  inspection is: one mutable current-truth row + an append-only revision log +
  a hard freeze once the record becomes a signed document.
- `material_lines` — description, quantity, unit, unit price in Rappen. Free text
  for MVP; shaped so a suissetec/NPK catalog can be added later.
- `reports` — aggregates time entries, material lines, selected photos and free
  text. Lifecycle `draft → signed → sent`, immutable after signing, sequential
  numbering per company.
- Signature captured on device into a **private** bucket, with signer name and
  timestamp. **Do not** capture geolocation: ArGV 3 Art. 26 and OR 328b limit
  employee location tracking and consent does not cure it.
- PDF rendered server-side so it is reproducible and can embed photos from
  private buckets.

> **Must fix before this ships**: `media_objects_update_own` /
> `media_objects_delete_own` are **not bucket-scoped**, so an uploader can delete
> their own object in *any* bucket. Harmless today; once signatures exist, a
> worker could delete the signature proving customer acceptance.

---

## Slice 5 — Magic links and QR-Rechnung — **DONE**

**Magic links** — customer opens a Rapport or invoice with no account.

- `document_links`: token **hashed at rest**, expiry, revocation, single-document
  scope, view audit.
- Serving model: a `SECURITY DEFINER` RPC that takes the token, granted to
  `service_role` **not** `anon`, fronted by one thin edge function that does
  nothing except mint short-TTL signed Storage URLs for the exact paths that RPC
  returned. **Postgres decides, the edge function signs.** No service-role key
  enters `web/` or `ios/`.
- `noindex`, rate limiting, and a friendly expiry page.

**QR-Rechnung** — the one place where "roughly right" is not acceptable.

- Build to Swiss Implementation Guidelines **v2.3** (in force; v2.4 applies from
  Nov 2026 and changes nothing for CHF billing).
- **Schema-shaping rule**: v2.3 removed combined address fields — only
  structured addresses are permitted. Creditor and debtor addresses need
  separate street / building-no / postcode / town / country columns **from day
  one**, or it is a migration later.
- Company billing settings configured once: IBAN or QR-IBAN, creditor address,
  MWST number. MWST rates 8.1 / 2.6 / 3.8.
- `invoices` + `invoice_lines` derived from an accepted Rapport.

**Decided**: Rapport + QR-bill with a **bexio** handoff. Ventline is the issuer
of record — it assigns the number, mints the reference and renders the bill the
customer pays against — because a draft created in bexio would give the customer
two payable documents with two references for one debt. The handoff ships as the
Treuhänder CSV export; the bexio API itself is still unbuilt, with
`bexio_invoice_id` / `customers.bexio_contact_id` as the seam.

Rate limiting: twenty failed resolutions in fifteen minutes per client, counted
against a **salted hash of the address, never the address**. The limit applies
before the token lookup, so a prober is refused even if their next guess would
have been right.

---

## Blockers and open decisions

1. **Apple Developer account** — APNs p8 key, Team ID, Key ID. Blocks slice 2,
   which is now the only slice not shipped. Also needs `DEVELOPMENT_TEAM` in
   `ios/project.yml`: the app is unsigned today, which is why the simulator
   never produced a push token.
2. ~~**Invoicing depth**~~ — settled: Rapport + QR-bill, Ventline as issuer of
   record, bexio receives a handoff. See slice 5.
3. **Web push** — recommend skipping for MVP.
4. **Email provider** for magic links (Resend / Postmark) and where it sends
   from, given revDSG data-residency expectations.

---

## Known limitations, recorded deliberately

- **German compound search.** Snowball does not decompose: a search for "Rohr"
  will not match "Lüftungsrohr" via FTS. A prefix query reaches the head of a
  compound and the trigram index covers tail and middle. Real decompounding needs
  hunspell dictionary files, which Supabase-hosted does not permit.
- **`unaccent` folds `ü`→`u`, not `ü`→`ue`.** Someone typing "lueftung" gets no
  FTS hit. `search_messages` compensates by also querying a de-transliterated
  variant; blind `ue`→`u` rewriting is wrong ("Steuerung" would break).
- **Disappearing messages (`messages.expires_at`)** conflict with retention
  expectations — purging a defect photo destroys evidence. Worth reconsidering
  before it is ever exposed in the UI.
- **Offline.** HVAC work happens in Heizungskeller and Tiefgaragen where signal
  fails. The current architecture is online-only (direct-to-Supabase, websocket
  chat, short-lived signed URLs). The small-job flow in slice 4 tolerates this
  because residential jobs have signal; plant-room work does not. Retrofitting
  offline is a data-layer rewrite — writes should carry client-generated
  idempotency keys from now on so it does not become one.
