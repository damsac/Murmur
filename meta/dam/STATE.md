# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Daily focus — UI bugs** — LLM-composed focus strip is wired end-to-end but has UI issues to fix next session
- **Results surface** — new `ResultsSurfaceView` replaces toast-based agent response display; confirmation flow added
- **Recording UI** — minimal wave line with real audio input

## What happened last session

- Implemented `compose_focus` tool + `DailyFocus` types in MurmurCore
- `PPQLLMService.composeDailyFocus()` — one-shot LLM call, separate conversation
- `DailyFocusStore` — JSON cache in Documents, load/save/clear
- `AppState.requestDailyFocus()` — cache check → credit gate → LLM → persist → deterministic fallback
- `FocusStripView` rewired to accept `DailyFocus` (LLM message + resolved entry IDs)
- `FocusCardView` takes `reason: String` from LLM instead of computing from entry fields
- `FocusShimmerView` — loading placeholder while LLM composes
- Dev mode: "Regenerate Daily Focus" button — clears cache + triggers fresh LLM call on dismiss
- Fixed pre-existing `.confirm` case exhaustiveness in ToastView, AgentActionExecutor
- `ResultsSurfaceView` + `ConfirmationData` + `DenialLogStore` added (prior session, untracked until now)

## Known UI bugs to fix

- Focus strip UI issues dam wants to address (unspecified — inspect in simulator)
- Mock focus IDs don't resolve to real entries (expected, but worth testing with real data)

## Recent decisions

- Daily focus fires once per app launch, cached for the day
- Deterministic fallback uses same overdue + P1/P2 rules as before
- Credit gating: authorize/charge wraps the briefing call for consistency
- `compose_focus` is a forced tool call (not auto) — always returns structured data

## Open questions

- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Confirmation flow UX: how should confirm/deny feel?

## What I need from sac

- Continue iterating on focus section UI — dam has wired LLM curation behind it
- Coordinate on remaining conversation UI PR
