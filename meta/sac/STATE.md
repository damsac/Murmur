# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Real-device tap fixes: resolved two regressions introduced by the UIKit tap overlay fix — list cards navigating to detail instead of expanding, and habit circle opening detail instead of toggling.

## Recent decisions

- **UIKit overlay intercepts all taps** — The `UITapGestureRecognizer` added to `SwipeableCard` to fix real-device tapping was too aggressive: it captures all taps including those meant for interactive subviews (list expand chevron, habit circle). SwiftUI sub-buttons are unreachable behind the UIKit overlay.
- **Category-aware tap routing in SwipeableCard.onTap** — Rather than trying to detect which sub-element was tapped (no coordinate inspection), changed callers to route by category: lists toggle expansion, habits call `checkOffHabit`, others navigate. This keeps `SwipeableCard` API simple.
- **Expansion state hoisted out of ListCardView** — Added `externalExpanded: Binding<Bool>?` to `ListCardView`. Falls back to internal `@State` when nil (for previews/standalone use). Parent views (AllEntriesView, ZonedFocusHomeView, DamHomeView) each hold `@State private var expandedListIDs: Set<UUID>` and pass per-entry bindings.
- **Habit tap no longer navigates** — Tapping a habit card toggles it (if `appliesToday`). Navigation to habit detail is still available via swipe actions.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on SacHomeView?

## What I need from dam

- Confirm API key plan for TestFlight archive build — document or add a Makefile target.
- PPQ error signal for wiring error views (#9) — need a clear error type from PPQ auth/quota failures.
- Review the TestFlight checklist and adjust any dam-owned items or priorities.
