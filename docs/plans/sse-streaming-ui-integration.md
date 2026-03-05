# SSE Streaming → UI Integration Plan

## Status Quo: What Uses Streaming vs Not

### Nothing uses streaming.

The SSE infrastructure was built but never wired in:

| Component | File | Current Path | Streaming? |
|-----------|------|-------------|------------|
| Agent processing | `PPQLLMService.process()` | `runTurn()` → `session.data(for:)` | No |
| Daily focus | `PPQLLMService.composeDailyFocus()` | `runTurn()` → `session.data(for:)` | No |
| Entry extraction | `PPQLLMService.extractEntries()` | `runTurn()` → `session.data(for:)` | No |
| Pipeline | `Pipeline.processWithAgent()` | Calls `llm.process()` (non-streaming) | No |
| ConversationState | `submitDirect()` | Calls `pipeline.processWithAgent()`, awaits full result | No |
| AppState | `requestDailyFocus()` | Calls `llmService.composeDailyFocus()`, awaits full result | No |

### Built but unused SSE components:

| Component | File | Purpose |
|-----------|------|---------|
| `SSELineParser` | `SSELineParser.swift` | Parses `data: {...}` lines and `[DONE]` sentinel |
| `StreamingResponseAccumulator` | `StreamingResponseAccumulator.swift` | Accumulates SSE chunks → emits `AgentStreamEvent` |
| `AgentStreamEvent` | `SSEStreamTypes.swift` | Event enum: `.textDelta`, `.toolCallStarted`, `.toolCallCompleted`, `.completed` |
| `ToolCallProgress` / `ToolCallResult` | `SSEStreamTypes.swift` | Progress/result types for streaming tool calls |
| `ToolCallParser` | `ToolCallParser.swift` | Shared parser used by both batch + streaming paths |

The `buildRequest()` method doesn't include `"stream": true` in the request body. Even if it did, `session.data(for:)` waits for the complete response — you'd need `URLSession.bytes(for:)` to consume SSE incrementally.

## What Needs to Change

### 1. PPQLLMService: Add streaming request path

**New method:** `processStreaming()` returning `AsyncStream<AgentStreamEvent>`

- Add `"stream": true` and `"stream_options": {"include_usage": true}` to request body
- Use `URLSession.bytes(for: request)` instead of `session.data(for:)`
- Feed each SSE line through `SSELineParser.parse()` → `StreamingResponseAccumulator.feed()`
- Yield each `AgentStreamEvent` to the caller
- On `[DONE]`, call `accumulator.finish()` and yield remaining events
- Update conversation history with `accumulator.assembledMessage()`

**Daily focus variant:** `composeDailyFocusStreaming()` returning `AsyncStream<String>`

- Same streaming request setup
- Only yields text deltas (the `message` field streams incrementally)
- Tool call (`compose_focus`) still parsed at stream end for structured items
- Returns `DailyFocus` at completion (items from tool call, message from accumulated text)

### 2. Pipeline: Add streaming passthrough

**New method:** `processWithAgentStreaming()` returning `AsyncStream<AgentStreamEvent>`

- Same credit gate logic as `processWithAgent()`
- Passes through events from `llm.processStreaming()`
- On `.completed`, does credit charge and updates `currentConversation`

### 3. LLMService protocol: Add streaming capability

- Add `processStreaming()` to `MurmurAgent` protocol (or make it optional with default)
- Add `composeDailyFocusStreaming()` to `PPQLLMService` (not protocol — only PPQ supports it)

### 4. ConversationState: Consume streaming events

**Replace `submitDirect()` internals:**

- Instead of awaiting `pipeline.processWithAgent()`, iterate `pipeline.processWithAgentStreaming()`
- On `.textDelta`: update `agentStreamText` incrementally (UI sees text appear token by token)
- On `.toolCallStarted`: optionally show "creating entries..." status
- On `.toolCallCompleted`: execute actions immediately (entries appear one by one)
- On `.completed`: finalize, replace tool results, record action result

Key design decision: should actions execute as tool calls complete (progressive), or batch at the end? Progressive is more responsive but complicates undo (partial generation).

### 5. AppState: Stream daily focus message

**Modify `requestDailyFocus()`:**

- Use `composeDailyFocusStreaming()` to get text deltas
- Set `dailyFocus.message` progressively as text arrives
- `FocusStripView` already observes `dailyFocus` — it would animate naturally
- Items (selected entries) only available at stream end when tool call completes

## Architectural Gaps

### Gap 1: No streaming method on PPQLLMService
The core blocker. `runTurn()` uses `session.data(for:)` which is inherently non-streaming. Need a parallel `runTurnStreaming()` using `URLSession.bytes(for:)`.

### Gap 2: LLMService protocol doesn't support streaming
The protocol returns `AgentResponse` (a complete value). Streaming requires `AsyncStream<AgentStreamEvent>`. Either extend the protocol or add streaming as a concrete method on `PPQLLMService`.

### Gap 3: Pipeline has no streaming passthrough
`processWithAgent()` returns `AgentResult`. Need a streaming variant that yields events while handling credit gating.

### Gap 4: ConversationState assumes batch results
`submitDirect()` awaits a single `AgentResult` then processes it all at once. Streaming requires an event loop that incrementally updates UI state.

### Gap 5: Daily focus message vs items timing
The `compose_focus` tool call contains both `items` (entry selections) and `message` (briefing text). With streaming, the message text arrives as content deltas BEFORE the tool call. But items are inside the tool call arguments, which stream incrementally and aren't parseable until complete. This means:
- Message can stream immediately (it's text content)
- Items only available at stream end (tool call arguments need full JSON)
- UI needs to handle showing the message while items are still loading

### Gap 6: Undo semantics with progressive execution
If tool calls execute as they complete (not batched), the undo system needs to handle partial generations. Current `generationCounter` assumes all-or-nothing.

## Recommended Sequencing

1. **PPQLLMService streaming** — add `runTurnStreaming()` + `processStreaming()`. Test with existing accumulator tests.
2. **Agent path first** — wire streaming through Pipeline → ConversationState for voice/text input. This is the primary interaction loop.
3. **Daily focus streaming** — lower priority since it's a one-shot call at app launch. Still valuable for perceived speed.
4. **Progressive execution** — decide batch-at-end vs execute-as-complete based on undo complexity.
