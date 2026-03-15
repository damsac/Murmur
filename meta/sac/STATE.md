# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Gesture conflict fix: card swipe actions vs tab switching. Onboarding result view polish.

## Recent decisions

- **Dropped swipe-to-switch-tabs** — `TabView(.page)` gives UIPageViewController-backed swipe for free, but that gesture fires simultaneously with card swipe actions on device (non-deterministic callback ordering). No reliable SwiftUI fix exists without UIKit UIGestureRecognizer delegation. Replaced with HStack pager (tap-only via bottom nav bar, spring animation). Applied to both `SacHomeView` and `ZonedFocusHomeView`.
- **Root cause was in both home variants** — `homeVariant` AppStorage persists across sessions; if set to `"sac2"`, `ZonedFocusHomeView` was shown — which still had `TabView(.page)`. Fixed both.
- **Onboarding result view redesign** — Greeting + briefing header, hero card (todo), standard card (reminder), interactive habit row. Staggered entrance animation.
- **Sequential hints in RootView** — Replaced `showCardHints: Bool` with `hintStep: Int` for step-through hint system post-onboarding.
- **TestFlight checklist in `meta/`** — Wrote a structured doc covering 14 items across blocker/high-priority/nice-to-have.
- **Calendar view in `CalendarView.swift`** — Monthly calendar, entries grouped by due date, opens from home top bar.
- **Inline editing in EntryDetailView** — Replaced the separate `EntryEditSheet` with in-place editing.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable wrapping UIPageViewController + UITableView gesture delegation. High complexity, low priority for now.
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on SacHomeView?

## What I need from dam

- Confirm API key plan for TestFlight archive build — document or add a Makefile target.
- Real token counts from PPQ responses — MurmurCore side, needed before credits display is trustworthy.
- Review the TestFlight checklist and adjust any dam-owned items or priorities.
