# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Layout diff system** — Phase 1 (data model) and Phase 2 (tool schemas + agent integration) complete. Next: Phase 3 (DamHomeView animations) and Phase 4 (settings toggle).

## What happened last session

- Layout diff system Phase 1: LayoutOperation enum (7 cases), LayoutDiff return type, mutable HomeComposition with apply(operations:), findSection helper, 27 new unit tests
- Layout diff system Phase 2: get_current_layout and update_layout tool schemas, AgentAction cases, parsing in both streaming (ToolCallParser) and non-streaming (PPQLLMService) paths, AgentActionExecutor layout handling with appState, ToolResultBuilder formatting, ConversationState recentInserts clearing
- All 51 HomeComposition/LayoutOperations tests pass, full app builds clean

## Recent decisions

- Layout tools added to entryManager prompt (not separate prompt) — agent can read/update layout during normal conversation
- RawLayoutOperation decodes from snake_case JSON (entry_id, to_section, etc.) to Swift LayoutOperation enum
- Agent sees layout as JSON via get_current_layout, returns diff confirmation via update_layout
- homeCompositionStore changed from private to private(set) so executor can persist layout updates
- Layout actions don't produce Entry objects — new ActionOutcome cases (layoutRead, layoutUpdated) handle them
- compose_view one-shot path preserved as cold start; update_layout is additive

## Open questions

- Card design direction: inline row vs slim card vs multi-column grid?
- LLM model switch: when to move from Sonnet to Haiku? Need to validate quality with core-scenarios
- Credit value redefinition: $0.001 → $0.0005 per credit to make packs profitable
- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Phase 3 matchedGeometryEffect: known to be finicky — may need fallback to simple opacity transitions

## What I need from sac

- Sign off on onboarding demo transcript and 3 vs 1 demo entries
- Category color palette approval
- Read the design psychology doc — does "Navigator" resonate?
- Thoughts on "Focus / Browse" as the settings toggle labels
