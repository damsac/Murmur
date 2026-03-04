# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Confirmation flow cleanup: removed transcript UI, added tap-to-edit on create cards, deduped conflicting proposed actions, added header hint explaining pill-tap-to-cycle interaction.

## Recent decisions

- **Removed transcript UI from EntryDetailView** — `onViewTranscript` callback and "View transcript" button deleted. The raw transcript is internal data, not a useful user-facing view. Removed from DevScreen and RootView as well.
- **Tap-to-edit on proposed create cards** — In confirmation mode, create action rows now show a pencil icon and open `EntryEditSheet` when tapped. User can edit summary, category, and priority before confirming. Edits stored in `createOverrides[Int: CreateAction]` and applied in `buildFinalActions`. Cycling (complete↔archive) and editing are mutually exclusive by action type.
- **Dedup conflicting proposed actions by entry ID** — `parseProposedActions` in `PPQLLMService` now filters out duplicate actions referencing the same entry ID, keeping only the first. Prevents the LLM from proposing both "complete" and "archive" for the same entry in a single confirmation surface.
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
- **Briefing message always surfaces** — `FocusStripView` previously hid the entire section when items were empty. Now the greeting+message always renders when `dailyFocus != nil`; focus cards are conditional inside it.
- **Greeting not doubled** — deterministic fallback was prepending `Greeting.current` to the message string, which the view also renders as a bold header. Removed from the fallback message so the LLM and deterministic paths are consistent.
- **FocusContainerView height no longer locked** — replaced ZStack/shimmerHeight approach with simple `if/else if`. The ZStack captured shimmer height in state and used `minHeight` to prevent collapse during card stagger; this left a gap after cards were archived. Since shimmer and strip are mutually exclusive, `if/else if` is correct and height is always natural.

## Open questions

- Is 3 the right cap for focus items, or should it adapt to screen space?
- Weekly and monthly habits: `appliesToday` always returns true for these (they apply every day of the week/month). Is there a scenario where a weekly habit should be excluded from focus on certain days?

## What I need from dam

- Confirm onboarding demo transcript still feels like a real use case. Current: "Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"
- Thoughts on 3 demo entries vs 1 — is the variety valuable or overwhelming?
- Category color remapping — sign off that the new palette works with the overall design direction.
- Is the dedup-by-first approach right for `parseProposedActions`? Alternative would be to prefer the action type that matches the user's intent (e.g. parse "archive and complete" as archive only). Current approach just drops the second occurrence.
- Review PR #84 — confirmation flow cleanup + header hint "Tap action to change".
