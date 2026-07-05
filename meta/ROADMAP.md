# Roadmap

Shared priorities and sequencing. Who's doing what, what's next, what's blocked.

Updated when priorities shift. Either person can propose changes via PR.

---

## Active

| Work | Owner | Status |
|------|-------|--------|
| Plan 08 Part C — noise robustness (Voice-Isolation A/B knob, VAD/no_speech gate, SNR sweep) | dam | next build run (Tasks 10–12; Parts A+B merged 2026-07-05) |
| Real-mic device voice walk (`live=1` on iPhone) + T5 spike tier (device RTF/battery) | dam | the milestone gate + the one unretired STT GO condition |
| Issue #155 — PR #1 review follow-ups (4 state bugs + seam hygiene) | sac | open (several now also guarded core-side by 07-carry) |
| Rebuild-era nix-based CI (cargo test needs nix deps — naive runner job goes red) | dam | follow-up from #157 |

## Up Next (sequenced)

1. **Plan 08 Part C** — noise robustness (see Active).
2. **Rebuild-era TestFlight pipeline** — release.yml is Era-I, manual-only; a real apps/ios pipeline is required before the next external build.
3. **Accuracy hardening**: word-level timestamps (whisper token_timestamps) fix the coarse-seam fallback; live-prompt pins in evals advance with the Plan 06a contract.
4. **Prompt-optimization loop** on the 05b eval suite (rank on F0.5, gate on recall).
5. **Photo attachment schema** (rides a migration after `source`).

## Done 2026-07-05 (the big day)

Re-unification complete (repo = **damsac/sitewalk**, one history, Swift Era I preserved; archive = sitewalk-archive) · issue/PR slate cleaned (19+2 Swift-era closed; #155/#156 remain) · CLAUDE.md + CI rewritten for the rebuild (#157) · **first real walk** (EST-0047, real core + key on sim) · **Plan 08 Parts A+B merged**: mic→whisper→append wiring, cancel() (closes #156's core half), transcript events, use_gpu knob (sim=CPU — D7's "Metal degrades on sim" was falsified: it SIGTRAPs), voice-walk-from-WAV proven end-to-end on sim (whisper decoded the fixture; transcript verified in SQLite). 290 tests.

## Decisions needed (joint)

- Template keys: adopt `landscape | property | inspection` as canonical? (dam: yes — needs sac's ack)
- STT DONE semantics: flush final utterance vs speed
- Fate of the Gallery/Screens static twins after design freeze

## Completed (rebuild era)

| Work | Date | Where |
|------|------|-------|
| Vision spec (4 revs) + UI mocks + user stories | 2026-07-01 | `damsac/Murmur` `pr/dam/rebuild-vision` |
| Plan 01 — harness foundation (agent loop, tools, providers) | 2026-07-01 | this repo, 14 commits |
| Plan 02 — memory/reflection/context (provenance, snapshots) | 2026-07-02 | this repo, 15 commits |
| Plan 03 — domain + SQLite store (tombstones, sync-ready) | 2026-07-02 | this repo, 14 commits |
| Plan 04 — processing pipeline + reflection coordinator + R9 cost log | 2026-07-03 | this repo, 16 commits |
| Plan 05 — live in-session extraction | 2026-07-03/04 | this repo, 6 commits |
| Plan 05b — eval suite (corpus + deterministic grader + runners) | 2026-07-04 | this repo, 8 commits |
| Memory frontier research / STT frontier research | 2026-07-02/04 | `damsac/Murmur` `docs/research/` |
| Repo → damsac org, public | 2026-07-04 | github.com/damsac/sitewalk |
| iOS app: design system + full flow behind WalkEngine seam | 2026-07-04 | PR #1 (sac), merged |
