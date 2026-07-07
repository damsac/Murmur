# Design: Onboarding — Vocabulary Seeding

**Date:** 2026-07-07 · **Status:** Proposal for dam + sac to react to (not a plan, not code)
**Owner tags:** core mechanics = **dam**, flow/visuals = **sac**, contested = **joint**
**Reads:** vision spec Rev 3 amendment 3 (onboarding interview seeds vocabulary → LLM context + STT biasing; orator2 adaptive-hotwords prior art), Plan 10 (vocabulary write half — LANDED: `add_vocabulary_term` funnel, `MAX_VOCABULARY_TERMS=100`, `MAX_VOCABULARY_TERM_WORDS=6`, FFI CRUD, `VocabularyView`), memory-frontier research (≤100 curated phonetically-confusable terms; vocabulary→ASR biasing is *novel*, no published precedent).

This doc answers the six open questions Plan 10 deferred with "onboarding interview = joint dam+sac, out of scope (D9)." It proposes *when* to seed, *what* to ask, *how* answers become vocabulary, how seeding interacts with reflection, the skip path, and how we measure it. Every write goes through the **existing** Plan 10 funnel — no new write path is proposed.

---

## Motivation *(joint)*

Vocabulary → STT biasing is the product's genuinely-novel differentiator (+10–19 pp term recall on the spike; frontier survey found no published precedent). But it has a **cold-start hole**: a brand-new user's `vocabulary` section is empty, so their *first* walk — the one that forms the first impression — gets zero biasing. That is exactly when transcription is worst (unknown crew names, local place names, trade jargon), and exactly when a bad transcript costs the most trust.

Reflection (Plan 02/10) fills the section *over time* by learning from walks. Seeding sets the **prior** so the loop starts warm instead of cold. The design tension is that the target user (gloved, hurried, not tech-savvy — Pillar 1 "stupid simple", R-series bias to *not interrupting work*) will abandon a long setup. So the whole design is governed by one rule: **seeding must be cheap, skippable, and never block the first walk.**

---

## Q1 — When do we seed? *(dam owns the mechanic; sac owns the surface)*

**Recommendation: progressive, triggered at first-job creation — not a first-run wall.** After the BYOK key step (already the highest-churn onboarding moment, spec §8), the *first* time the user creates a job or ends their first walk, offer a single lightweight vocabulary prompt ("Add a few words we'll get wrong?" → template starter pack + 2–3 free-form terms). One screen, ~30s, fully skippable.

- **Rationale:** R-series says don't interrupt work; a cold first-run vocabulary wall before the user has *any* context (they don't yet know what the app gets wrong) is low-yield and high-friction. Anchoring to first-job/first-walk means the user already has a concrete site in mind, so "crew names, supplier, local jargon" is answerable.
- **Alternative A — first-run onboarding step.** Pro: guaranteed seeding before walk #1 (closes the cold-start hole fully). Con: adds friction at the exact moment churn is highest; the user has no context yet. *Viable if kept to one optional screen right after key validation.*
- **Alternative B — pure progressive (ask nothing; let reflection learn).** Pro: zero friction, on-brand. Con: leaves the cold-start hole wide open — walk #1 is unbiased, which is the worst walk to lose. This is today's behavior and stays the **skip-path fallback** (Q5).

## Q2 — What do we ask? *(sac owns the ask/flow; dam owns starter-pack mechanics)*

**Recommendation: template starter pack (confirmed, not silent) + free-form "words we'll get wrong".** Two inputs:
1. **Trade/template selection** (`landscape | property | inspection` — canonical, CANON) picks a **starter pack** of ~10–20 common domain terms. These are shown as *suggestion chips the user confirms/deselects* — never silently written. (Memory-transparency principle: the user always sees what the agent knows.)
2. **Free-form terms** — crew names, supplier names, local place names, product/material jargon. This is where the highest-value, un-guessable terms live (a starter pack can't know "Hollis" or "Boxwood Lane").

- **Starter-pack curation & storage (dam):** curated by damsac, bundled as a **static Rust constant / `const` table keyed by template** in `murmur-core` (or a bundled JSON if sac prefers to iterate copy without a Rust rebuild — *joint call*). Not server-fetched (privacy: nothing but LLM calls leaves the device). Recommend Rust constant — it's ~50 short strings, versioned with the binary, testable.
- **Cap accounting (dam):** starter-pack terms are **suggestions the user confirms**, so they only count against the 100-cap *after* confirmation, through the normal `add_vocabulary_term` funnel (which already dedups + caps). No silent fills.
- **Import (contacts / previous notes):** **out of scope** (non-goal: contact-sync engineering). Named so it isn't assumed.
- **Alternative:** template-only (no free-form). Rejected — loses the un-guessable proper nouns that matter most.

## Q3 — How do answers become vocabulary? *(dam owns the path; sac owns input modality)*

**Recommendation: reuse the existing Plan 10 funnel verbatim; type-first input for the interview, with a voice-capture option.** Every confirmed term (starter-pack or free-form) is written through `add_vocabulary_term(term, now, FactSource::Stated)` — the *same* path the editor uses. No new write path, no bypass of normalize/dedup/cap/word-guard. Seeded terms are `Stated` (user asserted them), so they sit above any `Inferred` auto-harvested term under cap pressure (Plan 10 D3 floor).

- **The chicken-and-egg, confronted head-on (joint):** a voice-first app whose first act is *typing* is off-brand — but STT *without* vocabulary is exactly when dictation is worst, so voice-dictating unknown crew names would mis-transcribe the very terms we're trying to seed. **Resolution:** the interview is **type-first** (short, high-stakes, must be exact — the one place typing is correct), with an **optional "say it" affordance** that dictates into the field *and shows the transcript for correction before commit*. Typing a handful of proper nouns once is acceptable; the brand promise is that they never type *during a walk*, not never at all.
- **Alternative — voice-first interview.** Pro: on-brand. Con: unbiased STT mangles exactly the terms being seeded; correction loop is more friction than typing 5 words. Rejected for v1; revisit once biasing is stronger.

## Q4 — Reflection interplay & headroom *(dam)*

**Recommendation: seed conservatively to leave reflection headroom — cap seeding at ~60 of the 100 terms.** Reflection (Plan 02/10) keeps enriching the section from real walks; seeding only sets the prior. If seeding fills all 100 slots, `add_vocabulary_term` returns `Full` and reflection-learned terms can't land (writes reject; nothing silent-evicts — Plan 10 D4). Reserving ~40 slots lets the loop keep learning without immediately hitting the wall.

- **Mechanism:** a soft seeding budget (`SEED_MAX ≈ 60`) enforced *in the onboarding flow*, not in `Memory` (the 100-cap stays the single hard invariant; don't fork it). The flow stops offering suggestions past the budget and tells the user "add more anytime in Vocabulary."
- **Churn/eviction reality (surfaced, not hidden):** seeded terms are `Stated`, so they're evicted *after* all `Inferred` terms but are **not immune** to `clamp_to_cap` or to reflection dropping them from a `write_memory` rewrite (Plan 10 D3 honest-limits). Seeding does **not** change eviction semantics. The Plan 10 D3 open question (protected/`Pinned` tier) is the escalation if device testing shows seeded terms eroding — *deferred, measured first*.
- **Alternative — fill to 100.** Rejected: starves the learning loop and hits `Full` on the first reflection add.

## Q5 — Skip path *(joint — dam: behavior, sac: affordance)*

**Recommendation: everything skippable, everything revisitable, skip = today's behavior exactly.** A "Skip" / "Not now" on every onboarding vocabulary screen. Skipping writes **nothing** — the section stays empty and cold-start behavior is precisely today's (empty `vocabulary` → `build_bias_prompt` returns `None` → whisper runs with no `initial_prompt`, exactly as now). The `VocabularyView` editor already exists (Plan 10 / sac's #176 pass) as the revisit surface, reachable from the `VOCAB` chip on the board. No new persistence for "onboarding done" beyond a single boolean flag so we don't re-prompt.

- **Non-negotiable:** seeding is an *enhancement*, never a *dependency* — mirrors the live-extraction R-series principle. A user who skips forever gets a fully-working app that learns vocabulary via reflection alone.

## Q6 — How do we know it worked? *(dam)*

**Recommendation: before/after term-recall on the synthetic corpus, reusing the spike/eval methodology.** The spike already measured +10–19 pp term recall from `initial_prompt` biasing (`spikes/stt-whisper` harness, `say`-generated WAVs, WER/recall diff with vs. without vocabulary). Seeding's value is *the same lift, but present on walk #1 instead of walk N*. Two cheap measurements:
1. **Offline (CI-adjacent, dam):** take the `crates/evals` synthetic site-walk corpus, generate audio containing the corpus's proper nouns, and diff term recall for `seeded` vs `empty` vocabulary through the existing spike harness. This is the same before/after the spike ran — reframed as "seeded prior vs cold start." Device/model-gated, not a hermetic CI gate (whisper feature).
2. **Product A/B (later):** cohort with vs. without the onboarding prompt; measure first-walk term-recall and week-1 correction rate. Deferred until real users — named, not built.

- **Alternative — trust the spike, measure nothing new.** Rejected: seeding adds friction, so it must pay for itself; the offline before/after is nearly free (harness exists).

---

## Proposed flow — the ~30-second happy path *(sac owns visuals; screens are illustrative)*

Entry: user has just validated their API key (spec §8) and is creating their first job, OR just finished walk #1.

1. **Prompt (1 tap or skip).** A card on the board / a sheet: *"Teach the mic the words your crews say — 30 seconds. It hears them better."* Buttons: **Add words** · **Not now**. ("Not now" = Q5 skip, writes nothing.)
2. **Template → starter pack (~10s).** If the job already has a template, skip the picker; else pick `Landscape / Property / Inspection`. Show ~12 suggestion chips (bundled per-template pack). User taps to *deselect* any that don't apply; default is all-on but nothing is written until step 4. Counter: `SUGGESTED 12 · TERMS 0/100`.
3. **Free-form (~15s).** The `VocabularyView` add-bar (already built): *"boxwood, zone 2, Hollis…"* — type or tap the mic to dictate-with-preview (Q3). Each commit goes through `add_vocabulary_term` (dedup/cap/word-guard enforced). Crew names, supplier, local place names.
4. **Confirm & done (~5s).** **Done** writes all confirmed terms via the funnel (≤ `SEED_MAX≈60`); the board's `VOCAB` chip now shows the count. First walk starts warm.

Total keystrokes: a handful of proper nouns + taps. Nothing blocks recording — **Record is always reachable**; the prompt is dismissible at every step.

---

## Open questions

| # | Question | Owner |
|---|----------|-------|
| 1 | Trigger point: first-run step vs. first-job-creation vs. first-walk-end. Recommendation is first-job; needs sac's flow call + dam's `AppModel.Phase`/sheet plumbing. | joint |
| 2 | Starter-pack storage: Rust `const` table in murmur-core (versioned, testable) vs. bundled JSON (sac iterates copy without a Rust rebuild). | joint |
| 3 | Who curates the per-template starter packs, and how big (recommend 10–20 terms/template)? | joint (content: sac + trade knowledge; mechanism: dam) |
| 4 | `SEED_MAX` headroom value (recommend ~60/100) — enforced in the flow, not in `Memory`. Confirm the 100-cap stays the single hard invariant. | dam |
| 5 | Voice-capture-with-preview in the interview: worth building for v1, or type-only first? | sac (UX) + dam (dictation seam) |
| 6 | Protected/`Pinned` tier for seeded terms if reflection/cap-pressure erodes them (Plan 10 D3 escalation) — ship `Stated` + measure first. | dam |
| 7 | Onboarding-done persistence: a single boolean flag — where does it live (AppModel/UserDefaults vs. core)? | joint |
| 8 | Measurement: is the offline before/after on the evals corpus worth wiring as a standing spike, or run once? | dam |

## Explicitly out of scope

- **Contact-sync / previous-notes import** engineering (a term *source*, but the import plumbing is a separate product surface).
- **Server anything** — starter packs are bundled on-device; privacy invariant (only LLM calls leave the device) holds.
- **Redesigning the vocabulary editor** — `VocabularyView` (Plan 10 / sac #176) is the revisit + free-form surface, reused as-is.
- **Auto-harvest** of proper nouns from live extraction (Plan 10 D9 seam — `Inferred` source is ready; detection not built).
- **A new write path** — seeding *only* calls the existing `add_vocabulary_term` funnel.
- **The BYOK/key onboarding step** (spec §8) — a sibling onboarding surface, not this doc.
- **Changing eviction/reflection semantics** — seeding sets a prior; it does not alter `clamp_to_cap`, `prune_stale`, or the reflection rewrite.
