# Multi-Turn Conversation Persistence

> Wire existing conversation infrastructure through so turns accumulate in memory.

## Status quo

- `Pipeline.currentConversation` exists and persists across calls
- `Pipeline.processWithAgent()` accepts an optional `conversation` parameter
- When `conversation` is nil, a fresh `LLMConversation` is created
- When provided, subsequent turns append to the existing history
- `buildRequestMessages()` only includes system prompt when `conversation.messages.isEmpty` (first turn)
- **But**: `RootView` never passes a conversation — every input starts fresh

## Changes

### 1. Pass conversation from RootView (2 call sites)

**`handleStopRecording()`** (RootView.swift ~line 322):
```swift
// Before:
let result = try await pipeline.processWithAgent(
    transcript: liveText,
    existingEntries: agentContext
)

// After:
let result = try await pipeline.processWithAgent(
    transcript: liveText,
    existingEntries: agentContext,
    conversation: pipeline.currentConversation
)
```

**`handleTextSubmit()`** (RootView.swift ~line 370): same change.

### 2. Entry context refresh — already handled

`activeAndSnoozedEntries` is computed from the live SwiftData query at call time. After the agent creates/updates entries on turn N, turn N+1 will see the updated entries because the query reflects current state. No change needed.

### 3. System prompt — already correct

`buildRequestMessages()` checks `conversation.messages.isEmpty`. First turn gets system prompt + user message. Subsequent turns get the full conversation history + new user message. No change needed.

### 4. No reset logic

Pipeline is not persisted to disk. App termination recreates it via `AppState.configurePipeline()`, which creates a fresh `Pipeline` with `currentConversation = nil`. Natural reset.

## What NOT to change

- No UI for conversation state
- No reset button
- No disk persistence
- No changes to synthetic tool results ("accepted") — parallel lane
- No changes to Pipeline, PPQLLMService, or AppState

## Risk

- Token usage grows with conversation length (more input tokens per turn). Acceptable for testing.
- Stale entries in conversation history (turn 1's entry list vs turn 3's) — acceptable, LLM sees progression.
