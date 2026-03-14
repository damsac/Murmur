# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Calendar button + horizontal tab swiping in home views (Navigator + Zones).

## Recent decisions

- **TestFlight checklist in `meta/`** — Wrote a structured doc covering 14 items across blocker/high-priority/nice-to-have. Assigned ownership per item (sac vs dam vs both). Easier to track than a GitHub issue and lives next to STATE.md.
- **Calendar view in `CalendarView.swift`** — Monthly calendar, entries grouped by due date, opens from home top bar. Additive to existing tabs.
- **Inline editing in EntryDetailView** — Replaced the separate `EntryEditSheet` with in-place editing directly on the detail view. Simpler UX, less navigation overhead.
- **TabView page style for swipe** — Swipe between Focus and All tabs using `TabView(.page)`. Fixed `SwipeableCard` drag conflict by using `minimumDistance: .infinity` when no swipe actions present.
- **Calendar button in ZonedFocusHomeView** — Added calendar icon (top-left) to `ZonedFocusHomeView`. Wired to `showCalendar` sheet in RootView. Matches the gear icon style (17pt medium, textSecondary, 44pt hit area).
- **Horizontal swipe in ZonedFocusHomeView** — Added `simultaneousGesture(DragGesture)` to the tab ZStack. Threshold: 50pt horizontal, 1.5× horizontal > vertical (to not conflict with vertical scrolling). Uses existing `appState.selectedTab` + existing slide transitions.

## Open questions

- Tab swipe needs real-device verification — UIPageViewController behavior differs from simulator (blocker #2 on checklist).
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build (blocker #3).
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we move forward with two-tab navigator?

## What I need from dam

- Confirm API key plan for TestFlight archive build (checklist #3) — document or add a Makefile target.
- Real token counts from PPQ responses (checklist #4) — MurmurCore side, needed before credits display is trustworthy.
- Review the TestFlight checklist and adjust any dam-owned items or estimated priorities.
