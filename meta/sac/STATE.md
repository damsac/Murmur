# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Home screen visual polish — reduced noise, improved focus section UX.

## Recent decisions

- **Category badges text-free** — removed category name label (e.g. "TODO") from `CategoryBadge`, keeping only the colored dot + capsule. Less clutter, color alone carries the signal.
- **No red overdue dot in section headers** — removed the small red indicator dot next to category names when overdue items exist. Redundant given the focus strip.
- **Focus strip redesigned as vertical cards** — replaced horizontal chip scroll with up to 3 full `FocusCardView`s. Each card shows category badge, Overdue/P1/P2 reason badge, and summary text. Capped at 3.
- **Focus zone uses yellow not red** — yellow (`accentYellow`) feels softer and less alarming than red for the attention container. Background `opacity(0.05)`, border `opacity(0.18)`.
- **No colored card outlines anywhere** — removed `cardAccent` / `cardIntensity` from both `SmartListRow` and `EntryCard`. All cards use plain `.cardStyle()`. Urgency communicated via text badges, not border color.
- **Focus cards pulse** — staggered opacity animation (1.0 → 0.72, 2.4s easeInOut, delays 0s/0.6s/1.2s) draws the eye without being jarring.
- **Focus strip header** — two-line: bold `Greeting.current + "."` (title3.semibold) + softer "Focus on these things today." (body, textSecondary). Left-aligned — consistent with the rest of the UI.
- **No greeting popup** — tried a popup on app open but it didn't feel right. Removed. Greeting lives in the focus strip header instead.
- **Focus strip hidden when empty** — conditionally rendered; if no focus entries, the section doesn't appear at all.

## Open questions

- Should focus cards support swipe actions (complete/snooze) directly, or just tap-to-open?
- Is 3 the right cap for focus items, or should it adapt based on available screen space?

## What I need from dam

- Any thoughts on the focus strip UX overall — does the yellow zone + vertical cards feel right?
- The `Greeting.current` call is duplicated in `FocusStripView` — if you add a proper date/time context model, it should replace this.
