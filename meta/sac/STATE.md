# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Home screen redesign — focus strip + collapsible category sections + habit check-off.

Two commits shipping together:
1. **Focus strip + collapsible sections** — replaced flat sorted list with a horizontal "FOCUS" chip strip at top (always visible) and per-category collapsible sections below. Collapse state persists via `@AppStorage`.
2. **Habit check-off** — added circle button to habit cards that toggles `isDoneForPeriod`. Cadence-aware (daily/weekdays/weekly/monthly). Tap animates via haptic feedback.

## Recent decisions

- **Focus strip always visible** — originally conditionally rendered (hidden when no urgent items). Changed to always show because the user expects it as a permanent landmark at the top. Shows "All clear" when nothing qualifies.
- **Focus strip criteria** — overdue = `dueDate < Date()` (not start of day); high-priority = `priority <= 2` with no due date requirement. P2 items without a due date still qualify.
- **Gesture fix** — `SwipeableCard` used `.onTapGesture` on its content wrapper, which intercepted taps before child `Button`s could receive them. Changed to `.gesture(TapGesture().onEnded {...})` which has lower priority than interactive children.
- **Items in strip also appear in category section** — intentional duplication. Strip is a lens, not a separate bucket.
- **`RootView` action methods moved to extension** — SwiftLint `type_body_length` was blocking commits (467 lines vs 400 limit). Moved all handler methods into a `private extension RootView` block. Struct body is now ~240 meaningful lines.

## Open questions

- Should focus strip chips be tappable to jump to the entry directly (currently they do open the detail sheet — working fine)?
- Should there be a "View all" button on the focus strip that opens a filtered list of all urgent items (beyond the 4 chip limit)?
- Habit cadence display — currently cadence isn't shown on the card; should there be a subtle label (e.g. "daily")?

## What I need from dam

- Review the gesture fix in `SwipeableCard` — specifically that `.gesture(TapGesture().onEnded {...})` vs `.onTapGesture` is the right long-term approach. Could also explore `simultaneousGesture` if needed.
- Any thoughts on the always-visible focus strip UX — does it feel right when there are no urgent items?
