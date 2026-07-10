# Decisions — notes-first round (2026-07-10)

dam's answers to sac's open-question rounds on #189 (notes-first), #179 (Plan 12
product questions), and #181 (vocab seeding), resolved 2026-07-10. CANON carries
the one-line rulings; this doc carries the context and the work plan that falls
out. Written so either of us can sync from a cold start.

## The pivot: notes-first (#189 — ADOPTED)

A walk's first-level output is **notes** — a smart field-log writeup (summary
card + findings grouped by kind, trade-aware groupings, photos pinned inline,
transcript collapsed to "show what I heard"). Documents stop being auto-built
at DONE and become **explicit action buttons** on the notes screen: "TURN THESE
NOTES INTO → Estimate / Invoice / Work Order / …" per trade.

Why this isn't a slide to vitamin (sac's teardown argument, dam co-signs): every
rival stops at clean notes + generic export. The visible action-button row that
produces finished, trade-specific, priced documents IS the moat — moved from
the default output to the primary action. Guardrail: those buttons stay
prominent and magical, never a buried menu.

### Seam answers

| Q | Answer | Notes |
|---|--------|-------|
| finish() output | **Notes only.** Auto build_document at DONE removed. | finish() already returns items + summary — that IS the notes payload. |
| Document transform | **Hybrid.** Structure re-renders deterministically from structured items; LLM only where reasoning is needed. | Zero LLM for Export Notes and every document's skeleton. |
| Pricing | **LLM pass, v1.** One focused pricing call on Estimate/Invoice taps. | No price book exists yet; the seam is designed so price-book lookup slots in front later (lookup first, LLM fallback). |
| Persistence | **Note = durable per-session artifact. Documents = derived snapshots.** | 0..N documents per note; note edits never silently change generated docs; regenerate is explicit. Maps onto the existing artifact seam. |
| Per-trade button sets, export format, notes visuals | **sac's** (Q3/Q4). | Landscape: Estimate/Invoice/Work Order · property: Condition/Move-out · inspection: Inspection Report · universal: Export + Follow-ups — sac drafting. |
| Follow-ups | In-app list v1; Reminders export later. | Core will own follow-up items as data if/when needed — flag at design time. |

### Core work that falls out → **Plan 13** (dam, next core plan)

1. finish() stops calling build_document; notes payload becomes the finish
   contract (items + summary — mostly a removal).
2. New on-demand `build_document(kind)` engine path (throwing, priced per tap):
   deterministic structure render + optional pricing pass. Snapshot semantics
   into the artifact seam (document keyed to note/session, immutable once
   generated).
3. FFI surface for the action buttons; `// sac:` markers at the notes-screen
   hooks.
4. R9 note: per-tap cost is proportional to the tap — free to look, one cheap
   call to monetize.

## Companion decisions

- **TestFlight internal lane → real engine** (from build next-after-merge).
  Mechanism: GitHub Actions secret injected at archive time; never in the repo.
  **dam's one manual step: `gh secret set` the key (+ base URL) — do not paste
  key material anywhere else.** External-tester key handling remains open.
- **Device STT default → base.en** (revert of #175's promotion). sac's
  real-device lag on iPhone 16e settles the T5 question for now; small.en stays
  one launch arg away (`sttmodel=small.en`). Accuracy strategy = vocabulary
  biasing (the "wheelbarrow" device finding is its best evidence yet).
- **Plan 12 product answers** (sac answered, dam acked): manual rows show
  photos via session-scope grouping client-side; item↔row strictly 1:1 in v1.
- **Vocab seeding** (joint round closed): hybrid trigger riding the first-run
  profile flow, demo walk before the vocab card, bundled JSON packs
  (sac-curated, CI schema test, all writes through the Plan 10 funnel),
  type-only interview, SEED_MAX≈60. Implementation queued AFTER Plan 13.
- **Rename (#188)**: Isaac picking from Jefe / Hardcopy / Goldenrod / CopyThat;
  dam co-signs in CANON when picked. ASC listing rename stays deferred until
  then — nothing public is locked to "Sitewalk".

## Work queue after this round

| Owner | Item |
|-------|------|
| dam | Review #187 (voice-first) + #190 (onboarding/profile/DONE fix), thinking-first, then merge (CI kick needed — sacmeng Actions still account-disabled) |
| dam | Plan 13 (notes-first core) — plan → adversarial review → build → final review |
| dam | base.en default flip + CI-secret key injection (small PRs; key secret is dam-manual) |
| sac | Notes screen build (unblocked by the Q1/Q2 answers above) |
| sac | Per-trade action-button taxonomy; photo-grouping styling on the review document |
| Isaac | Rename pick → dam CANON co-sign |
