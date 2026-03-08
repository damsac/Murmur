# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Two-tab navigation (Focus + All) with expanded focus cards and bottom fade mask.

## Recent decisions

- **Focus tab as landing screen** — `selectedTab = .focus` default. Users open the app to their action dashboard, not the list. Focus tab is the primary surface; All tab is for browsing.
- **No TabView** — Simple `if/else` with slide transition (leading/trailing) in a ZStack. Avoids gesture conflicts with card swipes (horizontal gestures are consumed by the tab transition otherwise).
- **FocusTabView full-page layout** — Promoted Focus from a 3-item strip to a full scrollable page with up to 7 expanded cards. `FocusCardExpandedView` is richer: category label, 3-line summary, detail line (priority + due / cadence), LLM reason sentence.
- **AllTabView is the existing category list** — Moved category sections logic into `AllTabView` struct. Clean separation: Focus = curated action dashboard, All = full browse. No regression on existing list behavior.
- **7-item cap everywhere** — Bumped `.prefix(3)` → `.prefix(7)` in AppState, and "up to 3" → "up to 7" in LLMService (system prompt + tool description) and PPQLLMService. Focus tab now reveals a genuine daily picture.
- **Settings gear top-right** — Added `topBar` with gear icon; always visible from both empty and populated states. Previously there was no settings entry point from the home screen.
- **Tab labels in BottomNavBar** — "Focus" left / "All" right, flanking the mic. Keyboard button moved to the right side (next to All label) — no feature regression. Tab indicator is a small capsule underline.
- **Bottom fade mask instead of hard clip** — `populatedState` ZStack uses a `LinearGradient` mask (110pt fade at the bottom) to smoothly dissolve cards as they approach the mic dome. Looks much cleaner than a viewport clip and communicates "more content below" naturally.
- **Content padding 160pt** — Both FocusTabView and AllTabView have 160pt bottom padding inside their ScrollViews. Ensures the last card scrolls to a comfortable resting position well above the fade zone.

## Open questions

- Is 7 the right focus cap, or should it adapt to how many priority entries actually exist? Currently we show the top 7 regardless of whether items 5-7 are actually priority.
- Weekly and monthly habits: `appliesToday` always returns true for these. Intentional?
- Dedup policy: is first-wins correct for conflicting agent actions? (Carried from previous session.)
- Individual card reveal tasks can't be cancelled mid-reveal. (Carried.)

## What I need from dam

- Review the LLM prompt bump (3 → 7) in `LLMService.swift` and `PPQLLMService.swift` — does the system prompt need other tuning to handle 7 items well, or is just bumping the number sufficient?
- Do we want a "refresh" button on the Focus tab header, or is the auto-staleness refresh (3h) enough?
