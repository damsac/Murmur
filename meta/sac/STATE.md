# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Launch screen polish: eliminated the visible seam/box around the launch icon.

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
- **Archive + All-entries search** — Both views now have a search bar that filters by summary. Archive: grouped sections when idle, flat list when searching. All entries: same pattern, hides processing dots while searching.
- **Shorter notification bubble labels** — Dropped "before" suffix from lead time options (e.g. "15m before" → "15 min") since direction is implicit. Fixes squishing on small phones.
- **Smart toast duration** — Duration scales with message length: `max(2.5, min(6.0, chars / 12.0))`. Short confirmations ("Completed") disappear quickly; long LLM responses stay readable.
- **List category color: teal → blue** — Minor color tweak for better visual distinction.
- **Launch screen seam fix** — PNG has no alpha (navy background baked in), so color matching was imperfect. Fixed by pinning imageView to all 4 edges (full screen) with `scaleAspectFit` + setting screen background to the exact PNG corner pixel color (#060912). No seam because the imageView IS the background; letterbox areas above/below the icon match the PNG border color.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on SacHomeView?

## What I need from dam

- Confirm API key plan for TestFlight archive build — document or add a Makefile target.
- Real token counts from PPQ responses — MurmurCore side, needed before credits display is trustworthy.
- Review the TestFlight checklist and adjust any dam-owned items or priorities.
