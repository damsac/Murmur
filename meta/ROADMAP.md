# Roadmap

Shared priorities and sequencing. Who's doing what, what's next, what's blocked.

Updated when priorities shift. Either person can propose changes via PR.

---

## Active

| Work | Owner | Status | Branch |
|------|-------|--------|--------|
| Agentic entry management (UI simplification) | sac | In progress | — |
| Focus strip + category sections | sac | In review | PR #59 |
| Resilient action parsing + multi-turn wiring | dam | In review | PR pending |

## Up Next

- Simplify entry categories (currently 8: todo, idea, reminder, note, list, habit, question, thought — too many)
- VoiceOver accessibility custom actions

## Open Questions

These need resolution. Either person can claim one and propose an answer via PR.

- Metacraft skills: both use them, only dam, or create our own? (Custom skills probably later)
- Token budget: how many active entries before truncating context?
- Conversation lifecycle: when does multi-turn reset?
- Undo stacking: independent undo for rapid actions?

## Completed

| Work | Date | Commits |
|------|------|---------|
| Agent protocol + action types in MurmurCore | 2026-02-22 | `c27110d..d7c53cf` |
| Tool schemas (create, update, complete, archive entries) | 2026-02-22 | `c27110d..d7c53cf` |
| Smart list with flat sorting, daily brief | 2026-02-22 | `49cb1bc..e0936cf` |
| Gesture handlers (swipe right = complete, swipe left = snooze) | 2026-02-26 | `a2fc7e8..d2e2838` |
| Response toast with undo support | 2026-02-26 | `a2fc7e8` |
| Remove progressive disclosure system | 2026-02-22 | `f389a81..23125d9` |
| App icon redesign | 2026-02-22 | `6ddc930..c4b8337` |
