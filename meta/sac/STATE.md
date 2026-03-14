# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Calendar habits in calendar view + native swipe for Zones.

## Recent decisions

- **TestFlight checklist in `meta/`** — Wrote a structured doc covering 14 items across blocker/high-priority/nice-to-have. Assigned ownership per item (sac vs dam vs both).
- **Calendar view in `CalendarView.swift`** — Monthly calendar, entries grouped by due date, opens from home top bar. Habits shown by cadence (daily/weekdays/weekly/monthly).
- **Inline editing in EntryDetailView** — Replaced the separate `EntryEditSheet` with in-place editing directly on the detail view.
- **TabView page style for swipe** — Both Navigator (SacHomeView) and Zones (ZonedFocusHomeView) now use `TabView(.page)` for native swipe physics.
- **Wave visualizer + processing glow** — Reactive amplitude-based waveform during recording, purple glow during LLM processing.
- **Calendar button in ZonedFocusHomeView** — Calendar icon top-left, wired to showCalendar sheet in RootView.

## Open questions

- Tab swipe needs real-device verification — UIPageViewController behavior differs from simulator (blocker #2 on checklist).
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build (blocker #3).
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we move forward with two-tab navigator?

## What I need from dam

- Confirm API key plan for TestFlight archive build (checklist #3) — document or add a Makefile target.
- Real token counts from PPQ responses (checklist #4) — MurmurCore side, needed before credits display is trustworthy.
- Review the TestFlight checklist and adjust any dam-owned items or estimated priorities.
