# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Notification system overhaul: per-type preferences, due date extraction fix, and full system audit.

## Recent decisions

- **Per-type notification preferences** — Split old single-toggle into four rows: Reminders (minute-scale lead time), Due Soon / todos (hour/day lead time), Habits (morning/midday/evening daily ping), Snooze (no config, just on/off). Each type has independent enable + timing in Settings.
- **Habit reminder restore on launch** — Repeating `UNCalendarNotificationTrigger` survives relaunches but is wiped on reinstall (TestFlight). Added restore call in `MurmurApp.swift` on every launch.
- **Due date extraction: ISO 8601 instead of verbatim phrase** — `NSDataDetector` can't resolve relative time phrases ("30 min from now"). Changed LLM prompt (both `entryCreation` and `entryManager`) to output ISO 8601 datetime strings computed against the current time already in context. `Entry.resolveDate` tries ISO 8601 first, falls back to NSDataDetector for legacy entries.
- **LLM now always sets due_date for reminders/todos** — Changed "Optional: due_date (verbatim phrase)" to an explicit instruction: always set it when the user mentions a time reference.
- **Snooze notification defaults to ON** — `snoozeWakeUpEnabled` was defaulting to OFF, making snooze effectively silent. Changed to ON; snooze implies wanting a reminder.
- **Summary edit re-syncs notification** — EntryDetailView summary onChange now calls `sync()` so the pending notification title stays current.
- **Notification tip in onboarding result view** — Purple-tinted card pointing to Settings → Notifications after habits strip.
- **Dropped swipe-to-switch-tabs** — `TabView(.page)` fires simultaneously with card swipe actions. Replaced with HStack pager (tap-only). Applied to both home variants.
- **Section headers: dot + colored text + hairline** — Replaced pill/bubble with dot + category-colored label + tinted hairline.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on SacHomeView?

## What I need from dam

- **Launch screen icon is wrong** — `LaunchIcon.imageset` files need to be replaced with the correct app icon. You have the source file. Storyboard shows it at 200×200pt with `scaleAspectFit` on a dark background. After updating, delete `Library/SplashBoard` on simulator and clean build.
- Confirm API key plan for TestFlight archive build — document or add a Makefile target.
- Real token counts from PPQ responses — MurmurCore side, needed before credits display is trustworthy.
- Review the TestFlight checklist and adjust any dam-owned items or priorities.
