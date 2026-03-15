# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Unified home composition** — complete. Both views consume single `HomeComposition` model. DailyFocus system deleted. Both views have Focus/All tabs.
- **Layout diff system** — Phases 1-2 complete. Phase 3 (DamHomeView animations) and Phase 4 (settings toggle) remain.

## What happened last session

- Unified composition refactor: deleted entire DailyFocus system (types, prompts, store, state). Single `HomeComposition` model with `CompositionVariant` (.scanner/.navigator) consumed by both views.
- `CompositionVariant` enum, `briefing: String?`, `variant: CompositionVariant?` on HomeComposition
- Navigator prompt (`LLMPrompt.navigatorComposition`), layout refresh prompt (`LLMPrompt.layoutRefresh`)
- PPQLLMService: variant-aware `composeHomeView`, `refreshLayout()`, per-turn `layoutInstructions(for:)`
- Variant-aware cache: `HomeCompositionStore.load(expectedVariant:)`
- AppState: session tracking (currentSessionID, refreshTask), `requestLayoutRefresh()`, variant-aware fallbacks
- RootView: unified composition calls, variant switch handler (full reset), session-based refresh
- SacHomeView: FocusTabView reads `HomeComposition` instead of `DailyFocus`, badge as reason
- DevModeView: deleted Daily Focus button, picker labels "Navigator"/"Scanner"
- Deleted `DailyFocusStore.swift`
- Capped scanner at 7 items (was 5-15) to match navigator
- Extracted `AllEntriesView.swift` — shared category browser used by both home variants
- DamHomeView now has Focus/All tab switcher
- 57 tests passing (6 new for CompositionVariant/briefing)
- Used Claude teams (swarm) with core-worker + app-worker for parallel execution

## Recent decisions

- `.scanner` / `.navigator` naming (behavior-descriptive, not person-coupled)
- Diff-only refresh on app foreground (cheaper than full recompose)
- Session-level staleness (UUID, not time-based)
- Variant switch = full reset (invalidate + nil conversation + cold start)
- Both home views share AllEntriesView for the "All" tab
- Scanner and navigator both capped at 7 items

## Open questions

- LLM model switch: when to move from Sonnet to Haiku? Need to validate quality with core-scenarios
- Credit value redefinition: $0.001 → $0.0005 per credit to make packs profitable
- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Phase 3 matchedGeometryEffect: known to be finicky — may need fallback to simple opacity transitions

## What I need from sac

- Sign off on onboarding demo transcript and 3 vs 1 demo entries
- Category color palette approval
- Thoughts on unified composition approach — does navigator feel right reading HomeComposition?
