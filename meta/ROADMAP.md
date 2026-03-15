# Roadmap

Shared priorities and sequencing. Who's doing what, what's next, what's blocked.

Updated when priorities shift. Either person can propose changes via PR.

---

## Active

| Work | Owner | Status | Branch |
|------|-------|--------|--------|
| TestFlight prep (checklist items 3, 6, 13–20) | dam + sac | In progress | dam |
| Empty state fix (SacHomeView FocusTabView) | sac | Not started | — |
| Wire error views (MicDenied, OutOfCredits, APIError) | sac + dam | Not started | — |

## Up Next

- User-facing home view toggle (Settings: Scanner/Navigator/Zoned) — layout diff Phase 4
- VoiceOver accessibility + `accessibilityReduceMotion` broadly
- Search (entries become unfindable at scale)
- LLM cost visibility tool (usage log + Settings UI)
- Conversation lifecycle: reset mechanism, context indicator

## Open Questions

These need resolution. Either person can claim one and propose an answer via PR.

- Token budget: how many active entries before truncating context?
- Conversation lifecycle: when does multi-turn reset? Timer, explicit button, or N seconds of silence?
- Undo stacking: independent undo for rapid actions?
- Home view default: which variant ships to testers? (Currently DevMode-only toggle)

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
| Focus strip + category sections | 2026-02-26 | PR #59 |
| Resilient action parsing + multi-turn wiring | 2026-03-01 | PR #83 |
| Unified home composition (delete DailyFocus, variant system) | 2026-03-04 | PR #93 |
| Layout diff system (Phases 1–3) | 2026-03-04 | `30aebc6..ab40bf0` |
| Three-zone focus screen + keyboard UX fixes | 2026-03-05 | PR #94 |
| Card redesign (borderless rows, flow chips) | 2026-03-05 | `455f2d5` |
| Launch screen | 2026-03-05 | `379f927` |
| Reactive wave visualizer + processing glow | 2026-03-06 | `b9bb343` |
| Color palette tightening | 2026-03-06 | `8871103` |
| Inline editing in entry detail | 2026-03-06 | `f2658d8` |
| Calendar view + habits by cadence | 2026-03-07 | PR #97 |
| Tab swipe (TabView page style for zones) | 2026-03-07 | `1931934`, `23b46a5` |
| Real token usage for credits + switch to Haiku | 2026-03-14 | `e8a4a46` |
| Simplify categories (remove `thought`, down to 7) | 2026-03-01 | various |
