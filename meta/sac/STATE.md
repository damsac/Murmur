# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Habit check-off UX fixes + home screen polish.

## Recent decisions

- **Onboarding now 3 moments** — welcome → demo → result. Previously dropped straight into the transcript demo with no hook. Added `OnboardingWelcomeView` (hook + CTA) and `OnboardingResultView` (payoff — see what was captured).
- **Multiple demo entries** — changed from single-entry demo to 3 entries (reminder + todo + idea) to show the full breadth of what Murmur captures in one voice note.
- **Skip on welcome screen** — added skip button top-right. Calls `skipAndComplete()` without saving any entries. The demo is ~5s but some users will reject all onboarding.
- **Processing auto-advances to result** — reduced delay from 2s → 1.5s; result screen is where the payoff happens. User explicitly taps "Start capturing" to save and proceed.
- **isDevMode defaults true in DEBUG** — was always `false`; means every dev build needs to manually toggle dev mode. Now `#if DEBUG` sets it to `true` automatically.
- **SwipeableCard refactored to pure SwiftUI** — removed UIKit `HorizontalPanGestureView` (custom `UIPanGestureRecognizer`). Now uses `DragGesture` with `abs(dx) > abs(dy)` direction guard and `isDraggingHorizontally` state. Simpler and more maintainable.
- **Tap gesture moved to outer ZStack** — `onTapGesture` lives on the outer `ZStack` wrapping both the card and the action buttons. This is how SwiftUI gesture routing works: inner `Button`s (like the habit circle) win over the outer tap, so the circle button correctly intercepts its own taps.
- **isCompletedToday decoupled from isDoneForPeriod** — root cause of the check-off bug: `isDoneForPeriod` for `.weekdays` cadence returns `false` on Sat/Sun (correct — the habit doesn't apply). But the toggle used it as "is this checked off today?" — so on Sunday, toggling always set a date and never cleared. Fixed by adding `isCompletedToday` which purely checks `lastHabitCompletionDate` against today, no cadence logic.
- **appliesToday gates focus strip and circle button** — weekday habits are now excluded from the focus strip on weekends and the check-off circle is hidden. Semantically correct: no point surfacing a habit you can't check off today.
- **Category color remapping** — differentiated colors per category (todo=purple, reminder=yellow, idea=orange, habit=green, note=slate, thought=blue, question=fuchsia, list=teal). Previous mapping had duplicates (reminder=yellow, idea=yellow; thought=blue, habit=blue).
- **Post-onboarding card hints** — "Swipe to act · Tap to edit" tooltip appears at bottom after onboarding completes. Auto-dismisses after 4s, tappable to dismiss early.

## Open questions

- Is 3 the right cap for focus items, or should it adapt to screen space?
- Weekly and monthly habits: `appliesToday` always returns true for these (they apply every day of the week/month). Is there a scenario where a weekly habit should be excluded from focus on certain days?

## What I need from dam

- Confirm onboarding demo transcript still feels like a real use case. Current: "Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"
- Thoughts on 3 demo entries vs 1 — is the variety valuable or overwhelming?
- Category color remapping — sign off that the new palette works with the overall design direction.
