# Slice 4 decisions — Rapport, QR-Rechnung, bexio handoff

Written before the schema, because several of these are unrepresentable later.
Sources: the research pass of 2026-07-26 (8 parallel investigations + an
adversarial completeness critique).

---

## The decision everything else depends on

**Ventline is the issuer of record. bexio is a bookkeeping mirror.**

Ventline assigns the invoice number, mints the QR reference, and renders the
QR-bill the customer pays against. bexio receives a handoff *after the fact*.

The critique caught a contradiction that would otherwise have shipped: a
"create it as a draft in bexio and let the tradesman finalise it there" handoff
means **bexio** assigns its own number and generates its own QR-bill from its
own bank account — so the customer ends up holding two documents for one debt,
with two different references, and the bank reconciliation matches neither.

Consequence, stated plainly: the bexio handoff must never create a payable
document. v1 exports a file (see below); if the API path is built later it must
write a document that is already-issued-elsewhere, never a draft awaiting
bexio's own numbering.

---

## Scope

### In v1

| Thing | Note |
|---|---|
| `customers` with structured addresses | QR-bill debtor; v2.3 permits structured only |
| Company billing identity | creditor address, IBAN/QR-IBAN, MWST status, UID |
| Time entries + append-only revisions | start/end/breaks, integer minutes, never hard-deleted |
| Material lines | integer thousandths quantity, integer Rappen price |
| Rapport: draft → signed → sent | gapless per-company number assigned **at signing** |
| On-device signature | raster + stroke data, stroke data never leaves the system |
| Server-rendered PDF | async job, Liberation Sans, photos embedded |
| QR-Rechnung to IG **v2.3** | QRR/SCOR/NON, check digits enforced in the database |
| Magic link | hashed token, no customer login |
| Treuhänder/bexio export | CSV with rate-group breakdown |

### Deliberately not in v1 — placeholders recorded, no columns invented

- **GAV overtime accounting** (Überstunden A/B counters, night/Sunday
  surcharges, monthly statements, Jahresbruttoarbeitszeit from Anhang 8). This
  is a payroll product, not a Rapport. Time entries record what happened; they
  do not settle it.
- **camt.053/054 payment reconciliation.** Without it, QRR's automatic
  per-invoice matching has no consumer — we still mint QRR because the
  reference must be stable from day one, but nothing ingests bank files yet.
- **Teilrechnungen / Akonto / Schlussrechnung**, credit notes, Mahnwesen,
  Skonto, Verzugszins.
- **eBill**, print-and-post.
- **Offline capture.** See the open question below; v1 is online-only.
- **bexio API integration.** The seam exists; v1 exports a file.

---

## Engineer's calls (not asked, just decided)

- **Liberation Sans** — the only licence-free face among the four the spec
  permits.
- **Support IBAN and QR-IBAN both**, deriving the mode from the IID range
  (positions 5–9 numeric, 30000–31999). Asking a tradesman "is this a QR-IBAN?"
  is the wrong product.
- **Number format `YYYY-NNNN`, reset per calendar year**, Europe/Zurich.
- **Drafts get no human-readable number** — a deleted draft must not burn one.
- **QRR scheme: flat zero-padded per-tenant sequence.** No bank has asked for a
  grouping prefix.
- **Async PDF generation with a job table.** The Edge Function CPU ceiling is
  the binding constraint once photos are embedded; discovering that in
  production is not a plan.
- **Photo cap 20 per Rapport, 1600 px long edge.**
- **Strip EXIF on upload.** Nobody in the research said this, and it matters:
  the schema deliberately stores no coordinates anywhere, and an unstripped
  iPhone photo would reintroduce exactly the location trail that design
  forbids — with the employee's own device as the source.
- **MWST: 5-Rappen half-up, per rate group, never per line.** Reproduces all
  four of ESTV's published worked examples; 1-Rappen rounding reproduces none.
- **The signed Rapport shows hours and quantities, not money**, by default.
  A document that settles consideration is already an invoice under MWSTG
  Art. 3 lit. k, which would drag Art. 26/27 and a second number series along
  with it. `show_prices_on_rapport` exists and defaults to false.
- **Stroke dynamics never leave the system** — not to bexio, not in the emailed
  PDF, not in any view or export.
- **Print the document SHA-256 on the customer's PDF.** A free external anchor
  for the hash chain.
- **Data residency: the Supabase project is in `eu-central-2` (Zurich).** No
  foreign-transfer notice is needed above the signature pad. Re-check this if
  the project ever moves.

---

## Open questions — genuinely for the product owner

These are **placeholders in the schema**: the columns exist and are nullable or
defaulted conservatively, so answering later is a config change, not a migration.

1. **Regie vs. Pauschal.** On a fixed-price job the Rapport records hours for
   internal costing and must *not* produce an hourly invoice. One boolean
   changes the whole billing path. → `projects.billing_mode`, default `regie`.
2. **Rate card.** Where does an hourly rate come from — per role (Monteur /
   Vorarbeiter / Lernender), per customer, per project? Plus the surcharges a
   Swiss shop actually bills: Anfahrtspauschale, Kleinmaterialpauschale,
   material markup. → `rate_cards` shipped with a single default rate;
   everything else placeheld.
3. **Is the customer with no email in scope?** Magic link covers WhatsApp/SMS
   sharing. Print-and-post is real work and is not built.
4. **Offline capture — DECIDED: supported.** Implemented in `20260730091000`
   and `ios/Ventline/Core/Offline/`.

   The objection was never the plumbing, it was that a Rapport signed offline
   has no number yet, so "the customer signed *this* document" stops being
   provable. The resolution is that **the number was never what the customer
   signs.** They sign a statement of work performed; the number is bookkeeping
   the issuer assigns, and on paper it is pre-printed purely as an artefact of
   paper.

   So the device computes the same canonical hash the server would, at the
   moment the pad is signed, and sends it at sync. The server recomputes and
   compares. Match → the stored document is provably the one the customer saw.
   Mismatch → the sync is refused and the Rapport stays a draft.

   That is **stronger** than the online path, not weaker: it produces a
   device-side attestation of what was on screen, which the online flow never
   had.

   Design notes worth keeping:
   - An **outbox of intents**, not a local replica. Reads still want the
     network; writes never fail. The crew needs to record, not to browse.
   - Every operation carries a **device-generated id**, and the `sync_*` RPCs
     return the existing row rather than raising. A replay is a no-op — and
     deliberately not an update, so a retry cannot clobber a correction made in
     between.
   - The queue is **strictly FIFO and stops at the first failure**: a Rapport
     must not be signed before its lines arrive.
   - `created_at` is **not** a valid floor for clamping an offline signing
     time. For a draft built offline it records when the row reached the
     server, so clamping against it would drag every offline signature forward
     to its own sync time. A 30-day plausibility window is used instead, and
     the raw device claim is preserved verbatim in `signed_at_device`.
   - A Rapport must be opened once **with a connection** before it can be
     signed, because the attestation needs the canonical text. Stated in the UI
     rather than failing at the pad.
5. **Night / Sunday / Pikett work.** Common in HLKS service. If yes, a whole
   surcharge subsystem becomes mandatory rather than optional.
6. **Unregistered and Saldosteuersatz tenants.** Both are modelled
   (`mwst_status`), because getting the unregistered case wrong is an Art. 27
   liability trap — a business that shows MWST it is not entitled to charge
   owes it anyway.
7. **Retention — DECIDED: 5 years.** Implemented in `20260730090000`.

   The conflict was real, so the decision is applied to the thing it actually
   governs. ArGV 1 Art. 73 Abs. 2's five years is a rule about the *working-time
   record*, and that is what the purge deletes. A time entry frozen onto a
   signed Rapport has also become part of an *accounting* record, which carries
   its own floors (OR 958f: ten years; MWSTG Art. 70 Abs. 3: twenty where
   immovable property is involved — routine for HLKS). Those attach to two
   different things, so they are satisfied separately: the labour record goes
   at five years, the signed Rapport does not.

   Nothing a Rapport states is lost. What is lost is the separate live
   per-employee record behind it, which is exactly what ArGV 1 Art. 73 is about.

   Making that work needed one narrow exemption to the freeze: the purge clears
   a signed line's pointer to the record it deletes. That is safe because
   `report_canonical_text` covers the date, name, description, minutes and rate
   and never the provenance columns — so clearing them cannot change the hash.
   The regression test asserts the Rapport **still verifies** afterwards, which
   makes the claim checkable rather than merely argued.

   Still worth a Treuhänder's eye: whether deleting signed Rapporte at any
   horizon is ever wanted. This job does not, and that stays a separate
   deliberate decision.
8. **Qualified timestamp / company seal certificate.** Not legally required for
   a Rapport. Cost and per-tenant provisioning versus credibility.
9. **Location at signature.** Default off, and **no coordinate column exists** —
   its absence is the enforcement. Enabling it needs an ArGV 3 Art. 5/6
   employee consultation first.

## For a Treuhänder or Swiss counsel

- The 5/10/20-year retention rule, per table.
- Whether stroke dynamics are besonders schützenswerte biometrische Daten under
  revDSG Art. 5 lit. c Ziff. 4. This dictates the storage architecture and is
  genuinely unresolved.
- Whether a Rapport number series with no matching invoice series raises more
  questions than it answers.

## Still to verify before the QR renderer is trusted

- The **SIX Style Guide** x/y coordinates. The research produced every
  dimension, font size and heading string but **not one coordinate**. Without
  the style guide the layout is guesswork, and a bank's acceptance test is
  exactly what rejects guesswork.
- Whether the 46×46 mm QR area is inside or outside the 5 mm quiet zone. A
  10 mm error waiting to happen.
- The official SIX Swiss cross artwork file (it is a file, not a question).
- **SIX's public QR-bill validator belongs in CI** — the cheapest correctness
  win available.

---

## QR-bill geometry — resolved 2026-07-26

The SIX **Style Guide QR-bill v1.1** (effective 01.01.2026) turned out to be
fetchable and machine-readable, so the layout is no longer guesswork. Every
constant in `supabase/functions/render-document/qrbill.ts` comes from it.

The two things most often got wrong, now settled:

- **The 46 × 46 mm QR size EXCLUDES the quiet zone.** The zone is an additional
  5 mm on every side, so **56 × 56 mm** must be kept clear. This was the "10 mm
  error waiting to happen" flagged earlier.
- **There are no fixed y positions for text blocks.** The Style Guide is
  explicit: "if any are omitted the rest all move up." The information block is
  a top-anchored flow, not a coordinate table. Only the section rectangles are
  fixed. A renderer built from a coordinate table would misplace every bill
  that omits a reference or a message.

Other findings worth keeping:

- The payment part's information block starts at the **top margin (y = 5)**,
  level with the title — the receipt's starts **below** its title (y = 12).
  Easy to get wrong, and the two differ.
- The official Swiss cross artwork is 878 bytes of SVG containing four shapes
  and no `<path>`, so it is reproduced directly with no SVG parser. It is very
  slightly off-centre (~0.13 mm); that is reproduced faithfully, because it is
  the mark banks are calibrated against.
- **Standard-14 Helvetica cannot be used.** pdf-lib encodes it as WinAnsi and
  throws on Latin Extended A, which SIX explicitly permits in names. Verified:
  `WinAnsi cannot encode "ś"`. So Liberation Sans (SIL OFL 1.1) is embedded and
  subsetted — 30 KB in the PDF versus 443 KB unsubsetted.

### Correction to an earlier claim

I previously said SIX's QR-bill validator "belongs in CI". **It cannot be put in
CI.** It is a browser form requiring manual account activation, with no public
API, and it validates only the payload or a QR image — never the layout. Plan
for a "no" if you ask them for machine access.

What replaces it, and is arguably better for the encoder:

- **SIX's 18 official sample payloads** are now permanent assertions in
  `scripts/rls-tests.sql`. If our check-digit or IBAN-pairing rules reject one
  of SIX's own samples, the rules are wrong. All 18 pass.
  **Caveat recorded in the test:** those samples date from 2021 and **nine of
  them still use address type `K`**, the combined form v2.3 removed. Anyone
  treating all eighteen as current would "fix" their encoder to emit an invalid
  address type.
- **A decode round trip** in `qrbill_test.ts`: the rendered bill is decoded back
  and compared byte-for-byte. This is the assertion that matters, because the
  Swiss cross physically covers modules in the centre of the code — if error
  correction cannot recover them the bill is unscannable, and that failure is
  completely invisible in a visual review.

### Still unverified

- No pixel-exact golden image exists. SIX's only rendered samples are JPEGs
  from 2021 that predate Style Guide v1.1, so layout regression has no ground
  truth beyond our own baseline.
- The separation line's weight, dash pattern and scissors placement are **not
  specified anywhere**. Current choice (0.5 pt, 2 mm dashes, text instruction
  instead of a glyph) is convention, not spec.
- IG **3.6 says the acceptance point section should be ≥ 20 mm; the Style Guide
  drawing shows 18 mm.** We use 18. If a bank validator checks for 20, this is
  the first place to look.
- The Swiss cross artwork is licensed by conformance, not by a grant — using it
  is permitted only while output conforms to the IG. Worth a short counsel
  review before commercial launch.

---

## Closing the loop (2026-07-26)

Three things that were built but never connected, and what connecting them
turned up.

### The renderer had never once been called

The PDF function shipped, worked, and was invoked only by hand. Nothing in
`web/`, `ios/` or the database ever called it, so `pdf_path` stayed null and
every customer magic link resolved to a page with no document behind it. Both
sides failed silently: the customer saw a page without a PDF, and nothing
recorded that one had been expected.

A row leaving `draft` now nudges the renderer over pg_net, and a five-minute
sweeper picks up anything still missing a PDF. **The nudge is the latency
optimisation; the sweeper is the guarantee** — pg_net is fire-and-forget by
design, so a dropped request must cost a few minutes, never a document. Bounded
by `p_limit` and a 7-day horizon, with `render_runs.stuck` counting whatever
falls past it so "nothing has rendered all week" is visible rather than silent.

**Why the secret lives only in the vault.** The obvious design keeps the shared
secret in two places — the vault so Postgres can send it, an env var so the
function can check it. Two copies means carrying the value between them, and
every carrier (shell history, CI log, chat transcript) is somewhere it can be
left behind. Instead it is generated inside Postgres by `gen_random_bytes`,
stored once, and never returned; the function presents the header it received
and asks `verify_render_secret` whether it is right. Costs one round trip
against a render measured in seconds. `verify_jwt` is off because the caller is
a trigger, not a client, so that check is the entire boundary — which is also
why it now fails closed.

`render_document_url` is deliberately *not* created by the migration: it is
per-deployment and a migration must not hardcode one project's ref. Absent, the
nudge returns silently, so a fresh environment degrades to "no PDFs yet" rather
than to errors on signing.

### `qr_payload` was never written

The column and its two CHECK constraints had existed since the first invoice
migration with nothing ever writing to them — so neither constraint had been
evaluated on a single row, including the 997-byte capacity guard. `issue_invoice`
now persists it in a second UPDATE (it must run after the number, reference and
totals land, since `app.qr_bill_payload` reads the row). The immutability guard
permits this: it seals number, reference, totals and IBAN, and `qr_payload` is
none of those.

**Verified end to end against the deployed function, not a fixture.** Invoice
2026-0001 renders from real billing data, and the QR decodes *out of the
rasterised PDF* to 31 CRLF-separated lines with no trailing newline and a valid
QRR reference. Measured off the same raster, the Swiss cross is a 6.5 mm black
square inside a 0.25 mm white border with 3.9 mm arms — 7 mm overall, as SIX
specifies.

### The Treuhänder export

**One row per invoice per rate group**, not one per invoice. Art. 26 requires
tax stated per rate, an invoice can carry more than one, and totalling each rate
separately is the accountant's actual job.

The rule the column set is built around: **every numeric column is summable**.
`netto`/`mwst`/`brutto` describe that rate group alone, never the invoice they
belong to. Repeating an invoice total on each of its rows would read better and
would silently double-count.

Cancelled invoices are included on purpose — the numbering is gapless, so an
accountant who sees 2026-0003 missing will ask why.

CSV conventions, each a failure someone has already had: **semicolon** because
de-CH Excel splits on the locale list separator; a **UTF-8 BOM** because without
it Windows Excel renders Zürich as ZÃ¼rich; **CRLF** per RFC 4180; and a **dot**
for decimals, because Switzerland writes 1'234.50 and not 1.234,50.

### Photos on a Rapport, and two bugs only a UI could surface

`report_photos` existed, `app.report_canonical_text` already hashed the photo
paths, and the renderer already printed them. Nothing wrote a row.

Because the paths are in the canonical text, **the signature already covers the
photos** — no hash versioning was needed. It also settles the offline question:
photos are the one thing on a Rapport that require a connection, since a photo
waiting in the outbox would change the canonical text after the customer had
signed the version without it, and the sync would then reject the signature.
Failing at that moment, for that reason, is worse than saying so up front.

Two defects found by writing the tests:

- **`attachments_delete` never covered report attachments.** It still read
  `task_id is not null and ...` from before attachments could belong to a
  report. RLS refuses by deleting nothing rather than by raising, so the call
  succeeded, returned no error, and left the row in place. Nobody noticed
  because nothing had ever attached a report photo. The policy now covers them,
  with `not app.report_is_frozen(report_id)` folded in — otherwise the freeze
  would hold on the link row and not on the file beneath it.
- **Delete order.** `report_photos.attachment_id` is ON DELETE RESTRICT — on
  purpose, so a photo cannot vanish from under a Rapport that cites it — so
  deleting the attachment first fails on the foreign key even on a draft. Both
  clients unlink, then delete, then drop the storage object.

### Still open

- **Storage objects orphaned by an interrupted upload.** The clients delete the
  object on an explicit removal, but an upload that fails after the object lands
  and before the attachment row is inserted leaves a file nothing references.
  There is no GC sweep for storage.
- **bexio's own API** remains unbuilt; `bexio_invoice_id` / `bexio_synced_at` /
  `customers.bexio_contact_id` are the seam, and the CSV carries the contact id
  so a later push can match without re-deriving it from a name.
