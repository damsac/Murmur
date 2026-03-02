# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Onboarding redesign + habit check-off button fix.

## Recent decisions

- **Onboarding now 3 moments** — welcome → demo → result. Previously dropped straight into the transcript demo with no hook. Added `OnboardingWelcomeView` (hook + CTA) and `OnboardingResultView` (payoff — see what was captured).
- **Multiple demo entries** — changed from single-entry demo to 3 entries (reminder + todo + idea) to show the full breadth of what Murmur captures in one voice note.
- **Skip on welcome screen** — added skip button top-right. Calls `skipAndComplete()` without saving any entries. The demo is ~5s but some users will reject all onboarding.
- **Processing auto-advances to result** — reduced delay from 2s → 1.5s; result screen is where the payoff happens. User explicitly taps "Start capturing" to save and proceed.
- **isDevMode defaults true in DEBUG** — was always `false`; means every dev build needs to manually toggle dev mode. Now `#if DEBUG` sets it to `true` automatically.
- **Focus cards got swipe actions** — FocusCardView now participates in the shared `activeSwipeEntryID` binding and receives swipe actions from the parent. Previously it had no swipe actions.
- **Habit check-off button fix** — replaced `onTapGesture` on background with a proper `Button` wrapper in `SwipeableCard`. SwiftUI's inner-Button-wins rule means the habit circle button now correctly takes priority over card navigation.
- **Done habits excluded from focus strip** — habits already checked off for the period are filtered out of `focusEntries`. Reduces noise; no point showing a done item as urgent.
- **Focus strip visual cleanup** — removed yellow zone container (background + border). Cards sit directly in the list without a bounding box.

## Open questions

- Habit button fix needs a test run — confirm the circle toggles and doesn't open the detail sheet
- Is 3 the right cap for focus items, or should it adapt to screen space?

## What I need from dam

- Confirm onboarding demo transcript still feels like a real use case. Current: "Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"
- Thoughts on 3 demo entries vs 1 — is the variety valuable or overwhelming?
