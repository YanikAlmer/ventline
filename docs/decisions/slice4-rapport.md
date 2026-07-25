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
4. **Offline capture in a Heizungskeller.** v1 is online-only, and the
   consequence is owned out loud: a Rapport cannot be completed where there is
   no signal, because the number, the render and the hash are all server-side.
   The alternative — a client-side provisional identity numbered at sync —
   breaks "the customer signed *this* document". Needs a product decision
   before it is engineered.
5. **Night / Sunday / Pikett work.** Common in HLKS service. If yes, a whole
   surcharge subsystem becomes mandatory rather than optional.
6. **Unregistered and Saldosteuersatz tenants.** Both are modelled
   (`mwst_status`), because getting the unregistered case wrong is an Art. 27
   liability trap — a business that shows MWST it is not entitled to charge
   owes it anyway.
7. **Retention.** Genuinely conflicting: ArGV 1 Art. 73 says 5 years for the
   labour record; OR 958f says 10 for a Buchungsbeleg; MWSTG Art. 70 Abs. 3
   says 20 where immovable property is involved, which for HLKS is routine.
   Running a 5-year purge over data that is also an accounting record destroys
   books. → two separate clocks, `retain_until` on each table, and **no purge
   job ships** until a Treuhänder confirms the rule.
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
