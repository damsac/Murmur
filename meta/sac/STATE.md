# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Post-TestFlight bug fixes (round 5): due date sheet height.

## Recent decisions

- **DueDateEditSheet opens at .large detent** — Sheet was using `[.medium, .large]`, defaulting to medium. The graphical calendar + time wheel + toolbar buttons don't fit at medium height. Fix: use `[.large]` only so the sheet always opens with enough room.
- **Lists skip SwipeableCard in Focus tab too** — (from PR #136) PR #135 fixed the All tab but missed the Focus tab (`ZonedFocusTabView`). Same UIKit overlay root cause: `SwipeableCard` wrapping `ListCardView` fires expand/collapse on every tap. Fix: render `ListCardView` directly with `onTap: { onEntryTap(item.entry) }` — same pattern as the All tab fix.
- **Lists skip SwipeableCard in All tab** — (from PR #135) Same UIKit overlay root cause as habits (#134). When `SwipeableCard` wraps a `ListCardView`, the `UITapGestureRecognizer` overlay fires `sectionTapAction` (toggle expand/collapse) on every tap, including taps on item check-off Buttons. Fix: list entries skip `SwipeableCard` entirely in both the category section and search results. `ListCardView` handles navigation (header Button → `onTap`), expand/collapse (chevron Button), and item check-off (row Buttons) internally — no outer gesture wrapper needed.
- **DueDateEditSheet hasTime initialized from binding, not onAppear** — Previously `hasTime = false` at init, then `onAppear` set it to `true` if the date had a time component. This caused a visible layout jump (date picker alone → time picker appears). Fix: custom `init` initializes `@State private var hasTime` from `date.wrappedValue.hasTimeComponent` so the correct layout renders on first frame.
- **Top-up packs empty in TestFlight** — Not a code bug. `Product.products(for:)` returns empty because the IAP products don't exist in App Store Connect yet. The `.storekit` file is Simulator-only. Needs dam to create the three consumable products in ASC with product IDs: `com.damsac.murmur.credits.1000`, `com.damsac.murmur.credits.5000`, `com.damsac.murmur.credits.10000`.
- **Habits skip SwipeableCard in All tab** — (from PR #134) UIKit overlay steals all taps. Habits rendered as plain rows with `onTapGesture` for navigation. Circle `Button(.plain)` handles check-off.
- **Briefing regenerated per app session** — (from PR #134) Removed daily disk cache. LLM regenerates on every app launch.

## Open questions

- Should habit/list cards in All tab get swipe actions back? Currently removed to fix taps — could re-add with a UIKit hit-test override.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap?

## What I need from dam

- Create the three IAP products in App Store Connect (product IDs above) so top-up works in TestFlight.
- PPQ error signal for wiring error views (#9) — need a clear error type from PPQ auth/quota failures.
