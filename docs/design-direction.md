# Design direction — FELDAKTE

> Ventline looks like the paperwork it replaces — ruled rows, numbered exhibits, stamped documents — and every mark on it is drawn so it still reads with the colour taken away, on a roof, in July.

Selected by a five-direction judge panel (field-reality / market-differentiation / build-reality lenses).
Runner-up and the condition under which it wins are recorded at the bottom.

---

## Why this direction

The weighting decides this almost mechanically. Field reality is disqualifying, build reality caps scope, market breaks ties. SIGNALFELD won the field lens outright and is genuinely the most rigorous status engineering in the set — but it came LAST on build with an architectural contradiction that is not a detail: it specifies `enum VColor { static let … }` and simultaneously says every token "resolves through a Theme value published by an @Observable ThemeStore in the environment." Those cannot both be true. A theme threaded through the environment cannot be a static Color, which breaks `.listRowBackground`, breaks fills inside the PencilKit `UIViewRepresentable` bridges in PhotoMarkupView and SignaturePadView (which have no SwiftUI environment at all), and breaks previews; a static reading a global singleton breaks SwiftUI invalidation. It also throws away 21 UIKit dynamic-colour sites — i.e. it deletes the free dark mode this codebase has today — and its real QA matrix is 3 themes × 3 densities. For one person with no CI, that is a rewrite wearing a redesign's clothes. Disqualified on scope, not on merit.

RASTER placed 2nd on build and 2nd on market, and its migration tactics are the best anyone proposed. But two things sink it. Radius 0 is exactly what SwiftUI `Form` cannot express, so all 9 creation sheets must be hand-rolled — and "twenty minutes each" is wrong, because `Form` supplies keyboard avoidance, focus traversal and scroll-to-focused-field for free and a ScrollView+VStack supplies none of them. And its differentiation is explicitly typographic against a typeface whose app-embedding tier it admits is unquoted; on the Inter fallback it becomes a Swiss grid set in the most-used face in B2B SaaS, with iOS silently falling to SF Pro. Its field failures are premise-level too: `done` vs `approved` distinguished by whether 2pt gaps are present is an acuity task at the resolution limit of a wet screen.

Aktenlage won two of three lenses and placed 4th on field — but crucially, its field failures are all *local choices*, not consequences of its premise. The premise is "state is notation." Nothing in that premise requires `done` and `approved` to be pixel-identical marks (that was one specific call: "approval is a countersignature"), requires `todo` to be outlined at 3.01:1, or forbids a high-visibility theme. All three are replaceable without touching the thesis, and replacing them is exactly what the other four directions supply. Meanwhile the things Aktenlage has that cannot be grafted are the expensive ones: ruled rows on a flat ground is literally what `List(.plain)` already renders, so 14 of 14 List instances get reskinned in five modifiers each; 2px radius keeps all 9 `Form` sheets free; zero shadows and radius ≤2px delete the two worst cross-platform reconciliation problems (shadow spread/blur/offset, and `.continuous` vs `.circular` corner curvature) by construction rather than by discipline. And it is the only direction whose token layer reaches the artifact the customer keeps for eight years — the repo already proves that pipeline works via `scripts/build-fonts.py` → `render-document/fonts.ts`.

Where it honestly loses: it is the coldest first thirty seconds of the five. A Sanitär-Meister told he was getting "a modern app" may open flat white sheets with hairlines and think the CSS failed to load, and there is no half-measure that fixes that without abandoning the premise. Its own risk section names this and it is right to. It is also the direction with the lowest tolerance for careless implementation — with shadows and radius gone, a missing hover state or an inconsistent rule weight reads as broken rather than as plain. I accept both. The mitigation is that the German copy is already warm, informal `du`, and trade-precise: the coldness lives in the layout and the warmth lives in the words. The market judge's sharpest hit — that `#FDFBF2` vs `#FFFFFF` is a 1.5% step that cannot carry the entire storefront differentiation — is a real defect and I have fixed it by moving the customer-copy tint to `#FBF4E0` (a 1.10 luminance ratio plus a 12% blue-channel drop, perceptible side by side) and pairing it with an explicit "Ihre Kopie" label.

### Grafts from the non-winning directions

- From SIGNALFELD — the monotonic ladder, re-expressed in ink instead of hue. The four forward task states are ordered by INK COVERAGE of the Statusmarke (0% → 50% → 100% square → 100% pointed tag), so a column of Arbeitsschritte reads as a filling gauge in greyscale, on a photocopy, and under every CVD type. This is Signalfeld's central insight ported into Aktenlage's native material: Aktenlage already refuses hue, so a coverage ladder costs nothing and buys the whole thing.
- From SIGNALFELD — SONNE as a first-class LIGHT high-visibility theme, not a dark one. #FFFFFF/#000000, all rules promoted to 2px black, every tint under 3:1 and every opacity<1 stripped, type +1 rung, targets 56/64pt, motion zeroed. The physics is correct and contrarian: veiling glare is additive, so effective contrast is (Lfg+Lveil)/(Lbg+Lveil) and a bright ground degrades far less than an emissive black one. Scoped hard to field density only (never portal, never desktop) so it adds ONE QA cell, not four.
- From SIGNALFELD — the thumb-zone law and the tap token set (44/48/56/64pt), enforced inside a shared VLIconButton with .frame(minWidth:minHeight:).contentShape(Rectangle()) so no call site can reintroduce the bug. Fixes the verified defect: ComposerBar.swift's PhotosPicker and mic are literally .frame(width: 40, height: 40) and the send button is a bare .font(.system(size: 32)) with no frame at all.
- From SIGNALFELD — the portal collapses the five task statuses to exactly two (offen / fertig) using the `done || approved` predicate the code already computes. The internal pipeline is not the homeowner's business, and a portal exposing five states reads as a leaked admin tool.
- From SIGNALFELD — theme-invariance as a stated rule: --vl-alert is byte-identical in light, dark and Sonne, because a warning that changes appearance with the theme is not a warning.
- From Werkschild — the PLAKETTE silhouette (a pointed right edge, the hang-tag an inspector signs and leaves) for the terminal released state, reused identically for `approved` tasks and for signed/sent Rapporte. This is the single most important graft: it fixes Aktenlage's one disqualifying field failure, where `done` and `approved` rendered as pixel-identical marks in the very column designed to be scanned. Square vs pointed tag is a silhouette difference readable at 3m and in greyscale, and it is ledger-native rather than borrowed — a Visum on a hang-tag is what Swiss practice actually looks like.
- From Werkschild — Werkplakette numbering: every Arbeitspaket carries AP-03, every Arbeitsschritt 03.2, in Plex Mono on a sunk field. It carries the never-flatten hierarchy invariant into every context where layout physically cannot: search results, inbox hits, a screen reader, and a phone call from a plant room.
- From Werkschild — generate BOTH web/src/lib/status.ts's maps AND ios/.../StatusTokens.swift from the same four status maps in tokens.json, so ProjectStatus / TaskStatus / ReportStatus / AppRole cannot drift between platforms. This is the only structural answer to the mess that exists today (20 class bundles + Domain.swift's inline enum colours + RapportView's separate ReportStatus map + two escaped web re-implementations).
- From Werkschild — cut iOS static font instances from the source TTFs with fonttools rather than fighting variable axes from SwiftUI, reusing the toolchain scripts/build-fonts.py already establishes.
- From RASTER — blocked gets a HEIGHT channel: the blocked Statusmarke is 30×24px where every other mark is 20×20 (office) / 24×24 (field). Height is a channel nobody else used and it survives greyscale, peripheral vision, glare and colour-blindness simultaneously. Combined with Aktenlage's full-row alert edge and wash, blocked is over-determined across five channels.
- From RASTER — ban the weakest ink token by ROUTE rather than deleting it: --vl-ink-400 (4.75:1) is forbidden on every iOS surface and on the web /projects/*/tasks/* and /chat routes, permitted at desk density only. Enforcement by route is the correct engineering response to a token that is legitimate at a desk and illegitimate on a roof.
- From RASTER — the day-one `@layer utilities` radius hard-override, so the sweep across 138 rounded-* sites is incremental and safe rather than one 38-file atomic commit. Plus: raise the PencilKit widths (signature pen 3pt → 4.5pt, markup pen 6pt → 8pt, markup ink retokenised from .systemRed to --vl-alert), because both canvases already declare .anyInput with an explicit comment committing to bare-finger input and only the widths were left at defaults.
- From RASTER — extract the 56px mobile-header magic number to --vl-topbar consumed by the two page files that hardcode it (chat/page.tsx line 35, tasks/[taskId]/page.tsx line 81), and DO NOT change the value in the same commit. Tokenise and change separately so any layout regression in the chat/task shells is attributable.
- From Abwärts — put the chevron geometry constants (run 232, drop 182, stroke 88, pitch 136) into design/tokens.json and have brand-mark.tsx, a new SwiftUI BrandMark Shape, and scripts/build-app-icon.py all read from it. This closes a drift hole brand-mark.tsx's own docstring frets about in prose — a comment currently doing a generator's job.
- From Abwärts — export the icon set as SF Symbols CUSTOM SYMBOLS rather than template images, so glyphs get Dynamic Type scaling and weight matching for free. Same drawing work, different export target.
- From Abwärts — add .dynamicTypeSize(...DynamicTypeSize.accessibility2) and .minimumScaleFactor(0.85) across iOS field screens. Zero files in ios/ use any of dynamicTypeSize, minimumScaleFactor or accessibilityElement today; many of these users wear readers on a roof with system text size cranked up, and that path is currently untested and unbounded.

### Runner-up

RASTER. It would be the better call in exactly one circumstance: if the owner secures a written Grilli Type quote covering desktop + web + iOS app embedding at a price he is happy to pay, AND accepts that the 9 iOS creation sheets get hand-rolled (budget 4 extra days, not 3 hours). RASTER's Siegelrahmen and its two-letter role codes are stronger identity assets than anything Aktenlage generates natively, and its day-one `@layer utilities` radius override is the single best migration tactic proposed by anyone. But GT America's app tier is unquoted, and on the free fallback RASTER spends its differentiation budget on Inter — which is the house face of every B2B SaaS product since 2018 — while still paying the Form rewrite cost. If the font money is not real and permanent, RASTER is strictly worse than FELDAKTE at higher cost.

---

## Typeface

SETTLED: **IBM Plex Sans (400 / 500 / 600) + IBM Plex Mono (400 / 500)**. Two families, not three — I am dropping Aktenlage's proposed IBM Plex Sans Condensed.

Licence: SIL Open Font License 1.1. Cost: CHF 0, permanently. Source: github.com/IBM/plex (static or variable builds; cut static instances with `fonttools varLib.instancer` if using the variable source).

WHY OFL IS A HARD CONSTRAINT, NOT A BUDGET PREFERENCE. This is the one place where the technical facts in this repo settle a design argument outright. `supabase/functions/render-document/` embeds font BYTES into every generated PDF — `scripts/build-fonts.py` says so in its own docstring, and the reason it exists is that pdf-lib's Standard-14 Helvetica is WinAnsi-encoded and throws on the Latin Extended-A characters SIX permits in names ("the render would work until a customer was called Wiśniewski"). Those PDFs are distributed to third parties (homeowners, Treuhänder) and retained for years. Every commercial licence — GT America, Suisse Int'l, ABC Diatype, Söhne, FF DIN — prices or forbids document embedding separately from web serving, and separately again from app embedding into the iOS binary. OFL permits all three without limit. Choosing a licensed face would mean the design system's central claim (screen and PDF are one artefact, one token file) is a procurement problem rather than a technical one.

WHY PLEX SPECIFICALLY. It was drawn for technical and corporate documentation. It has genuine tabular lining figures (the Rappen columns require them and most grotesques fake them). Its Sans and Mono siblings are metrically related, so a table header, a body cell and a money column look drawn by one hand. Its slightly flattened bowls keep it off the Inter/Geist default axis — Inter is technically excellent and free, but it is the default face of every SaaS product built since 2018, and shipping on it would forfeit most of the typographic differentiation.

WHY NO CONDENSED. The build lens correctly flagged three families at ~180KB as the heaviest LTE payload of the five candidates, and rural LTE is a real constraint here. The German-compound problem is solved more cheaply by hyphenation than by a third font file: `lang="de-CH"` + `hyphens: auto` + `hyphenate-limit-chars: 8 4 4` + `overflow-wrap: anywhere`, plus ~20 authored soft hyphens in `web/src/i18n/dictionaries/de.ts` for the known offenders. Two families subset to latin + latin-ext land at roughly **115 KB woff2 total**. If the Treuhänder export table proves genuinely too wide in production, adding Plex Sans Condensed for column headers ONLY is a Phase-8 addition and a one-line token change — it is deliberately not in the shipping budget.

SELF-HOSTING PLAN.
- Web: `next/font/local` from woff2 in `web/src/app/fonts/`, subset latin + latin-ext (must include U+2019, the Swiss thousands apostrophe). No Google CDN request — that removes a third-party call and a DSG question for a Swiss customer base. `font-display: swap`, `font-feature-settings: "tnum" 1, "zero" 1`.
- iOS: the same TTFs in `ios/Ventline/Resources/`, registered via `UIAppFonts` in `ios/project.yml`'s info block. XcodeGen's `sources: - path: Ventline` glob picks them up with zero .pbxproj work. Every token routes through `Font.custom(_:size:relativeTo:)` wrapped in `UIFontMetrics(forTextStyle:).scaledFont(for:)`, so Dynamic Type keeps working — and because all 140 `.font(...)` call sites already use semantic styles rather than fixed sizes, the typeface lands across the whole app by extension, touching zero call sites. That seam is the reason this is a token project and not a rewrite.
- PDF: extend `scripts/build-fonts.py` to subset and base64-embed Plex Sans + Plex Mono alongside the existing Liberation Sans, into `supabase/functions/render-document/fonts.ts`. Budget ~250 KB per generated document unless per-document subsetting is added; per-document subsetting is explicitly deferred and flagged as unbudgeted pipeline work.

THE ONE PLACE PLEX DOES NOT GO: the QR payment part below the perforation line keeps **Liberation Sans**. SIX Style Guide v1.1 permits only Arial, Frutiger, Helvetica or Liberation Sans in the Zahlteil. Yes, the invoice page will show two typefaces. It is legally correct, it is conceptually defensible as a form-within-a-form, and the visible face change declares "below this line is federal geometry." A picky art director will read it as a mistake; it cannot be fixed without breaking SIX compliance, and compliance wins.

FALLBACK STACKS.
Sans: `"IBM Plex Sans", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`
Mono: `"IBM Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace`
iOS terminal fallback: SF Pro / SF Mono.

REJECTED, WITH REASONS. Atkinson Hyperlegible (the field lens's pick — genuinely the best letterform set for degraded viewing, and OFL, but its humanist soft bowls at weight 800 read warm and slightly juvenile, which contradicts a records system; its disambiguation benefits are largely recovered here by Plex Mono's slashed zero on every machine-generated string). GT America (Swiss foundry, superb, but CHF 1,200–2,400 against an unquoted app-embedding tier, and PDF embedding is a separate negotiation). Suisse Int'l and Söhne (same embedding problem, worse). Inter (free and excellent, but it is the house face of modern SaaS and defeats the differentiation premise).

---

## Tokens

Single source of truth is `design/tokens.json`; `web/src/app/tokens.css` and
`ios/Ventline/Core/Design/Tokens.generated.swift` are both generated and committed.

### Colour

| Token | Light | Dark | Use |
|---|---|---|---|
| `--vl-paper-desk` | `#F2F0EA` | `#101316` | App background — the desk. Nothing content-bearing sits directly on it. Sonne overrides to #FFFFFF. |
| `--vl-paper-sheet` | `#FFFFFF` | `#191D21` | The record surface. Every table, log, form and document sits on a sheet. Depth is value contrast against the desk, never a shadow. Ink on it = 18.2:1 light / 14.6:1 dark. |
| `--vl-paper-copy` | `#FBF4E0` | `#1D1B15` | The yellow Durchschrift. ONLY the customer portal sheet and the r/[token] viewer. Raised from Aktenlage's #FDFBF2 to a genuinely perceptible carbon tint (1.10 luminance ratio vs sheet, 12% blue-channel drop). Ink on it = 16.5:1. |
| `--vl-paper-sunk` | `#EDEBE4` | `#22272C` | Composer well, code/reference blocks, Werkplakette number fields, table zebra, the interior of a frozen document. |
| `--vl-paper-hover` | `#E7E4DC` | `#262C31` | Row hover / pressed fill. With shadows gone this is the only affordance cue left, so it is a deliberate ~4% value step, not a whisper. |
| `--vl-ink-900` | `#14171A` | `#ECEFF2` | Printed text, filled status marks, primary button fill, structural rules that carry finality. 18.2:1 on sheet light / 14.6:1 dark. Never pure black — pure black halates on OLED at full brightness. Sonne overrides to #000000. |
| `--vl-ink-700` | `#3D454C` | `#BCC3CA` | Labels, column headers, author names, Kürzel glyphs, secondary body. 9.6:1 light. AAA. |
| `--vl-ink-500` | `#4E575F` | `#9BA4AC` | Metadata that matters: timestamps, document numbers, unit labels, system-message text — AND the todo mark's 2px outline. 7.25:1 light. AAA by policy: in a records system nothing a court would read is allowed to be low-contrast. |
| `--vl-ink-400` | `#6B747C` | `#868F97` | Placeholders and archived-row text ONLY. 4.75:1 — AA. BANNED BY LINT on every iOS surface and on web routes /projects/*/tasks/* and /chat. This is the enforcement mechanism for 'AAA for anything a worker reads outdoors'. |
| `--vl-rule` | `#8C8578` | `#5F6870` | Structural 1px rule: sheet edge, table-head underline, section boundary, input border, Kürzel box outline, the Randstrich gutter line. 3.66:1 — clears the WCAG 1.4.11 non-text floor with margin (Aktenlage's original #9A9488 sat at 3.01:1 and vanished in sun). Promotes to 1.5px in field density, 2px #000000 in Sonne. |
| `--vl-rule-hair` | `#DCD8D0` | `#272C31` | Decorative sub-division only: row separators inside a table body, day-group boundaries in a photo grid. Never load-bearing, because rows are also separated by whitespace. |
| `--vl-rule-ink` | `#14171A` | `#ECEFF2` | 1.5px finality rule: above a total, the double rule below it, the signature line, the 3px top band on a frozen document. Identical to --vl-ink-900 by definition — in this system a rule is drawn text. |
| `--vl-alert` | `#A31F0F` | `#FF6F52` | Oxide stamp red. THE only hue in the status system. Blocked mark fill + 3px row edge, the Storniert stamp, the strike rule across a cancelled total, destructive confirmations, PencilKit markup ink. 7.5:1 light / 6.1:1 dark. Theme-invariant in Sonne (stays #A31F0F) because a warning that changes with the theme is not a warning. |
| `--vl-alert-tint` | `#F9E7E3` | `#2E1A16` | The blocked-row wash and ErrorNote background. Never used for anything non-blocking. --vl-alert on it = 7.0:1. |
| `--vl-link` | `#075985` | `#5CC6F6` | Interactive text: links, task references, @mentions, the active project's Registerreiter rule. 7.5:1 light / 8.5:1 dark — AAA, because mentions and task refs are how the log cross-references itself. Always carries a 1px underline at 2px offset so it survives greyscale. |
| `--vl-mark-mid` | `#38BDF8` | `#7DD3FC` | Brand mark, middle chevron. Light value is VERBATIM from brand-mark.tsx and scripts/build-app-icon.py — nothing about the mark changes visually, it just stops being a literal. Lifts one stop in dark so the three-chevron ramp survives on near-black. Non-text use only. |
| `--vl-mark-low` | `#0284C7` | `#38BDF8` | Brand mark, bottom chevron. Light value VERBATIM. Also the 2px Registerreiter rule above an `active` project — the only place brand blue signifies anything. Also the new iOS AccentColor, replacing #E87A2E. |
| `--vl-focus` | `#075985` | `#5CC6F6` | 2px focus ring at 2px offset PLUS a 1px --vl-paper-sheet inner ring, so focus stays visible on both the white sheet and the ink-filled primary button. Radius 2px like everything. Replaces today's ring-slate-400/30, which fails 3:1. |
| `--vl-visum-tint` | `#E6F0F6` | `#0E2833` | Background of the Visum chip on an approved task — the only tinted chip in the entire product. |
| `--vl-visum-ink` | `#075985` | `#7FD3F7` | Visum chip text: Kürzel + date, Plex Mono 11px office / 13pt field. 6.7:1 on its tint. |
| `--vl-copy-1` | `#F4EFE2` | `#23211A` | Decorative avatar backfill #1 (carbon yellow). RULE, documented in the token file: --vl-copy-* are background-only and carry NO meaning. This is what stops avatars colliding with status semantics, which today's 8-colour hash palette makes possible (emerald = approved AND a person on the same row). |
| `--vl-copy-2` | `#F6EDEF` | `#241D1F` | Decorative avatar backfill #2 (carbon pink). |
| `--vl-copy-3` | `#EAF0F5` | `#181F25` | Decorative avatar backfill #3 (carbon blue). |
| `--vl-copy-4` | `#EDF2EC` | `#1A211A` | Decorative avatar backfill #4 (carbon green). Four ~6%-chroma tints replace the current 8-colour hash palette; initials in --vl-ink-700 do the identifying. |
| `--vl-scrim` | `rgba(20,23,26,0.82)` | `rgba(0,0,0,0.86)` | Modal scrim. Single value shared by modal.tsx and chat/lightbox.tsx, replacing today's mismatched slate-900/50 and slate-950/90. No backdrop-blur — blur is consumer softness; a slip of paper is either on the desk or it is not. |
| `--vl-scrim-media` | `rgba(20,23,26,0.94)` | `rgba(0,0,0,0.96)` | Lightbox scrim only, so a markup photo is judged on its own ground. |
| `--vl-sonne-ink` | `#000000` | `#000000` | Sonne override for --vl-ink-900. 21:1. Only reachable inside [data-theme="sonne"], which is field-density only and never applies to the portal. |
| `--vl-sonne-rule` | `#000000` | `#000000` | Sonne override for --vl-rule and --vl-rule-hair, drawn at 2px. In Sonne there are no hairlines: every boundary is a black 2px rule, and every tint under 3:1 resolves to transparent. |

### Type

| Token | Value | Use |
|---|---|---|
| `--vl-font-sans` | "IBM Plex Sans", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif | Everything human-authored. Self-hosted woff2 via next/font/local, weights 400/500/600, subset latin + latin-ext (ä ö ü à é and U+2019). |
| `--vl-font-mono` | "IBM Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace | Everything machine-generated: money, durations, Rapport-Nr., Einladungscode, IBAN, QR reference, Werkplakette numbers, CSV column values. Weights 400/500. |
| `--vl-text-micro` | 11px / 14px / 600 / +0.08em / uppercase — FIELD: 13px / 16px | The stencil register: column headers, BELEG labels, Kürzel, datelines, stamp text, Werkplakette numbers. Minimum colour --vl-ink-700. HARD RULE: micro is never the sole carrier of a status — it always accompanies a mark. |
| `--vl-text-meta` | 12px / 16px / 400 — FIELD: 15px / 20px | Timestamps, counts, document numbers, unit labels. Mono for anything numeric, Sans otherwise. The field step is the floor set by the field lens: nothing load-bearing below 15pt on a phone. |
| `--vl-text-body` | 14px / 20px / 400 — FIELD: 17px / 25px — PORTAL: 18px / 28px | Default. Table cells, office rows, form fields. 17px on mobile is deliberate: iOS Safari zooms any input under 16px. |
| `--vl-text-body-strong` | same metrics / 500 | Task titles, person names, money totals in prose. |
| `--vl-text-read` | 16px / 24px / 400 — FIELD: 17px / 26px | Chat entry bodies, prose, portal body — anything read continuously rather than scanned. |
| `--vl-text-lead` | 18px / 24px / 500 — FIELD: 20px / 28px | Row titles, Arbeitsschritt names, list row labels. |
| `--vl-text-head` | 22px / 28px / 600 / -0.01em — FIELD: 24px / 30px | Section heads, Arbeitspaket names. |
| `--vl-text-doc` | 28px / 32px / 600 / -0.015em — FIELD: 30px / 36px | Document and page titles. font-black is DELETED from the product — a black weight is a marketing weight and a ledger does not shout, and 900 plus a 24-character German compound is a wall. |
| `--vl-text-figure` | 32px / 32px / Mono 500 / tabular-nums | Rapport totals, invoice totals, invite code display. |
| `--vl-text-timer` | 40px / 40px / Mono 600 / tabular-nums | The running timer. Replaces the existing .system(size: 40, weight: .bold, design: .rounded). |
| `--vl-numeric` | font-variant-numeric: tabular-nums slashed-zero; font-family: var(--vl-font-mono); text-align: right | MANDATORY on every cell holding Rappen or minutes. Because Plex Mono is fixed-pitch and money always carries two decimals, 1’234.55 and 98.00 align on the decimal from right-alignment alone — no decimal-align hack. The slashed zero is what makes an IBAN and an invite code readable at 15pt in a basement. |
| `--vl-hyphenation` | lang="de-CH"; hyphens: auto; hyphenate-limit-chars: 8 4 4; overflow-wrap: anywhere; text-wrap: pretty | Set on <html> and on all heading/label classes. Plus soft hyphens authored directly into de.ts for the ~20 known offenders (Arbeitspaket­übersicht, Rapport­unterschrift, Kunden­sichtbarkeit, Saldo­steuersatz, Treuhand­export). Truncation with an ellipsis is BANNED on anything that names a work package — a half-named Arbeitspaket in a record is worse than a wrapped one. |

### Space

| Token | Value | Use |
|---|---|---|
| `--spacing` | 4px | Tailwind 4 derives the entire spacing scale from this single value, so p-4 = 16px and gap-6 = 24px with no tailwind.config file. There isn't one today and there still won't be. |
| `--vl-space-scale` | 2 / 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 56 / 64 | The permitted steps. Anything off-scale is a review comment. |
| `--vl-row (office)` | 36px | Desktop table and list rows: overview, export, customers, people, settings. |
| `--vl-row (field)` | 56px | All iOS, all web below 768px. |
| `--vl-row (portal)` | 64px | Customer surfaces only. |
| `--vl-gutter` | 52px office / 56px field | The Randstrich margin — the width of the left gutter carrying timestamps and marginal marks, with the 1px --vl-rule at its right edge. SCOPED TO THE LOG ONLY (chat threads, chronological lists), never to List-based screens. |
| `--vl-markspalte` | 20px office / 24px field, +8px trailing gap | The fixed leftmost column holding the Statusmarke in every task list, on both platforms. This — not the Randstrich — is the vertical-scan device on List-based screens, and it works per-row natively. |
| `--vl-indent-step` | 24px office / 20px field | Arbeitsschritt indent under its Arbeitspaket, behind a 2px --vl-rule vertical riser running the full height of the step group with a 12px horizontal tick into each row. Replaces today's `border-l border-slate-200 pl-4`. |
| `--vl-topbar` | 56px | Mobile header height. Extracted from the two hardcoded min-h-[calc(100dvh-56px)] strings and consumed as calc(100dvh - var(--vl-topbar)). The VALUE DOES NOT CHANGE in the tokenising commit. |
| `--vl-measure` | 1120px office sheet / 720px document sheet / 640px portal | 720px is an A4-ish reading measure with 75px side padding ≈ 20mm. German runs ~15% longer than English, so the English build sits shorter in the same column rather than the German build overflowing. |

### Form, motion, density

| Token | Value | Use |
|---|---|---|
| `--vl-radius-sheet` | 0px | Sheets, tables, rows, status marks, stamps, avatars, thumbnails, the Kürzel box, modal panels. Circles are social software; squares are records. |
| `--vl-radius-box` | 2px | Inputs, buttons, the composer field — a printed form's boxes carry a hair of press radius. CRITICALLY: 2px keeps SwiftUI `Form`'s grouped insets acceptable, so all 9 iOS creation sheets survive untouched. This single decision is worth ~4 days against a radius-0 direction. |
| `--vl-radius-full` | DELETED | 37 current uses. Every one becomes a square or a rule. Enforced by the day-one @layer utilities override, then by grep. |
| `--vl-shadow` | NONE, with exactly one exception | All 33 shadow-* uses are deleted; every shadow-sm becomes a 1px --vl-rule border and every hover:shadow-md becomes a border-colour change. The exception is the modal, a slip of paper laid on the desk: box-shadow: 2px 3px 0 rgba(20,23,26,0.18) — hard-edged, zero blur — plus a 1px --vl-rule-ink border. In Sonne it is deleted too. |
| `--vl-rule-weights` | 1px hair (--vl-rule-hair) / 1px structural (--vl-rule) / 1.5px finality (--vl-rule-ink) / double 1px+2px gap+1px (der Abschlussstrich) / 3px --vl-alert (blocked row edge) | The five weights are the product's whole visual language. In FIELD density every structural rule promotes 1px → 1.5px; in Sonne every rule is 2px #000000. On iOS structural rules are a literal Rectangle().frame(height:), never Divider(), so they do not thin to 0.33pt on 3× displays; only decorative hairlines use 1/displayScale. |
| `--vl-tap-min` | 44pt | Absolute floor on every interactive element, enforced INSIDE a shared VLIconButton / IconButton primitive rather than at call sites, so it cannot regress. |
| `--vl-tap-field` | 56pt | The four primary field actions: Kamera, Sprachnachricht, Senden, Status setzen. Fixes ComposerBar.swift's PhotosPicker and mic (currently .frame(width: 40, height: 40)) and the send button (currently a bare .font(.system(size: 32)) with no frame at all — its hit area is close to the 32pt glyph box). Send becomes a 56×56 solid --vl-ink-900 SQUARE with a white arrow: a stamp you press, not a floating circle. |
| `--vl-tap-sign` | 64pt | The one primary action per iOS screen, presented full-width via .safeAreaInset(edge: .bottom) and labelled with the NEXT status ('→ ERLEDIGT'). Includes the Rapport 'Unterschreiben' CTA. Sonne raises this to 76pt. |
| `--vl-motion-state` | 120ms cubic-bezier(0.2, 0, 0, 1) | Row hover fill, status mark fill, disclosure expand. iOS: .easeOut(duration: 0.12). |
| `--vl-motion-sheet` | 180ms cubic-bezier(0.2, 0, 0, 1) | The modal slip (translateY 8px + opacity), bottom sheets, the mobile nav. |
| `--vl-motion-position` | 0ms | HARD RULE: no layout animation in a log. Entries appear, they never slide — a record whose rows move while you read it is not a record. prefers-reduced-motion / .accessibilityReduceMotion and Sonne all zero every token above. |
| `--vl-icon` | 24×24 grid, 1.5px stroke, BUTT caps, MITER joins, angles 0°/45°/90° only | 18 glyphs drawn in-house, paths in design/icons.json, emitted as a React <Icon name> component AND as SF Symbols custom symbols (which get Dynamic Type scaling and weight matching for free — template images do not). The coherence argument is mechanical: the icons are drawn with the same pen as the rules. Nav mapping replacing ▦💬🏠👥⤓⚙ — Übersicht: three ruled lines of decreasing length in a frame. Kommunikation: two ruled lines with a tick in the margin (a log, not a speech bubble). Kunden: a sheet with a folded corner (a dossier). Personen: two abutted squares with a hairline gap. Treuhand-Export: a sheet with a down-arrow crossing its lower rule. Einstellungen: a rule with a square handle (a cog is machinery; this is an office). Fallback if drawing slips: Phosphor Icons at weight 'light' with a global stroke-linecap: butt override. |
| `--vl-density` | data-density="office" \| "field" \| "portal" on <html>, @Environment(\.vlDensity) on iOS | Three profiles overriding custom properties ONLY on web, so zero call sites change. On iOS the environment value is read by row builders to set .listRowInsets and minHeight — this IS per-call-site work across the 14 List instances and is budgeted as such in Phase 6, not hand-waved as free. |
| `--vl-theme` | data-theme="light" \| "dark" \| "sonne" | Sonne is field-density ONLY. Never applies to the portal (a homeowner opens a magic link in daylight), never to desktop. Real QA matrix: office×light, office×dark, field×light, field×dark, field×sonne, portal×light, portal×dark = 7 cells, of which dark is derived. On web the theme toggle stamps data-theme so it wins over prefers-color-scheme in both directions. |
| `--qr-protect` | SPERRZONE — no token crosses this line | supabase/functions/render-document/qrbill.ts is untouched: the 46mm QR symbol, the 5mm quiet zone (56×56mm total clearance), the exact 878-byte Swiss cross, embedded Liberation Sans, the top-anchored information flow, and 5-Rappen half-up rounding per rate group are all frozen by SIX Style Guide v1.1. The document page force-renders in LIGHT regardless of the viewer's theme. No signal colour within 12mm of the block. The redesign contributes only the chrome ABOVE the perforation line. |

---

## Status system

The 20 hardcoded class bundles in `web/src/lib/status.ts` plus the escaped map in `rapport-panel.tsx` collapse to FOUR NOTATIONS and ONE HUE. The governing rule: a different vocabulary gets a different KIND of mark, never a different palette, so two vocabularies on the same screen can never be confused. Total hues in the status system: one (--vl-alert). Total hues in the product: two (--vl-alert, and brand sky on the mark / active project / focus ring).

═══ A. TASK PIPELINE (5) → DIE STATUSMARKE ═══
A 20×20px (office) / 24×24pt (field) mark in the fixed leftmost --vl-markspalte column of every task row, so the marks stack into a vertical stripe you can read down without reading a word. Progress is encoded as INK COVERAGE — the monotonic ladder, expressed in ink instead of hue. Every mark ships with `role="img"` and an aria-label, and icon-only status rendering is banned system-wide: the mark always has its text label beside it.

1. **todo / "Offen"** — empty square, **2px --vl-ink-500 outline** (7.25:1), sheet fill, no glyph. An unticked box. Ink coverage 0%.
   · Deuteranopia: zero hue. Pure shape.
   · Sunlight: this is the fix for Aktenlage's worst field defect — the original drew this outline in --vl-rule at 3.01:1, which vanishes under veiling glare, leaving the most common task state rendering as blank space that reads as "not loaded". At 7.25:1 and 2px it survives. In Sonne: 2.5px #000000 at 21:1.

2. **in_progress / "In Arbeit"** — 2px --vl-ink-900 outline, LEFT HALF filled solid --vl-ink-900. Half-done, drawn. Ink coverage ~50%.
   · Deuteranopia: zero hue. The 50/50 split is a hard vertical edge at maximum contrast.
   · Sunlight: 18.2:1 fill on white. The silhouette (half-dark square) is a low-frequency signal — the kind that survives blur, motion and a scratched protector better than any glyph.

3. **blocked / "Blockiert"** — solid --vl-alert fill, white 3px horizontal BAR glyph (a bar, not an X — an X reads as cancelled), and **the mark is 30×24px: 50% wider and 20% taller than every other mark**. PLUS the entire row takes a 3px --vl-alert left edge and a --vl-alert-tint wash. It is the only row on screen that changes colour and the only mark that breaks the grid.
   · Deuteranopia: five redundant channels. Luminance (alert L=0.0896 vs ink L=0.0078 → 5.8:1 separation, so it reads as a distinctly lighter mark even with all hue removed); SIZE (the height channel, grafted from RASTER — nobody else uses it, and it survives greyscale, peripheral vision and CVD simultaneously); the bar glyph; the 3px row edge; the row wash.
   · Sunlight: 7.5:1 fill, oversized, plus a full-row treatment. Peripheral detection of a full row is far faster than of a 20px chip, which means a foreman scrolling 60 rows sees the exception without fixating. Theme-invariant: --vl-alert is byte-identical in light, dark and Sonne.

4. **done / "Erledigt"** — solid --vl-ink-900 SQUARE, white 2.5px check. A ticked box. Ink coverage 100%, square silhouette.
   · Deuteranopia: zero hue.
   · Sunlight: maximum-contrast fill. Distinguished from `approved` by SILHOUETTE, see below.

5. **approved / "Freigegeben"** — solid --vl-ink-900 **PLAKETTE**: the same fill and white check, but with a **pointed right edge** (6px notch, `clip-path: polygon(0 0, calc(100% - 6px) 0, 100% 50%, calc(100% - 6px) 100%, 0 100%)` on web; the identical polygon as a SwiftUI `Shape` on iOS). PLUS a Visum chip at the row's right edge — `VIS. M.B. · 14.03.` in Plex Mono, --vl-visum-ink on --vl-visum-tint — PLUS a double rule under the row (der Abschlussstrich). Ink coverage 100%, TAG silhouette.
   · **This is the single most important correction to the source direction.** Aktenlage rendered done and approved as pixel-identical marks in the very column it designed to be scanned vertically, pushing the differentiator to 11px mono at the opposite end of a 375px row — an arm's-length failure on the state that gates payment. The Plakette silhouette (grafted from Werkschild) fixes it: square vs pointed hang-tag is detectable in peripheral vision, in greyscale, and at 3m. It is also ledger-native rather than borrowed — a Visum on a hang-tag is exactly what a Swiss inspector leaves on released scaffolding, and the notch recurs as the seal on a signed Rapport.
   · Deuteranopia: zero hue in the mark. The Visum chip's tint is redundant reinforcement only.
   · Sunlight: the notch is a 6px silhouette feature on a 24pt mark — a shape difference, not an acuity task (contrast RASTER's answer, which asked the user to detect whether 2pt gaps were present).

`allowedTaskStatuses(role)` is untouched — a worker still stops at `done`. The Visum chip is simply the visual proof that only a foreman/office role could have produced the transition. In the status control, `approved` renders for workers as a Plakette OUTLINE with a Mono caps "NUR VORARBEITER" label rather than silently vanishing.

═══ B. PROJECT LIFECYCLE (5) → DER REGISTERREITER ═══
A completely different mechanism, so project and task status can never be confused on a screen showing both. No chip. A micro-11 uppercase letterspaced label with a RULE ABOVE IT, and the lifecycle lives in the rule.

- **planning / "Planung"** — NO rule. Label --vl-ink-500. The file is not open yet.
- **active / "Aktiv"** — 2px **--vl-mark-low #0284C7** rule. Label --vl-ink-900. The only project state that gets brand blue, and the only place in the product where brand blue signifies anything.
- **on_hold / "Pausiert"** — 2px --vl-rule-ink **DASHED 2-2**. Label --vl-ink-700. A literally interrupted line.
- **completed / "Abgeschlossen"** — **DOUBLE 1px --vl-rule-ink** (1px, 2px gap, 1px). Der Abschlussstrich. Closed books.
- **archived / "Archiviert"** — 1px --vl-rule, label --vl-ink-400, and the whole card's text drops to --vl-ink-500. Filed away.

· Deuteranopia: four of five are pure line-pattern. `active`'s blue is the only hue and it is redundant with being the only solid single 2px rule — the word is always there anyway.
· Sunlight: rules promote to 1.5px in field density, 2px #000000 in Sonne. Project status lives mostly on desktop where there is reading time, so it is deliberately quieter than the task Statusmarke — project status must never compete with task status.

═══ C. ROLE IDENTITY (5) → DAS KÜRZEL ═══
ZERO colour. Identity must never compete with state. A 2-letter Plex Mono abbreviation in a 22×22px box with a 1px --vl-rule outline, --vl-ink-700 on sheet. **IN** Inhaber · **GL** Geschäftsleitung · **VA** Vorarbeiter · **MO** Monteur · **KD** Kunde. (EN: OW / MG / FM / WK / CU, from the i18n dictionary.) Swiss trades already read two-letter codes off Bauplänen and Ausmassblättern; this is their convention, not a designer's.

ONE exception, and it is semantic rather than decorative: **KD is inverted** — solid --vl-ink-900 box, paper glyph — because the customer is the one role outside the company, and inside/outside is the distinction that actually matters when you are deciding what is visible to whom.

`ROLE_BADGE`'s five hues are deleted outright. `avatar.tsx`'s 8-colour hash palette is deleted with them: avatars become **squares** (radius 0) with Plex Mono initials in --vl-ink-700 on one of four ~6%-chroma --vl-copy-* carbon tints that are documented in the token file as carrying no meaning.
· Deuteranopia: no hue anywhere in identity. This structurally eliminates today's real misread risk, where emerald means both `approved` and "a person" on the same row.
· Sunlight: 9.6:1 glyphs at 11px office / 13pt field. Learning cost is real for the first fortnight on PeopleView; the full word ships alongside the Kürzel in every layout with room, and on hover/long-press everywhere else.

═══ D. RAPPORT DOCUMENT LIFECYCLE (4) → DER STEMPEL ═══
The fourth vocabulary, currently hiding as a local `StatusChip` in `rapport-panel.tsx`. Documents get stamped, and the terminal states reuse the Plakette silhouette so "released" means the same shape everywhere in the product.

- **draft / "Entwurf"** — 1.5px DASHED --vl-ink-400 rectangle, Mono caps. Provisional.
- **signed / "Unterschrieben"** — solid **PLAKETTE** (pointed right edge) filled --vl-ink-900, white Mono caps, with `14.03.2026 · 16:42` beneath. The sheet simultaneously FREEZES: a 3px --vl-rule-ink band appears on its top edge, the body drops to --vl-paper-sunk, and every edit control is **REMOVED FROM THE DOM / view tree**, not disabled — with one --vl-ink-500 line explaining why. A greyed-out button still says "this could change"; removal is the honest signal, and it answers the immutability rule both platforms' docs state verbatim.
- **sent / "Versendet"** — the signed Plakette REMAINS and a second Mono line is added: `Versendet 15.03.2026 · E-Mail`. Sent is an addendum to signed, not a replacement, which is factually what happened.
- **cancelled / "Storniert"** — Plakette outline and text in --vl-alert, with a 1.5px --vl-alert rule struck horizontally through the totals block. A Storno is drawn over, never deleted. The most ledger-native moment in the product.

· Deuteranopia: dashed vs solid vs solid-plus-second-line are three pure line/shape states; only `cancelled` uses hue, and it also carries the strike rule.
· Sunlight: the frozen state is a full-sheet treatment (top band + sunk ground + absent controls), which is the loudest possible signal short of colour.

═══ E. WHAT DOES NOT GET A NOTATION (enforced by lint) ═══
- Overdue/late: bold weight plus a Mono caps "SEIT 3 TAGEN". A delayed part is not a site hazard.
- Unread counts: a filled 8×8px --vl-ink-900 square in the row's left gutter. Not a coloured badge.
- Offline queue: keeps its existing restraint — renders nothing when the queue is empty (`SyncStatusSection.swift`'s comment is correct and stays) — and when queued becomes a 2px --vl-alert left rule with one Mono line, `3 WARTEN AUF SYNC`. No icon, no chip, no persistent bar.
- Customer-visible toggle: currently `.teal` on iOS. Becomes a 22×22 Kürzel-style checkbox carrying the **KD** glyph, inverted when on — the same notation as the customer role badge, so "this goes to KD" is literally spelled out. Zero new hue.

═══ F. THE PORTAL COLLAPSE ═══
At the portal boundary the five task statuses collapse to **two** — `offen` (empty square, 2px --vl-ink-500) and `fertig` (solid --vl-ink-900 square + white check) — using the `status === "done" || status === "approved"` predicate the code already computes. `blocked` and `in_progress` collapse to `offen`. No Registerreiter, no Kürzel, no Visum, no Plakette, no alert hue anywhere. The internal pipeline is not the homeowner's business, and completed steps are NEVER struck through — strikethrough reads as cancelled, not as finished.

---

## Surface specifications

### Desktop shell + navigation (web/src/components/sidebar.tsx, web/src/app/(app)/layout.tsx)

The slate-900 rail is DELETED — it is the single strongest generic-SaaS tell in the product and the brief names it. Desktop ≥768px: a 232px column on --vl-paper-desk, separated from the content by a single 1px --vl-rule — no fill change, just the rule. Briefkopf at the top: real <BrandMark> at 20px + 'Ventline' at --vl-text-body-strong + company name at micro-11 caps --vl-ink-500, with a 1px --vl-rule under the whole band. Nav items are 40px rows, micro-11 uppercase letterspaced labels in --vl-ink-700 with the new 1.5px Icon glyphs at 20px; the active item goes --vl-ink-900 with a 3px --vl-ink-900 left edge (the same notation as a blocked row's edge, in ink rather than alert — one grammar, two meanings, distinguished by hue). The user block at the bottom: square Avatar + name + the Kürzel box, replacing the coloured RoleBadge. Mobile <768px: the header becomes --vl-paper-sheet with a bottom 1px --vl-rule, height stays 56px but moves into --vl-topbar and is consumed by chat/page.tsx:35 and tasks/[taskId]/page.tsx:81 as calc(100dvh - var(--vl-topbar)). Hamburger is the three-rule Icon glyph in a 48×48 target; the open menu is a full-width sheet with 1px rules between items, not a floating dropdown.

### Project overview (web/src/app/(app)/page.tsx, web/src/components/overview/project-card.tsx)

Not cards. A single sheet holding a ruled table. Row content, left to right: a 40×40 square hard-cropped thumbnail with a 1px --vl-rule (radius 0, no shadow); project name at --vl-text-lead + customer/Ort at meta-12 --vl-ink-500 on the line below; the tally as Plex Mono tabular '14/22' plus a 4px square-ended progress bar on a --vl-rule-hair track; the Registerreiter (the status label with its rule above); last activity in Plex Mono meta, right-aligned. Rows 36px office / 56px field, separated by 1px --vl-rule-hair, hover fill --vl-paper-hover. The status-filter tabs stop being rounded-full pills and become a register: micro-11 uppercase labels with a 2px --vl-ink-900 underline on the active one. This ships as ONE new shared <SegmentedControl>, replacing the four independently-authored local pivotClass/chip helpers in overview page, inbox-view.tsx, inbox-search.tsx and export-panel.tsx.

### Task board / Arbeitspaket → Arbeitsschritt (web/src/components/project/task-board.tsx, web/src/app/(app)/projects/[projectId]/page.tsx)

Grouped-by-status disclosure is preserved. Section headers become micro-11 uppercase caps on a 2px --vl-rule ('IN ARBEIT · 4') — the current rounded-full count badge is deleted. Every row leads with its Statusmarke in the fixed 20px --vl-markspalte, so the marks form the vertical scan stripe. Packages are --vl-text-head rows with a 1px --vl-rule beneath and a Werkplakette plate — 'AP-03' in Plex Mono 11px on --vl-paper-sunk — plus a fraction '4/7' in Mono. Steps indent one --vl-indent-step (24px office / 20px field) behind a 2px --vl-rule VERTICAL RISER running the full height of the step group, with a 12px horizontal tick into each row: the drawing convention of a Steigzone, which every installer reads instantly. Steps carry '03.2'. This replaces today's `border-l border-slate-200 pl-4` and is the durable answer to the never-flatten invariant both platforms' docs state verbatim — the number carries the hierarchy even where the layout physically cannot (search results, inbox hits, a screen reader, a phone call). Sorting: blocked rows first, then by pipeline position, so the eye reads the Markenspalte vertically like a bar chart. Disclosure is a 44pt hit area with a 1.5px chevron drawn in the icon pen.

### Inbox (web/src/components/inbox/inbox-view.tsx, thread-row.tsx, inbox-search.tsx, person-lens.tsx)

The three pivot tabs become the shared <SegmentedControl>. Thread rows sit on a sheet: 8×8px filled --vl-ink-900 unread square in the left gutter (replacing the coloured badge), project/task name at --vl-text-body-strong, the Werkplakette number in Mono so a hit out of context still says where it lives, sender Kürzel + square avatar, last-message excerpt at meta --vl-ink-500, timestamp Mono right-aligned. Rows separated by 1px --vl-rule-hair. The attention banner keeps its position but becomes a 2px --vl-alert left rule with the copy in --vl-ink-900 — no filled card. person-lens.tsx's inlined from/to direction badge is DELETED and re-pointed at <Kuerzel>. inbox-search.tsx's filter chips become register labels with a 2px underline.

### Chat thread — the log (web/src/components/chat/chat-thread.tsx, message-bubble.tsx, message-body.tsx, voice-player.tsx)

The single most identity-defining surface, and the one place DER RANDSTRICH lives. Bubbles are deleted. Each entry is a ruled row: a 52px (office) / 56px (field) left gutter carrying the time in Plex Mono meta --vl-ink-500, a 1px --vl-rule VERTICAL at the gutter's right edge running the full height of the thread, then author (Kürzel box + name at meta-500 --vl-ink-700; your own name at --vl-ink-900/600) and body at --vl-text-read. Own messages are NOT right-aligned and NOT tinted — in a record, whose entry it is does not change where it sits, and right-aligned bubbles make a thread unquotable and unprintable. NOTE ON SCOPE: the Randstrich is deliberately scoped to CHRONOLOGY only — chat threads and chronological lists — because those are already hand-built flex/LazyVStack columns on both platforms, where a single full-height rule is trivial. It is explicitly NOT used on List-based screens, where a continuous cross-cell rule is not expressible in SwiftUI; there the --vl-markspalte stripe is the scan device. Day boundaries become datelines: a full-width 1px --vl-rule with 'MITTWOCH, 14. MÄRZ 2026' inset at micro-11 caps --vl-ink-500 on paper. System messages ('hat die Aufgabe als erledigt markiert') carry no author, sit at meta --vl-ink-500, and get a 4px filled --vl-ink-500 square in the margin gutter — a ledger annotation, typographically distinct from human speech. Photos become numbered exhibits: 'BELEG 3' at micro-11 caps above an 88px square thumbnail with a 1px --vl-rule and no radius. Mentions and task refs in --vl-link with a 1px underline at 2px offset. Voice waveform bars go 2px wide, 2px gap, --vl-ink-700, square ends.

### Task detail + composer (web/src/app/(app)/projects/[projectId]/tasks/[taskId]/page.tsx, web/src/components/chat/composer.tsx, web/src/components/task/task-status-control.tsx, customer-visibility-toggle.tsx, task-files.tsx)

Field density: body 17/25, --vl-ink-400 forbidden, everything ≥48pt. Header: task title at --vl-text-head wrapping to 3 lines and never truncated, with the full-width Statusmarke at 32px directly beneath it — the largest instance of the mark in the product, readable across a room — then a Mono micro context line 'AP-03 · PROJEKT' as a breadcrumb. The status control is a full-width 56pt control whose face IS the Statusmarke: display and control are the same object. Composer: --vl-paper-sunk well with a 1.5px --vl-rule top edge, --vl-radius-box field, three 56×56 targets (Kamera / Sprachnachricht / Senden), Senden as a solid --vl-ink-900 SQUARE with a white arrow — a stamp you press. The 'sichtbar für Kunden' control becomes a 22×22 Kürzel-style checkbox carrying the KD glyph, inverted when on. Mention chips are 1px --vl-rule outlined Mono tokens, not capsules. task-files.tsx thumbnails become 1px-ruled squares.

### Rapport (web/src/components/rapport/rapport-panel.tsx, rapport-photos.tsx, web/src/app/(app)/projects/[projectId]/rapporte/page.tsx)

The screen IS the document, at 720px document-sheet width with 75px padding. 'RAP-2026-0142' in Plex Mono top-right — a record without a visible number is not a record. Stat tiles become 1px --vl-rule plates with micro-11 caps labels above --vl-text-figure numbers. Arbeitszeit and Material are ruled tables: micro-11 uppercase column heads underlined by 1px --vl-rule, right-aligned Plex Mono tabular columns, a new `hoursAndMinutesColumnar()` in web/src/lib/rapport.ts always padding to '7 h 00' so hour columns align (a four-line sibling of the existing function; `chf()` is untouched), a 1.5px --vl-rule-ink above Total and a DOUBLE RULE below it. The divergence banner uses a 2px --vl-alert left rule on --vl-paper-sunk, never a filled alert field — a discrepancy to check is not a site hazard, and that restraint is what keeps --vl-alert meaningful. Photos above the signature get a micro-11 'BEWEISFOTOS' header, because the docs are explicit that they are evidence for the lines above. rapport-panel.tsx's local StatusChip is DELETED in favour of the shared <DocumentStamp>. On signing: the UNTERSCHRIEBEN Plakette appears, a 3px --vl-rule-ink band lands on the sheet's top edge, the body drops to --vl-paper-sunk, and all edit controls are removed from the DOM. Signature block: a 1.5px --vl-rule-ink line with the drawn signature above and 'Alpenluft Klima AG · 14.03.2026 · 16:42' in Mono meta below.

### Treuhänder export (web/src/components/export/export-panel.tsx)

Pure office density, pure typography, zero colour — the point is that the selling point is arithmetic, so the design has to look like arithmetic. Two ruled tables: the MWST recap (one row per rate group) and the row-capped preview. micro-11 uppercase column heads on a 2px --vl-rule; 1px --vl-rule-hair row rules; zebra on --vl-paper-sunk; every numeric cell right-aligned in Plex Mono 13px tabular so the U+2019 grouping in 1'234.55 stays in one vertical rail. Each rate group carries a 2px --vl-rule-hair left rule so the grouping is STRUCTURAL, not implied, and each group total sits on a 1px rule with the grand total on a double rule. The existing copy — 'Jede Betragsspalte zählt korrekt zusammen — nichts steht doppelt' — sits directly under the recap in --vl-ink-700, because the sentence and the layout are making the same claim. Quarter/YTD presets use the shared <SegmentedControl>.

### Customer portal (web/src/app/portal/layout.tsx, page.tsx, [projectId]/page.tsx, web/src/components/portal/portal-header.tsx, photo-timeline.tsx)

DIE GELBE DURCHSCHRIFT. The portal sheet is --vl-paper-copy #FBF4E0 — the same document, the customer's copy, exactly as the three-part NCR Rapportblock in the van works — and it carries an explicit 'Ihre Kopie · Alpenluft Klima AG' line at micro-11 caps so the metaphor actually reaches the homeowner rather than staying a rationale. The bg-slate-50 ground is removed; it exists nowhere else in the system. Portal density: 64px rows, 18px body, 640px measure, NO tables. Briefkopf uses the real <BrandMark> — killing hardcoded 'V' square #3 — plus the company name. Progress is stated as a SENTENCE at --vl-text-lead — '14 von 22 Schritten erledigt' — over a 4px square-ended --vl-ink-900 bar on a --vl-rule-hair track, not a percentage widget. Steps nest under packages behind the same 2px riser, never flattened. Task lines carry only the TWO-STATE collapse: offen (empty 2px --vl-ink-500 square) and fertig (solid --vl-ink-900 square + white check), with completed text dropping to --vl-ink-700 and NEVER struck through — strikethrough reads as cancelled, not finished. Photos are Belege with dates in a day-grouped grid of 1px-ruled squares. Zero edit affordances, zero Kürzel, zero alert hue, no Registerreiter, no Sonne. Light theme only — a homeowner opens a magic link in daylight. This is the calmest surface in the product and the one an external buyer judges the firm by.

### r/[token] — the unauthenticated document link (web/src/app/r/[token]/page.tsx)

Kept as its own third template, correctly — not folded into the portal shell. A 480px --vl-paper-copy sheet centred on --vl-paper-desk, with a 1px --vl-rule-ink border (heavier than an internal card: this is a document, not a card). Briefkopf with <BrandMark> at 32px, then 'RAPPORT' at micro-11 caps and the document number in Plex Mono as the masthead. A ruled two-column summary (Datum / Betrag / Rapport-Nr.) with 1px hairlines and the amount at --vl-text-figure. The PDF link is the ink-filled primary at 56pt full width. The expired state loses the 🔒 emoji for the Icon-set padlock at 24px in --vl-ink-500 on a --vl-paper-sunk field, with the copy at --vl-text-read — muted, not alarming, because an expired link is not a hazard and must never use --vl-alert. This page is opened by people with no account, often months later, sometimes on a bad phone: nothing on it is dense.

### iOS field screens — the 14 List instances (MyTasksView.swift, ProjectDetailView.swift, PeopleView.swift, RapportView.swift, InboxView.swift, CustomerPortalView.swift, TimeTrackerView.swift, MaterialsView.swift)

REskinned, not rewritten — this is the practical payoff of the direction and no card-based alternative can claim it. Per screen, roughly five modifiers: `.listStyle(.plain)` + `.scrollContentBackground(.hidden)` + `.background(VL.paperDesk)` + `.listRowBackground(VL.paperSheet)` + `.listRowSeparatorTint(VL.ruleHair)` + `.listRowInsets(.init(top: 14, leading: 16, bottom: 14, trailing: 16))`, with rows reaching 56pt via `.frame(minHeight: VL.row)`. Section headers become micro-caps text on a 2px `Rectangle()`. Every task row leads with its Statusmarke in a fixed 24pt column. The 9 `Form` instances in the creation sheets are LEFT ALONE — --vl-radius-box is 2px specifically so `Form`'s grouped insets remain acceptable, which preserves keyboard avoidance, focus traversal and scroll-to-focused-field for free. ProjectListView.swift's shadowed rounded-16 ProjectCard — the one place iOS echoes the old web look — is replaced by the same ruled rows, deleting the app's only two `.shadow()` calls. ComposerBar.swift: the PhotosPicker and mic frames go 40→56 and the send button gets an explicit 56×56 frame with `.contentShape(Rectangle())`, all enforced inside one shared `VLIconButton` so no call site can regress. TaskDetailView.swift's ~30pt inline 'Update' menu is replaced by a full-width 64pt `.safeAreaInset(edge: .bottom)` bar labelled with the NEXT status ('→ ERLEDIGT'), whose face is itself a Statusmarke. SignaturePadView.swift: pen 3pt → 4.5pt, canvas 220 → 260pt. PhotoMarkupView.swift: pen 6pt → 8pt, ink `.systemRed` → VL.alert. `.dynamicTypeSize(...DynamicTypeSize.accessibility2)` and `.minimumScaleFactor(0.85)` land across all field screens — none of the three exist anywhere in ios/ today.

### Auth / onboarding (web/src/app/(auth)/login/page.tsx, web/src/app/onboarding/page.tsx, web/src/components/auth/login-form.tsx, onboarding-form.tsx, ios/Ventline/Features/Auth/AuthView.swift)

A 400px sheet on --vl-paper-desk, flush-left inside the sheet rather than centre-aligned. Real <BrandMark> at 32px above the company name — deleting hardcoded 'V' square #1 and #2, so all three copy-pasted div-based logos die in one commit. Inputs are --vl-radius-box, 1px --vl-rule, 48px tall, with micro-11 caps labels above; focus swaps to the 2px --vl-focus ring. Primary button is a full-width 52pt --vl-ink-900 rectangle. The Einladungscode keeps its monospaced display but at --vl-text-figure with +0.08em tracking in a 1px --vl-rule box on --vl-paper-sunk — it reads like a reference number because that is what it is. The onboarding sheet is the first thing an owner ever sees, so it carries one ruled 'Was du bekommst' list, not an illustration. iOS AuthView's SF Symbol wrench-and-screwdriver placeholder is replaced by the new SwiftUI BrandMark Shape.

---

## Rollout

Each phase ships independently and leaves the app working.

| # | Phase | Effort |
|---|---|---|
| 1 | Token layer, fonts, and the radius kill-switch | 2 days |
| 2 | Status and identity — the notation system | 2 days |
| 3 | Primitives, icons and shell | 3 days |
| 4 | Web office surfaces | 3 days |
| 5 | The log | 2 days |
| 6 | iOS token layer, List reskin, and the tap-target fixes | 4 days |
| 7 | Customer-facing surfaces, PDF chrome and Belege | 3 days |
| 8 | Sonne, enforcement, and the sweep close-out | 2 days |

### Phase 1 — Token layer, fonts, and the radius kill-switch (2 days)

**Goal.** Stand up design/tokens.json as the single source of truth, generate web/src/app/tokens.css, wire IBM Plex, and land the day-one @layer utilities override so the 138 rounded-* sites collapse without a 38-file atomic commit.

**Visible after this phase alone.** The whole app changes typeface, ground colour and radius at once. Every card loses its shadow and its 16px corners; the page ground goes from the blue-tinted #f8fafc to the warm #F2F0EA desk; money and time columns become tabular Plex Mono. It already looks like a different product and nothing is broken, because tokens.css only redefines what globals.css already fed to @theme.

**Files.**

- `design/tokens.json (new)`
- `scripts/build-tokens.mjs (new)`
- `web/src/app/tokens.css (new, generated, committed)`
- `web/src/app/globals.css`
- `web/src/app/layout.tsx`
- `web/src/app/fonts/ (new — Plex Sans 400/500/600 + Plex Mono 400/500 woff2 subsets)`
- `web/src/i18n/dictionaries/de.ts (lang de-CH + ~20 soft-hyphen strings)`
- `package.json (build:tokens script)`

### Phase 2 — Status and identity — the notation system (2 days)

**Goal.** Replace all 20 class bundles plus the two escaped maps with four notations and one hue, keeping every existing export signature so the ~30 call sites compile untouched.

**Visible after this phase alone.** Fifteen pill colours become one. The Statusmarke stripe appears in the leftmost column of every task list; approved rows grow their Plakette notch and Visum chip; blocked rows take the alert edge and wash. Role badges become Kürzel; avatars go square and achromatic.

**Files.**

- `web/src/lib/status.ts`
- `web/src/components/status-pill.tsx (keeps ProjectStatusPill / TaskStatusPill / RoleBadge exports; gains StatusMark, Kuerzel, Registerreiter, DocumentStamp)`
- `web/src/components/avatar.tsx (COLORS array deleted)`
- `web/src/components/rapport/rapport-panel.tsx (local StatusChip deleted)`
- `web/src/components/inbox/person-lens.tsx (inline direction badge deleted)`
- `web/src/components/project/task-board.tsx (TASK_STATUS_DOT consumers)`

### Phase 3 — Primitives, icons and shell (3 days)

**Goal.** Retire every emoji, unify the two overlays, ship the shared SegmentedControl and IconButton, and delete the slate-900 rail.

**Visible after this phase alone.** The dark sidebar is gone and the app's silhouette changes completely. All ~16 emoji sites carry drawn glyphs. The four re-implemented pivot/chip helpers collapse into one component. NOTE: --vl-topbar keeps the value 56 in this commit; any change to it ships separately so a regression in the chat/task shells is attributable.

**Files.**

- `web/src/components/icon.tsx (new)`
- `design/icons.json (new — 18 glyphs)`
- `web/src/components/segmented-control.tsx (new)`
- `web/src/hooks/use-overlay.ts (new — Escape + scroll-lock, currently duplicated)`
- `web/src/components/form.tsx`
- `web/src/components/modal.tsx`
- `web/src/components/chat/lightbox.tsx`
- `web/src/components/sidebar.tsx`
- `web/src/app/(app)/projects/[projectId]/chat/page.tsx (line 35 → --vl-topbar)`
- `web/src/app/(app)/projects/[projectId]/tasks/[taskId]/page.tsx (line 81 → --vl-topbar)`

### Phase 4 — Web office surfaces (3 days)

**Goal.** Sweep the desk-density screens onto the new primitives and land the Werkplakette hierarchy.

**Visible after this phase alone.** Overview, board, inbox, export, customers, people and settings are ruled tables on sheets. AP-03 / 03.2 numbering appears; the riser replaces the pale border-l; the Treuhänder recap looks like an Erfolgsrechnung.

**Files.**

- `web/src/app/(app)/page.tsx`
- `web/src/components/overview/project-card.tsx`
- `web/src/components/overview/new-project-button.tsx`
- `web/src/components/project/task-board.tsx`
- `web/src/components/project/new-task-button.tsx`
- `web/src/components/project/project-status-select.tsx`
- `web/src/components/project/members-panel.tsx`
- `web/src/app/(app)/inbox/page.tsx`
- `web/src/components/inbox/inbox-view.tsx`
- `web/src/components/inbox/thread-row.tsx`
- `web/src/components/inbox/inbox-search.tsx`
- `web/src/components/export/export-panel.tsx`
- `web/src/components/customers/customers-panel.tsx`
- `web/src/components/people/members-table.tsx`
- `web/src/components/people/invite-panel.tsx`
- `web/src/components/settings/settings-forms.tsx`
- `web/src/components/settings/billing-form.tsx`

### Phase 5 — The log (2 days)

**Goal.** Rebuild chat as a ruled ledger with the Randstrich, and land the field-density task detail.

**Visible after this phase alone.** The signature surface. Bubbles are gone, timestamps sit in the margin behind a full-height rule, day boundaries are datelines, system messages are annotated in the gutter. This is the screenshot that sells the direction. HONEST NOTE: this is the largest non-mechanical edit in the plan — those files are fully custom today, so it is a rewrite of five components, not a reskin.

**Files.**

- `web/src/components/chat/chat-thread.tsx`
- `web/src/components/chat/message-bubble.tsx`
- `web/src/components/chat/message-body.tsx`
- `web/src/components/chat/composer.tsx`
- `web/src/components/chat/voice-player.tsx`
- `web/src/app/(app)/projects/[projectId]/tasks/[taskId]/page.tsx`
- `web/src/app/(app)/projects/[projectId]/chat/page.tsx`
- `web/src/components/task/task-status-control.tsx`
- `web/src/components/task/customer-visibility-toggle.tsx`
- `web/src/components/task/task-files.tsx`

### Phase 6 — iOS token layer, List reskin, and the tap-target fixes (4 days)

**Goal.** Give iOS a generated token layer and vector BrandMark, reskin all 14 Lists in place, and fix the three under-HIG controls inside a primitive so they cannot regress.

**Visible after this phase alone.** iOS stops disagreeing with the brand: the orange tint is gone, the mark is a live vector, and the app looks like the web build. The composer's illegal 40pt targets and the unframed send button are fixed, the signature and markup pens widen for cold hands. HONEST NOTE: the 9 Form sheets are deliberately NOT touched, and the per-row density work across 14 Lists is real per-call-site editing, not a zero-touch swap.

**Files.**

- `ios/Ventline/Core/Design/Tokens.generated.swift (new)`
- `ios/Ventline/Core/Design/StatusTokens.generated.swift (new)`
- `ios/Ventline/Core/Design/BrandMark.swift (new)`
- `ios/Ventline/Core/Design/VLIconButton.swift (new)`
- `ios/Ventline/Core/Design/StatusMark.swift (new)`
- `ios/Ventline/Resources/Assets.xcassets/AccentColor.colorset (#E87A2E → #0284C7 / #38BDF8)`
- `ios/Ventline/Core/Models/Domain.swift (ProjectStatus/TaskStatus .color → tokens)`
- `ios/Ventline/Features/Chat/ComposerBar.swift (40 → 56, send gets a frame)`
- `ios/Ventline/Features/Tasks/MyTasksView.swift`
- `ios/Ventline/Features/Tasks/TaskDetailView.swift`
- `ios/Ventline/Features/Projects/ProjectListView.swift`
- `ios/Ventline/Features/Projects/ProjectDetailView.swift`
- `ios/Ventline/Features/Inbox/InboxView.swift`
- `ios/Ventline/Features/People/PeopleView.swift`
- `ios/Ventline/Features/Rapport/RapportView.swift`
- `ios/Ventline/Features/Rapport/SignaturePadView.swift`
- `ios/Ventline/Features/Markup/PhotoMarkupView.swift`
- `ios/project.yml (UIAppFonts)`
- `scripts/build-app-icon.py (reads geometry + hexes from tokens.json)`
- `web/src/components/brand-mark.tsx (hexes → var())`

### Phase 7 — Customer-facing surfaces, PDF chrome and Belege (3 days)

**Goal.** The storefront pass plus the token layer's reach into the artefact the customer keeps.

**Visible after this phase alone.** All three hardcoded 'V' squares are dead. The portal is the yellow customer copy with a two-state checklist. The row rule on screen and the row rule in the PDF are the same number from the same JSON. Belege are numbered — scoped to the Rapport as numbering authority (deterministic ordering by created_at, id), which keeps it out of the three-renderer sync problem. supabase/functions/render-document/qrbill.ts is NOT opened.

**Files.**

- `web/src/app/portal/layout.tsx`
- `web/src/app/portal/page.tsx`
- `web/src/app/portal/[projectId]/page.tsx`
- `web/src/components/portal/portal-header.tsx`
- `web/src/components/portal/photo-timeline.tsx`
- `web/src/app/r/[token]/page.tsx`
- `web/src/app/(auth)/login/page.tsx`
- `web/src/app/onboarding/page.tsx`
- `web/src/components/auth/login-form.tsx`
- `web/src/components/auth/onboarding-form.tsx`
- `web/src/components/rapport/rapport-panel.tsx`
- `web/src/components/rapport/rapport-photos.tsx`
- `web/src/lib/rapport.ts (hoursAndMinutesColumnar)`
- `supabase/functions/render-document/tokens.ts (new, generated)`
- `supabase/functions/render-document/index.ts (chrome above the perforation only)`
- `scripts/build-fonts.py (subset + embed Plex alongside Liberation Sans)`
- `ios/Ventline/Features/Customer/CustomerPortalView.swift`
- `ios/Ventline/Features/Auth/AuthView.swift`

### Phase 8 — Sonne, enforcement, and the sweep close-out (2 days)

**Goal.** Ship the high-visibility theme, add the CI that makes 'one source of truth' true rather than aspirational, and remove the temporary radius override.

**Visible after this phase alone.** A one-tap Sonne control in the iOS field tab bar: white ground, black 2px rules, type one rung up, 56/64pt targets, all motion off — the most demoable feature in the product. CI fails on stale generated files and on raw Tailwind palette classes. HARD SCOPE: Sonne is field-density only — never the portal, never desktop — so it adds ONE QA cell, and it is auto-SUGGESTED at high screen brightness, never auto-applied.

**Files.**

- `.github/workflows/design.yml (new)`
- `scripts/lint-tokens.mjs (new)`
- `web/src/app/tokens.css (sonne block)`
- `ios/Ventline/Core/Design/Theme.swift (new — Sonne toggle in the field tab bar)`
- `web/src/app/globals.css (delete the @layer utilities radius override)`
- `docs/decisions/design-system.md (new)`

---

## Open questions — owner's call, not the designer's

1. Does Sonne ship at all? It is the single most demoable feature in the plan and the field lens rates it the highest-value idea in the whole set — but it is also the only thing that makes the theme matrix bigger than light/dark, and it needs one round of validation with a real crew on a real roof before it is worth the QA. Kill-criterion: if crews do not reach for it in a two-week pilot, cut it and reclaim two days. This is a product bet, not a design one.

2. How yellow is the customer's copy? I have set --vl-paper-copy to #FBF4E0, a genuinely perceptible carbon tint, against Aktenlage's original #FDFBF2 which was effectively invisible. It is now unmistakably 'the yellow sheet' — which is the point — but it also reads slightly retro on a bright phone and it will look wrong to anyone expecting a white SaaS page. The value is one token. Look at it on a phone in a kitchen and decide.

3. Should `blocked` be visible to the customer at all? The portal currently collapses five statuses to two, so a blocked step reads as simply 'offen' — the homeowner learns nothing is happening but not why. That is a deliberate curation choice ('Customer portal is curation, not access'), but there is a real commercial argument the other way: a firm that proactively says 'wir warten auf ein Teil' looks better than one that goes quiet. If the answer is yes, it needs a designed extension, not an ad hoc borrow of the alert notation into a surface that is otherwise hue-free.

4. German role vocabulary for the Kürzel. Today de.ts has role.manager = 'Manager', which gives no natural two-letter code. I have specified GL (Geschäftsleitung); BL (Betriebsleitung) and BÜ (Büro) are equally defensible and BÜ is what a lot of crews actually say. Also role.worker is currently 'Mitarbeiter' but the trade word is 'Monteur' — MO reads correctly against Monteur and oddly against Mitarbeiter. This is a copy decision with a design consequence and it is the owner's vocabulary, not mine.

5. Is a dark theme offered as a manual toggle on web, or does it only follow the system? Building both costs nothing extra in the token layer (the [data-theme] override block is generated either way), but a manual toggle is a visible control that has to live somewhere in the shell, and this product's users are overwhelmingly in daylight. My default is: follow the system, no toggle on web, manual toggle on iOS only alongside Sonne.

6. Is there budget, later, for a licensed Swiss typeface? The answer changes nothing about Phase 1 — everything routes through --vl-font-sans / --vl-font-mono — but it changes what a family swap is allowed to cost. The hard constraint is non-negotiable and must be in any quote request: the face must be embeddable in PDFs distributed to third parties and retained for years, AND embeddable in an iOS binary. Most Swiss foundries will quote both; some will not permit the first at any price.

7. How much does the first-thirty-seconds coldness matter to the sale? This is the direction's real commercial risk and I cannot resolve it from here. A 54-year-old Sanitär-Meister opening flat white sheets with hairlines may read 'unfertig' rather than 'sauber'. The honest kill-criterion after five demos: if owners describe it as 'streng' or ask whether it finished loading, the direction is wrong for the market and RASTER (with the font money) or a warmer variant is the fallback. The German copy is already doing the warmth work; if that turns out not to be enough, adding warmth back means adding it in colour, which this system deliberately has nowhere to put.

