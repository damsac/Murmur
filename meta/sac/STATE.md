# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Three-zone focus screen (ZonedFocusHomeView) + keyboard UX fixes from parallel ux session.

## Recent decisions

- **Three-zone focus layout (sac2 variant)** — New `ZonedFocusHomeView` adds a third home screen variant: Hero zone (single highest-urgency item, tinted bg + accent stripe), Standard zone (urgency-sorted flat cards), Habits strip (compact checkable rows, today-only). Accessible via DevMode → Zones. Does not replace sac/dam variants — additive.
- **Urgency-first ordering** — Research showed urgency-first beats category-first for personal productivity dashboards. `urgencyScore()` client-side: overdue +100, P1 +60, P2 +40, due today +25. Categories are still visible via badge chips, not used for grouping.
- **Habits as a dedicated zone** — Pulled habits out of the urgency stack into their own strip. Habits compete differently than tasks — they're time-boxed rituals, not "work to finish." Showing them separately prevents a P1 todo from being buried by 3 habit items.
- **Keyboard button larger hit target** — Hit area bumped from 32×32 to 56×56pt with `contentShape(Rectangle())`. Was the UX pain point from the ux session — too easy to miss.
- **Removed dismiss chevron from text input** — The down-chevron before the text field was redundant (tapping mic already exits text mode) and cluttered the bar. Removed.
- **7-item cap on SacHomeView** — Added `maxFocusItems = 7` guard to `resolvedClusters()` in the existing navigator view. Previously uncapped.

## Open questions

- Is the three-zone layout the direction we want to pursue, or keep iterating on the two-tab navigator?
- Urgency scoring is client-side — should the LLM rank items for us instead (pass ordering hints in composition)?
- Weekly and monthly habits: `appliesToday` always returns true for these. Intentional?
- Individual card reveal tasks can't be cancelled mid-reveal. (Carried.)

## What I need from dam

- Review the LLM prompt bump (3 → 7) in `LLMService.swift` and `PPQLLMService.swift` — does the system prompt need other tuning to handle 7 items well?
- Feedback on three-zone layout direction — should this replace the two-tab navigator, or are we keeping both?
