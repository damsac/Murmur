# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Shipped** — daily focus system, results surface, confirmation UI, focus strip polish, recording UI fix, thought category removal

## What happened last session

- Removed `.thought` category — no distinct behavior, falls back to `.note`
- Daily focus system end-to-end: `compose_focus` tool, `DailyFocusStore`, `AppState.requestDailyFocus()`, deterministic fallback
- `FocusStripView` rewired for LLM-curated focus: greeting + briefing message + staggered card entry
- `FocusShimmerView` — rippling shimmer placeholder while LLM composes
- `FocusContainerView` — stable-height container through loading → loaded transition
- `ResultsSurfaceView` + `ConfirmationData` + `DenialLogStore` — replaces toast-based agent responses
- Confirmation UI: tap-to-cycle actions, removed header clutter, fixed card backgrounds
- Dev mode: "Regenerate Daily Focus" button clears cache + triggers fresh LLM call
- Recording UI: removed waveform from mic button during processing, edge glow only

## Recent decisions

- `.thought` removed — category must drive different behavior to earn existence
- Daily focus fires once per app launch, cached for the day
- Deterministic fallback uses overdue + P1/P2 rules when LLM unavailable
- `compose_focus` is forced tool call — always returns structured data
- Focus strip uses staggered entry animation (message first, then cards one-by-one)
- Shimmer uses rippling glow pattern (not uniform pulse)
- Mic button: edge glow only during processing, no waveform overlay

## Open questions

- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Confirmation flow UX: how should confirm/deny feel in practice?

## What I need from sac

- Iterate on focus section UI — LLM curation is wired, visual polish welcome
- Review color remapping — `.thought` removed, colors redistributed
- Coordinate on remaining conversation UI
