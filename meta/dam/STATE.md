# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

**The rebuild — this repo.** Murmur pivoted 2026-07-01 to AI meeting notes for blue-collar field work (GC site walks, inspections). Branded **Sitewalk** 2026-07-06, then **superseded 2026-07-12: the product is now Jefe** (Isaac's pick off the #188 shortlist, dam co-signed in CANON via #202) — hard-hat icon + amber theme shipped in #200. Rust core + native shells, built here in `damsac/sitewalk` (repo name unchanged, redirects cover it). Specs, plans, research, and mocks all live HERE now (`docs/`); `damsac/Murmur` is archive-only.

dam owns: harness / murmur-core / STT / FFI. sac owns: renderers / component library / visual direction (`apps/ios/`).

## Where the core is (main @ 17d6b24, clippy clean, CI-gated)

| Plan | What | Status |
|------|------|--------|
| 01 | `crates/harness` — agent loop, tools, Anthropic provider, mock provider | done |
| 02 | memory + reflection + context assembler (provenance, snapshots, forgetting) | done |
| 03 | `crates/murmur-core` — SQLite store, jobs/sessions/items/contacts, tombstones, sync-ready | done |
| 04 | processing pipeline (two-phase extract+summary), reflection coordinator, R9 cost log | done |
| 05 | live in-session extraction (`LiveExtractor`) — incremental passes onto the live board | done |
| 05b | `crates/evals` — synthetic site-walk corpus + deterministic grader (F0.5, R6-weighted) | done |
| 06-spike | STT benchmark — verdict **GO** (RTF ≪0.5 all models, +10-19pp biasing lift, append-only proven) | done; iPhone T5 tier pending (dam, ~1hr) |
| 06a | items `source` column + atomic swap-at-finish; failed process PRESERVES live board | done |
| 06 | `crates/stt` — whisper-rs feature-gated, chunked streaming, time-anchored dedup finalizer, initial_prompt biasing | done |
| 07 | `crates/ffi` (UniFFI) + `MurmurEngine.swift` — **the bridge is LIVE**: app builds with the real core linked | done |
| 07-carry | all 6 carry notes + 3 cross-model findings: fallible constructors, atomic begin_walk, mint-with-artifact-write, throwing WalkEngine.begin (dead walk never starts), tick fault counter, narrowed artifact sweep | done (merged be88bca) |
| first walk | **THE MILESTONE LANDED 2026-07-05**: real core + .env key on sim → document EST-0047 end-to-end. Clean checkout builds demo with zero setup; `generate.sh` opts into real | done (merged baa8848) |
| 08 A+B | STT stage-2 wiring: push_audio → pump thread → append path; TranscriptCommitted/Preview events; finish() flush + async cancel() (Store::delete_session — closes the #156 core half); AudioCaptureSource (mic→16kHz) + WavFileAudioSource; use_gpu knob (sim=CPU compile-time — D7 "Metal degrades on sim" FALSIFIED: SIGTRAP; device=Metal) | **done, merged 2026-07-05** — 290 tests; voice-from-WAV proven end-to-end on sim |
| 08 Part C | noise robustness: voiceproc A/B knob, dual R3 gates (complementary, proven), SNR sweep: base.en bundled | done, merged 2026-07-05 |
| 09 | word-level whisper timestamps → mode-aware finalizer seam (`time_precise`: precise drops by start, coarse keeps end) — resolves the Plan 06 coarse-seam CAVEAT; eval live-prompt golden pins | **done, merged 2026-07-05** (#162/#163) |
| 10 | vocabulary loop write half: editor → FFI CRUD → Memory vocab surface (normalize funnel, caps 100/6 at write) → whisper bias. **The differentiator is live e2e** | **done, merged 2026-07-05** (#164/#165) — 322 tests |
| infra | CI live (#160: nix Rust gates + iOS demo, every PR), threshold knobs launch-arg tunable (#161), **TestFlight rebuild pipeline built** (branch `pr/dam/testflight-rebuild`, UNMERGED on purpose — merging arms auto-publish on every main push; dry-run blocked on the Apple agreement signature) | 2026-07-05 |
| 11 | photo attachments: `photos` table (migration v5, transactional, append-only); **demote-on-swap (D3)** — item tombstone (live→authoritative swap, `delete_item`) demotes photos to session-level rather than orphaning or losing them, at 4 tombstone sites; session tombstone cascades and tombstones photos outright; FFI CRUD (`add_photo`/`list_photos`/`remove_photo`/`list_live_photo_filenames`, `EngineError::Photo`); iOS capture (PhotosPicker) + gallery wired through `WalkEngine`, visuals staged behind `// sac:` handoff markers | **done, merged (#172)** |
| 11 fast-follow | `photo_count` on the live board snapshot: batched per-snapshot counts (one query per tick, not per-item), stale-until-next-tick posture accepted rather than chased — `BoardItem.photo_count` is live, no longer pinned at 0 | **done, merged (#174)** |
| model infra | `fetch-whisper-model.sh`: sha256-verified download of the bundled ggml model; `small.en` promoted to default (spike RESULTS.md: strictly better WER/hallucination than base.en at every measured SNR); one-arg revert kept live (`STT_MODEL=base.en` / `sttmodel=base.en` launch arg) pending the iPhone T5 on-device RTF proof | **done, merged (#175)** |
| 11 fix | photo capture moved off the main actor (PR #176 should-fix) — `WalkEngine.attachPhoto` is now async, hopping the FFI call onto `Task.detached` so it doesn't contend with the Rust pump thread's store lock on the main thread; captures chain onto `AppModel.photoCaptureChain` so rapid taps stay ordered and append in tap order | **done, merged (#178)** |
| 12 | document-row item identity, echo-and-validate — forced `build_document` call is fed this run's authoritative items, the model echoes matching `item_id` onto each line, `BuildDocumentTool` validates every echo against the run's `created_ids` Arc and degrades unknown/hallucinated/cross-session/already-claimed ids to `None` (first-wins dedup, no branch fails the build); dangle invariant earned by construction (same Arc feeds the finish-time tombstone sweep, Plan 11 D3); no SQLite migration (JSON body field); FFI `DocLine.item_id` additive; iOS `DocRowFixture.itemId` + functional client-side photo/row join in `ReviewView`, **grouping visuals sac's** (`// sac:` markers) | **done, merged (#179)** — unblocks sac's per-item photo grouping |
| infra | CI: third job fails the build on stale committed UniFFI Swift bindings — regenerates `ffi.swift` from a hermetic host build of `crates/ffi` (release, no whisper feature, no macOS runner needed) and diffs against the committed copy; added because the bindings went stale twice (#176 late-regen, #179 caught only at final review) | **done, merged (#180)** |
| discussion | onboarding vocabulary-seeding design doc — draft only, not implementation; wants dam+sac reactions, top 3 open questions (2 joint) | **draft, merged as discussion (#181)** |
| 08 fix | iOS: `resolveLive()` defaults icon-tap launches to live mic on physical devices (sim still defaults to scripted — Metal STT SIGTRAPs on `MTLSimDevice`, and screenshot/QA automation is built around scripted); explicit `live=1`/`live=0` launch args always win on either platform | **done, merged (#182)** |
| 184 | TestFlight pipeline reconciled and merged/ARMED — dry-run (workflow_dispatch, upload=false) green on run 28900094459; push-to-main now means internal auto-publish, a `v*` tag means an external candidate | **done, merged (#184)** — **first publish SUCCESS: build #18, 2026-07-08, rebuild live on internal TestFlight** (demo engine — no key baked, standing decision) |
| 185 | zombie-Recording sweep — crash-orphaned `Recording` sessions flip to `Failed` on app open; the race is closed by a pinned ordering invariant; the todo-leak (orphaned partial work not recovered, just failed-out) persists deliberately, pending a future recover UI | **done, merged (#185)** — published as build #19 |
| 13 | **notes-first core, two stages** (CANON 2026-07-10: notes, not an auto-built document, is the walk's primary output). **Stage 1 (#197)**: additive `build_document(kind)` on-demand path — `MurmurEngine.swift` untouched, old `finish()` still auto-builds, a merge behaves identically to before. Final review caught the **N3 blocker**: the plan's approved condition (`doc_kind_for_template` → `doc_kinds_for_template(t)[0]`, property → `"condition"`) would have changed *live* behavior through the still-shared function — deferred to Stage 2 rather than shipped inert-but-wrong. **Stage 2 (#198)**: the atomic flip — `finish()` now returns `NotesPayload` (no auto document build), every `docKind` Swift `switch` arm gets coupled in the same PR so no build ships with a dangling case. | **done, merged** (#197 Stage 1, #198 Stage 2) |
| 14 | **comprehensive notes** — Isaac's coordination-artifact ask (sac's #199 thread): `write_summary` grown into `write_notes`, one forced call now returns narrative summary + `notes[]` across a **four-bucket contract** (`scope_of_work` / `constraints` / `conditions_and_issues`, unknown bucket strings dropped at the FFI boundary, not coerced — R6); persisted as a `kind="notes"` artifact. Depth came from growing the existing summarize pass (option b) rather than a new LLM call (R9) or loading detail onto the latency-sensitive live-extraction pass. Evals invariance is a gated fact, not a hope: `cargo test -p evals` is **Δ=0** against pre-14 (grader never reads artifacts). | **done, merged (#203)** |
| infra | **TestFlight-honesty saga, builds #24–#34** — five silently-rejected publishes (Apple's "missing 120x120 icon" was never surfacing because the upload step's exit-code check was too loose) fixed across a chain: app icon (Walked Wave glyph, #194) + the loose-grep false-green fixed to match failure signatures only — a bare `error` grep had red-flagged build #24's *successful* upload (#195); export-compliance key + STT default reverted to base.en (#196); version bumped to 2.0.0; then the real bug — every TF walk (demo included) 401'd because the shipped key is Anthropic-direct, not PPQ-issued, and #193 had wired a `ppq.ai` base-URL override on the wrong assumption; **root-cause fixed by removing the override (#205)** — build #33 is the first TF build where real walks actually work. #206 closes the loop: `Failed` sessions (including the ones stranded by #24-32's dead key) now retry on next app-open, capped at 5 oldest-first, and zombie-Recording recovery falls out of the ordering for free. | **done, merged** (#194, #195, #196, #205, #206) |
| brand | **Jefe** — Isaac's pick off the #188 rename shortlist (sac's research: "Sitewalk" collides with ≥7 products incl. a direct competitor); sac shipped the hard-hat icon + amber theme (#200), dam co-signed in CANON (#202), superseding the 2026-07-06 Sitewalk brand decision. Repo name (`damsac/sitewalk`) stays as-is; ASC/TestFlight listing rename is a standing follow-up. | **done, merged** (#200, #202) |

## Where we are (2026-07-13)

**Main is at 17d6b24.** TestFlight builds are **working in the field** — dam confirmed real walks completing end-to-end on build #34 (2026-07-13), after the #205 key/host root-cause fix and #206's retry-on-app-open closed the loop on everything stranded by builds #24-32's dead key. Notes-first (Plan 13) and comprehensive notes (Plan 14) are both merged; the core side of the notes-first pivot is done.

Four of sac's PRs are open and form the next review queue: **#204** (render Plan 14's comprehensive-notes buckets on the notes screen — completes the loop Plan 14 opened), **#207** (design: customizable paperwork — style/structure/upload), **#208** (back-arrow from review to notes), **#209** (Letterhead Studio — branded exported paperwork, Style v1).

**Device build state**: unchanged from prior freshen — xcframework + model cached locally; device session backlog (voiceproc A/B sweep, Plan 09 Task 7 rerun, small.en RTF validation) still pending a dedicated device session.

## What sac should know

- **The retry fix (#206) recovers `Failed` walks on app-open** — including anything stranded by the #24-32 dead-key window. Your app-open refresh hook is the trigger point; flagged here since it's the kind of thing that changes what a tester sees on next launch without any UI change on your side.
- **Your #204 completes the Plan 14 loop** — the core's four-bucket `notes[]` payload has been sitting inert behind your existing kind-grouped rendering since #203; #204 is the one that makes it visible. Review incoming from dam.
- **Jefe is CANON** — #202 is merged, your #200 branding is the co-signed brand. Nothing further needed from you there.
- **Builds #18 and #19 are on your TestFlight now** — #18 is the first-ever rebuild publish (demo engine, no key baked); #19 is the zombie-Recording sweep on top. Update and take a look.
- **Plan 12's seam is ready for your per-item photo grouping pass** — `ReviewView` has a functional client-side join (`model.photos` grouped by the row whose `itemId` matches, session-level catch-all for the rest); `DocRowFixture.itemId` mirrors it in the demo engine. Styling/visuals are yours, `// sac:` markers throughout.
- **Re-run `apps/ios/build-ffi.sh` after your next pull** — the FFI surface has moved several times since (Plan 13's `build_document(kind)`, Plan 14's `NotesPayload.notes`, #206's `retry_failed_sessions`); `check-bindings.sh` will flag drift.
- **PR #1 is merged** (main); review conditions carried as **issue #2** — four state-transition bugs + three seam-hygiene items.
- **STT is Rust-side — decided.** The spike GO'd whisper-rs (iOS 26's SpeechAnalyzer dropped custom vocabulary, and our biasing loop needs it). `crates/stt` is built; mic wiring (stage 2) is the next plan. Your `append(transcript:)` path works today.
- **finish() now returns `NotesPayload`** (Plan 13/14) — items + narrative summary + four-bucket `notes[]`; document build is a separate, explicit on-demand call per action button, not automatic at DONE.
- **`BoardItem.photo_count` is live** — counts are batched per-snapshot (one query per tick), so treat it as stale-until-next-tick, not real-time; that's an accepted posture, not a bug.

## What I need from sac

- Your two Plan 14 answers (subtitle truncation, taxonomy freeze) if they aren't already folded into #204.
- Formal review of the vision spec (`damsac/Murmur` → `pr/dam/rebuild-vision` → `docs/superpowers/specs/`) — still outstanding, carried forward.

## Standing items (dam)

- ASC listing rename — Sitewalk to **Jefe** — still pending in App Store Connect (dam/sac shared access).
- PPQ-vs-Anthropic-direct billing decision: TestFlight now bills **Anthropic directly** since #205's fix (the baked key was Anthropic-issued all along); needs a deliberate call on whether that's the intended long-term billing path or a PPQ re-route is still wanted.
- Factory 4 values + Isaac's 2 ASC clicks — carried forward, not yet done.
