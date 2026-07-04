# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

**The rebuild — this repo.** Murmur pivoted 2026-07-01 to AI meeting notes for blue-collar field work (GC site walks, inspections). Rust core + native shells, built here in `damsac/sitewalk`. Specs, plans, and research are still in `damsac/Murmur` on `pr/dam/rebuild-vision` (docs migration here is pending).

dam owns: harness / murmur-core / STT / FFI. sac owns: renderers / component library / visual direction (`apps/ios/`).

## Where the core is (main, 214 tests, clippy clean)

| Plan | What | Status |
|------|------|--------|
| 01 | `crates/harness` — agent loop, tools, Anthropic provider, mock provider | done |
| 02 | memory + reflection + context assembler (provenance, snapshots, forgetting) | done |
| 03 | `crates/murmur-core` — SQLite store, jobs/sessions/items/contacts, tombstones, sync-ready | done |
| 04 | processing pipeline (two-phase extract+summary), reflection coordinator, R9 cost log | done |
| 05 | live in-session extraction (`LiveExtractor`) — incremental passes onto the live board | done |
| 05b | `crates/evals` — synthetic site-walk corpus + deterministic grader (F0.5, R6-weighted) | done |
| 06-spike | STT benchmark: whisper-rs feasibility/RTF/biasing, GO-KILL exit criteria | plan ready, not run |
| 06 | STT for real (+ items `source` column, swap-contract fix) | blocked on spike |
| 07 | layout protocol + FFI (UniFFI) — **where the `WalkEngine` bridge lands** | queued |

## What sac should know

- **PR #1 is merged** (main); review conditions carried as **issue #2** — four state-transition bugs + three seam-hygiene items.
- **STT may move Rust-side.** iOS 26's SpeechAnalyzer dropped custom-vocabulary biasing, which our vocabulary→STT loop needs. The 06-spike benchmark decides. The `WalkEngine` seam survives either way (`append(transcript:)` takes text).
- **HANDOFF answers**: events batched per live pass; core mints document numbers; photos need a schema migration (queued); template keys `landscape | property | inspection` proposed as canonical — needs your ack (CANON).
- **Bridge realities**: `finish()` = `end_and_record_session` + `process()` — two-phase, budgeted <8s; live items get tombstoned and re-extracted at process time (the board "swaps" — UI should anticipate); `LiveExtractor.maybe_extract` is `&mut self`, the FFI wrapper serializes it.

## What I need from sac

- Work through issue #2 (or push back per item — it's a conversation).
- The two harness patches on your machine (PPQ Bearer auth + `ANTHROPIC_BASE_URL`) as a proper PR with tests.
- Two CANON acks: template keys; STT DONE semantics (flush vs speed).
- Formal review of the vision spec (`damsac/Murmur` → `pr/dam/rebuild-vision` → `docs/superpowers/specs/`).

## Open questions

- STT engine: whisper-rs Rust-side vs staged hybrid — the 06-spike benchmark decides (dam's preference: Rust-side if the numbers hold).
- Who runs the 06-spike: builder agent or dam's hands.
