# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Recording UI** — minimal wave line with real audio input
- **LLM-curated daily focus** — compose_focus tool, DailyFocusStore, shimmer loading state wired in
- **Category consolidation** — removed `thought` category (8 → 7), existing data falls back to `.note`

## Recent decisions

- Removed `thought` category — no distinct behavior, no future behavior path. Existing `"thought"` values in DB silently degrade to `.note` via defensive initializer.
- 7 categories remain: todo, reminder, habit, idea, list, note, question. Each has (or will have) distinct agent behavior.
- Daily focus: LLM generates both the entry selection and the briefing message via `compose_focus` tool
- Recording UI direction: minimal audio-reactive wave line
- Agent backend systems merged (PR #66)
- Sac's PRs merged: home visual polish (#65), onboarding redesign (#67)

## Open questions

- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Daily focus refresh frequency: on app open only, or periodic?

## What I need from sac

- Continue iterating on focus section UI — dam has wired LLM curation behind it
- Coordinate on remaining conversation UI PR
