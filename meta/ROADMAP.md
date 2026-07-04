# Roadmap

Shared priorities and sequencing. Who's doing what, what's next, what's blocked.

Updated when priorities shift. Either person can propose changes via PR.

---

## Active

| Work | Owner | Status |
|------|-------|--------|
| Issue #2 — PR #1 review follow-ups (4 state bugs + seam hygiene) | sac | open |
| 06-spike — whisper-rs STT benchmark (GO/KILL) | dam | plan ready (`damsac/Murmur` → `docs/superpowers/plans/2026-07-04-rust-core-06-spike-stt-benchmark.md`); needs an executor |
| Harness patches: PPQ Bearer auth + `ANTHROPIC_BASE_URL` | sac | on sac's machine, needs a PR |

## Up Next (sequenced)

1. **Plan 06 — STT** (dam; blocked on spike verdict). Also carries: items `source` column migration, swap-contract fix (clear live items only after successful process), template-keys alignment.
2. **Plan 07 — layout protocol + FFI** (dam builds bridge, sac consumes). Replaces `DemoWalkEngine` behind `AppModel.init(engine:)`. FFI boundary at domain types; never hold the Store lock across `maybe_extract`.
3. **Prompt-optimization loop** on the 05b eval suite (rank on F0.5, gate on recall).
4. **Photo attachment schema** (rides a migration after `source`).
5. **Docs migration**: specs/plans/research from `damsac/Murmur` `pr/dam/rebuild-vision` into this repo.

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
