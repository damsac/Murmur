# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Post-TestFlight bug fixes (round 2): habit card taps in All tab, personalized focus briefing.

## Recent decisions

- **Habits skip SwipeableCard in All tab** — `SwipeableCard` uses a UIKit `UITapGestureRecognizer` overlay when swipe actions are present. This overlay wins the hit-test on real devices and steals all taps before the SwiftUI Button can receive them. Habits in the All section were wrapped in `SwipeableCard`, so neither circle check-off nor row navigation worked. Fix: habits skip `SwipeableCard` entirely, rendered as plain rows with `onTapGesture` for navigation. Circle `Button(.plain)` handles check-off. Matches Focus tab behavior exactly.
- **Briefing regenerated per app session, not per day** — Removed the daily disk cache check in `requestHomeComposition`. Composition (including briefing) is now regenerated via LLM on every app launch (when `homeComposition == nil`). Within a session, layout refreshes handle incremental updates. This ensures the greeting subtitle is always personalized to the current state of entries.
- **Stale "all clear" safety net** — If the LLM runs early with no entries (briefing = "All clear") and entries arrive mid-session via layout refresh, the view detects the stale all-clear text and falls back to a generic "Here's what needs your attention today." This covers the edge case without requiring mid-session LLM re-composition.
- **Briefing computed from actual zones, not LLM cache** — (from previous PR) `composition.briefing` is set once by the LLM and cached. Fix: derive the subtitle dynamically — show LLM briefing when it's not stale, fall back to hardcoded string otherwise.
- **Credits button: dismiss settings before opening top-up** — (from previous PR) iOS can't present two sheets simultaneously. Fix: set `showSettings = false`, delay 0.45s, then `showTopUp = true`.
- **Habit circle: Button instead of nested onTapGesture** — (from previous PR) Replacing the circle with a `Button(.plain)` gives SwiftUI proper gesture priority semantics.

## Open questions

- Should habit cards in All tab also have swipe actions (Done/Snooze)? Currently removed to fix taps — could re-add with a UIKit hit-test override that lets the circle through.
- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- `project.yml` now has `UIRequiresFullScreen: true` — should we revisit iPad support later?
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on one home view?

## What I need from dam

- PPQ error signal for wiring error views (#9) — need a clear error type from PPQ auth/quota failures.
- Confirm whether habit navigation to detail should be re-enabled (current: row tap navigates, circle tap toggles — both in Focus and All tabs now).
