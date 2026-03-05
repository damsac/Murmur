# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **Shipping** — SSE streaming, entry arrival animations, confirmation UI removal, crash fixes

## What happened last session

- Removed confirmation UI entirely (ResultsSurfaceView, ConfirmationData, DenialLogStore)
- Wired SSE streaming into agent pipeline (processWithAgentStreaming, StreamingResponseAccumulator)
- Entry arrival animations: glow on expanded sections, peek preview on collapsed sections, staggered 150ms reveals
- Extracted SwipeableCard to its own file (was inline in HomeView)
- Bottom toast for text-only agent responses (replaces results surface)
- Toast direction changed from top to bottom (near mic button)
- ProcessingDotsView inline indicator while agent is working
- Fixed crash in ToolResultBuilder when actions include .confirm (safe range clamping)
- Added os.Logger SSE debug logging throughout pipeline
- Fixed Logger subsystem from com.murmur.app to com.gudnuf.murmur

## Recent decisions

- Confirmation UI removed — too much friction for the interaction model. Agent acts, user undoes.
- SSE streaming replaces batch calls — tool calls execute immediately as they arrive
- Entry arrival tracking via arrivedEntryIDs/pendingRevealEntryIDs on ConversationState
- Stagger animation: first entry immediately, rest with 150ms gaps
- Safety TTL: glow clears after 5s per entry
- buildActionSummary/sanitizeError moved to file-scope private functions (swiftlint type_body_length)
- Decodable types in PPQLLMService made internal (was private) — needed by ToolCallParser in separate file

## Open questions

- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Pre-existing test flake: PPQLLMServiceTests "Parses tool call response" fails due to MockURLProtocol static delegate cross-suite contamination

## What I need from sac

- Review arrival animation feel — timing, glow color, peek behavior
- Iterate on focus section UI — LLM curation wired, visual polish welcome
