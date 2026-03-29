# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Post-TestFlight bug fixes: three bugs found on first TestFlight install — stale greeting subtitle, credits button not opening, habit card taps not working.

## Recent decisions

- **Briefing computed from actual zones, not LLM cache** — `composition.briefing` is set once by the LLM and cached for the day. Layout refreshes update sections but not the briefing, so "All clear" persisted even after new entries arrived. Fix: derive the subtitle dynamically from computed zones — if any hero/standard/habits exist, show "Here's what needs your attention today." Only fall back to LLM briefing when zones are genuinely empty.
- **Credits button: dismiss settings before opening top-up** — Both settings and top-up are `.sheet` modifiers on the same root view. iOS can't present two sheets simultaneously; the second one is silently swallowed. Fix: set `showSettings = false`, call `openTopUp()`, then delay 0.45s before `showTopUp = true`.
- **Habit circle: Button instead of nested onTapGesture** — `HabitRowView` had a nested `onTapGesture` on the circle inside an outer `onTapGesture` on the whole row. On real devices, inner `onTapGesture` can eat all taps in its frame, making both the circle check-off AND row navigation unreliable. Replacing the circle with a `Button(.plain)` gives SwiftUI proper gesture priority semantics.
- **UIKit overlay intercepts all taps** — (from previous PR) The `UITapGestureRecognizer` in `SwipeableCard` was too aggressive. Fixed with category-aware routing.
- **Expansion state hoisted out of ListCardView** — (from previous PR) `externalExpanded: Binding<Bool>?` on `ListCardView`.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- `project.yml` now has `UIRequiresFullScreen: true` — should we revisit iPad support later?
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on one home view?

## What I need from dam

- PPQ error signal for wiring error views (#9) — need a clear error type from PPQ auth/quota failures.
- Confirm whether habit navigation to detail should be re-enabled (current: row tap navigates, circle tap toggles).
