# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- Resilient action parsing: per-tool-call error isolation, defensive decoding, partial success UX
- Multi-turn conversation: wired in-memory conversation persistence (no disk, resets on app close)
- Agent pipeline review: full architecture trace from voice input to final result

## Recent decisions

- `cancelRecording()` over `stopRecording()` in agent path (speed over completeness)
- Per-tool-call error isolation over all-or-nothing (one bad tool call shouldn't nuke the batch)
- `EntryCategory` falls back to `.note` on unknown values instead of throwing
- `AgentEntryStatus` stays strict (wrong status transitions are worse than crashes)
- Priority clamped to 1-5 after decode
- Multi-turn is in-memory only — app termination resets conversation naturally
- Defined dam/sac roles: dam = architecture + backend + frontend contributions, sac = frontend + UI/UX

## Open questions

- How should conversation reset work beyond app termination? Timer? Explicit button? After N seconds of silence?
- When multi-turn is active, should tool results reflect actual execution outcomes instead of synthetic "accepted"?
- Category simplification (8 categories → fewer) — still unowned on the roadmap
- Token budget: how many entries in context before we need to truncate?

## What I need from sac

- Review and agree on CANON.md decisions (roles, branch model, cancelRecording tradeoff)
- Fill in `meta/sac/PROCESS.md` and `meta/sac/STATE.md`
- Feedback on focus strip PR (#59) — is it ready to merge?
