# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Streaming arrival system polish: card arrival animations, toast after last card lands, focus section UX correctness (due text on habits, focus card reason color semantics).

## Recent decisions

- **`dueText` category guard** — `GlowingEntryRow.dueText` now only renders for `.todo` and `.reminder` entries. The LLM can attach `dueDate` to habits; the view shouldn't surface it as "Due tomorrow" noise in the regular list.
- **Focus card reason color semantics** — `FocusCardView` was always rendering the LLM reason (e.g., "Due", "Stale") in red with an exclamation mark. Added `isOverdue`/`isDueSoon` computed properties using actual `entry.dueDate` math: overdue → red + `exclamationmark.circle.fill`, due soon → yellow + `calendar`, everything else → secondary text + `circle.fill`. String-matching LLM output for visual treatment is fragile; real entry data is reliable.
- **Streaming arrival animation system** — `ConversationState` tracks `pendingRevealEntryIDs` (hidden during delay), `arrivedEntryIDs` (glowing), `lastRevealTime` (latest scheduled reveal across all batches), `toastTask` (cancellable; fires `completionText` after 1.5s post-last-reveal). `CategorySectionView` diffs `arrivedEntryIDs` additions (not removals) to prevent re-peek on glow expiry. `onAppear` guard handles first card in a new category.
- **Removed transcript UI from EntryDetailView** — `onViewTranscript` callback and "View transcript" button deleted. The raw transcript is internal data, not a useful user-facing view. Removed from DevScreen and RootView as well.
- **Dedup conflicting agent actions by entry ID** — `PPQLLMService` now filters out duplicate actions referencing the same entry ID (via `deduplicateByEntryID`), keeping only the first. Prevents the LLM from emitting both "complete" and "archive" for the same entry in one turn. `mutationEntryID` extension on `AgentAction` enables generic filtering across all mutation types.
- **Tap-to-edit on proposed create cards** — now obsolete (ResultsSurfaceView deleted by PR #86). Carried dedup logic and transcript removal forward; dropped confirmation UI changes.
- **Skeleton shimmer → minimal loading indicator** — `FocusShimmerView` (3 placeholder cards) replaced with `FocusLoadingView`: dimmed greeting + pulsing "Murmur is selecting your focus…" subtitle. Less visual noise; no fixed height reserved.
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
- **Focus strip natural height** — removed `shimmerHeight`/`ZStack`/`GeometryReader` fixed-height hack from `FocusContainerView`. Section now sizes naturally; shimmer and strip are a simple `if/else if`.
- **Categories slide smoothly** — swapped `LazyVStack` → `VStack` for category sections (max 7, safe); added `.animation(Animations.smoothSlide, ...)` keyed on focus loading state and item count. Categories animate up/down as focus cards appear or are completed.

## Open questions

- Is 3 the right cap for focus items, or should it adapt to screen space?
- Weekly and monthly habits: `appliesToday` always returns true for these (they apply every day of the week/month). Is there a scenario where a weekly habit should be excluded from focus on certain days?
- Dedup policy: is first-wins correct for conflicting agent actions, or should "stronger" actions win (archive > complete)? Relevant if a user voice note says "finish and archive all the old tasks."
- Individual card reveal tasks (`.sleep` → `pendingRevealEntryIDs.remove`) can't be cancelled if a new request starts mid-reveal. Currently fine (entry just glows briefly), but worth tracking.

## What I need from dam

- Review the dedup logic (`deduplicateByEntryID` + `mutationEntryID`) — is dedup-by-first the right approach?
- Is there a scenario where the same entry ID should appear in two different actions in one turn (e.g. complete + archive = just archive)? Should we prefer the "stronger" action?
