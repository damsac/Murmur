# Murmur Agent Pipeline — Architecture Review

> Research-only review. Traces every step from user input to final result.
> Date: 2026-02-28

---

## 1. Pipeline Overview (Sequence)

```
User speaks/types
    │
    ▼
┌──────────────────────┐
│  AppleSpeechTranscriber  │  (Speech framework → live partial text)
│  or text input directly  │
└──────────┬───────────┘
           │ transcript: String
           ▼
┌──────────────────────┐
│  RootView             │  Builds AgentContextEntry[] from active/snoozed entries
│  (handleStopRecording │  Calls pipeline.processWithAgent(transcript, entries)
│   / handleTextSubmit) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Pipeline.processWithAgent()  │  Credit pre-auth → LLM call → credit charge
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  PPQLLMService.process()  │  Builds messages + tools → HTTP POST to PPQ.ai
│                            │  Parses tool_calls → [AgentAction]
└──────────┬───────────┘
           │ AgentResponse { actions, summary, usage }
           ▼
┌──────────────────────┐
│  AgentActionExecutor.execute()  │  Applies create/update/complete/archive to SwiftData
│                                  │  Produces UndoTransaction
└──────────┬───────────┘
           │ ExecutionResult { applied, failures, undo }
           ▼
┌──────────────────────┐
│  Toast UI (agent toast)  │  Shows summary + expandable actions + "Undo" button
│                           │  5-second display
└──────────────────────┘
```

---

## 2. Voice Input → Transcription

**Protocol:** `Transcriber` (`Packages/MurmurCore/Sources/MurmurCore/Transcriber.swift`)

```swift
public protocol Transcriber: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> Transcript
    func cancelRecording() async
    var currentTranscript: String { get async }
    var isRecording: Bool { get async }
    var isAvailable: Bool { get async }
}
```

**Implementation:** `AppleSpeechTranscriber` (`AppleSpeechTranscriber.swift`)

- Uses Apple's `SFSpeechRecognizer` with `en-US` locale
- Creates a fresh `AVAudioEngine` per session (avoids stale tap state)
- Installs audio tap on input node → feeds buffers to `SFSpeechAudioBufferRecognitionRequest`
- Partial results update `_currentTranscript` via `recognitionTask` callback
- `stopRecording()` calls `cleanupRecordingState(endAudio: true)`, sleeps 500ms for final results, returns `Transcript(text:)`

**Output:** `Transcript` — contains `.text: String` and `.segments: [Segment]`

**Key detail in actual usage:** The UI flow in `RootView.handleStopRecording()` does NOT call `pipeline.stopRecording()`. Instead it:
1. Reads `pipeline.currentTranscript` (the live partial)
2. Calls `pipeline.cancelRecording()` (discards without finalizing)
3. Sends the captured text directly to `processWithAgent()`

This means segments/timing data from finalized transcription are never used in the agent path.

---

## 3. Transcription → LLM Context

### 3a. Entry context building

**Location:** `RootView:324-328` (voice) and `RootView:372-376` (text)

```swift
let agentContext = activeAndSnoozedEntries.map { $0.toAgentContext() }
```

`activeAndSnoozedEntries` = all entries with `.active` or `.snoozed` status.

**`Entry.toAgentContext()`** (`Entry.swift:193`):
- Maps UUID → short ID (first 6 chars, lowercased)
- Copies summary, category, priority, dueDateDescription, cadence, status, createdAt
- Returns `AgentContextEntry`

### 3b. User content formatting

**`PPQLLMService.buildAgentUserContent()`** (`PPQLLMService.swift:314-338`):

When entries exist, produces:
```
## Current Entries

- [abc123] TODO P1 "Buy groceries" due:tomorrow
- [def456] REMINDER "Dentist appointment" status:snoozed

## User Transcript
<raw transcript text>
```

When no entries: just the raw transcript text.

Entries are sorted: by priority ascending (lower = more important), then by createdAt descending (newest first).

### 3c. Message construction

**`buildRequestMessages()`** (`PPQLLMService.swift:110-127`):

**First turn** (conversation.messages is empty):
```json
[
  {"role": "system", "content": "Current date and time: ...\n\n<system prompt>"},
  {"role": "user", "content": "<formatted user content>"}
]
```

**Subsequent turns** (multi-turn refinement):
```json
[...previous conversation messages..., {"role": "user", "content": "<new input>"}]
```

System prompt is only included in first turn — on subsequent turns, it's already in the conversation history.

---

## 4. System Prompt

Two prompt variants defined in `LLMPrompt` (`LLMService.swift:39-107`):

### `LLMPrompt.entryManager` (agent mode — default)

Used by `PPQLLMService.process()`. Full agentic prompt with:
- Role: "Murmur, a personal entry manager for voice input"
- Decision rules: prefer updating over creating duplicates, fuzzy semantic matching, status-aware
- Quality rules: concise card-style, 10-word summaries, natural language dates
- Mutation rules: every update/complete/archive needs a reason
- Output rules: tool calls only, no clarifying questions
- Tool choice: `.auto`

### `LLMPrompt.entryCreation` (extraction mode — backward compat)

Used by `PPQLLMService.extractEntries()`. Create-only prompt for the old UI flow.
- Tool choice: `.function(name: "create_entries")` — forced

---

## 5. Tool Definitions

Four tools, all using OpenAI-compatible function calling schema:

### `create_entries`
```
Parameters: { entries: [{ content, category, source_text, summary, priority?, due_date?, cadence? }] }
Required per item: content, category, source_text, summary
```

### `update_entries`
```
Parameters: { updates: [{ id, fields: { content?, summary?, category?, priority?, due_date?, cadence?, status?, snooze_until? }, reason }] }
Required per item: id, fields, reason
```

### `complete_entries`
```
Parameters: { entries: [{ id, reason }] }
Required per item: id, reason
```

### `archive_entries`
```
Parameters: { entries: [{ id, reason }] }
Required per item: id, reason
```

**Category enum:** todo, note, reminder, idea, list, habit, question, thought
**Cadence enum:** daily, weekdays, weekly, monthly
**Status enum (update only):** active, snoozed, completed, archived

---

## 6. Agent Loop

### Single-turn execution

The agent loop is **single-turn**: one HTTP request → one response → parse tool calls → done.

**`PPQLLMService.runTurn()`** (`PPQLLMService.swift:75-106`):
1. `buildRequestMessages()` — system + user (or continuation)
2. `buildRequest()` — HTTP POST to `https://api.ppq.ai/chat/completions`
3. `URLSession.data(for:)` — single HTTP call
4. `parseAssistantMessage()` — extract `choices[0].message`
5. `parseUsage()` — extract token counts
6. `updateConversation()` — append to conversation history

### Conversation history management

**`updateConversation()`** (`PPQLLMService.swift:150-170`):
- Replaces `conversation.messages` with the full request messages
- Appends the assistant message
- For each tool call, appends a synthetic `role: "tool"` message: `"<toolName> accepted."`

This means tool call results are always reported as successful. The LLM never sees actual execution outcomes.

### Multi-turn support

`Pipeline.processWithAgent()` accepts an optional `conversation` parameter. If provided, subsequent turns reuse the conversation history. `Pipeline.currentConversation` persists across calls.

However, the UI (`RootView`) does NOT pass a conversation — each voice/text input creates a fresh `LLMConversation` inside `processWithAgent()`. Multi-turn is structurally supported but not exercised in the current agent path.

---

## 7. Tool Call Parsing

**`parseActions()`** (`PPQLLMService.swift:185-230`):

1. Extracts `tool_calls` array from assistant message
2. For each tool call: gets function name + arguments JSON string
3. Decodes arguments into typed Swift structs via `JSONDecoder`
4. Maps to `AgentAction` enum cases

**Decoding types** (`PPQLLMService.swift:380-506`):
- `CreateEntriesArguments` → `[RawCreateAction]` → `CreateAction`
- `UpdateEntriesArguments` → `[RawUpdateAction]` → `UpdateAction`
- `EntryMutationArguments` → complete/archive actions

**Fallback behavior:**
- If `tool_calls` is nil (model responded with text only): returns empty `[AgentAction]`
- Unknown tool names: silently skipped (`default: continue`)
- Missing optional fields: normalized (empty reason → "No reason provided", empty source_text → content)

---

## 8. Result → SwiftData (AgentActionExecutor)

**`AgentActionExecutor.execute()`** (`AgentActionExecutor.swift:35-63`):

Iterates actions, executes each independently:

### Create
- Creates `Entry` via convenience init with all fields
- Resolves `dueDate` via `Entry.resolveDate()` (NSDataDetector)
- Inserts into `modelContext`
- Syncs notification

### Update
- Resolves entry via `Entry.resolve(shortID:in:)` — prefix match on UUID
- Captures `FieldSnapshot` for undo
- Applies field updates + status transitions
- Skips if entry is also being completed in same batch

### Complete / Archive
- Resolves entry by short ID
- Calls `entry.perform(.complete/.archive, ...)`
- Captures previous status for undo

### ID Resolution
**`Entry.resolve(shortID:in:)`** (`Entry.swift:215-220`):
- Filters entries whose UUID (lowercased) starts with the given prefix
- Returns the match only if exactly 1 entry matches
- Returns nil if 0 or 2+ matches (ambiguous)

### Transaction
- All changes saved in a single `modelContext.save()` at the end
- Returns `ExecutionResult` with applied actions, failures, and `UndoTransaction`

---

## 9. Result → UI

**`RootView.showAgentToast()`** (`RootView.swift:458-472`):

- If any actions were applied: shows an agent toast with summary, action list, and undo button (5s duration)
- If no actions but summary text exists: shows a plain info toast
- If empty everything: nothing shown

**Undo flow** (`RootView.handleUndo()`):
- `UndoTransaction.execute()` reverses all items in reverse order
- Created entries: deleted from context
- Updated entries: restored from field snapshot
- Completed/archived entries: status reverted
- Single `modelContext.save()` at end
- Shows "Undone" toast

---

## 10. Credit System

### Flow
1. **Pre-auth:** `creditGate.authorize()` — checks balance > 0, returns `CreditAuthorization`
2. **LLM call:** happens between auth and charge
3. **Charge:** `creditGate.charge(auth, usage, pricing)` — calculates credits from token usage

### Pricing math (`Credits.swift:44-53`)
```
inputCostMicros = inputTokens × inputUSDPer1MMicros
outputCostMicros = outputTokens × outputUSDPer1MMicros
totalMicros = (inputCostMicros + outputCostMicros) / 1,000,000
credits = ceil(totalMicros / 1,000)
credits = max(minimumChargeCredits, credits)
```

1 credit = $0.001 (1,000 USD micros)

### Current pricing config (`AppState.swift:43-48`)
```swift
inputUSDPer1MMicros: 1_000_000    // $1.00 per 1M input tokens
outputUSDPer1MMicros: 5_000_000   // $5.00 per 1M output tokens
minimumChargeCredits: 1
```

### Storage
`LocalCreditGate` — backed by UserDefaults, 1,000 starter credits.

---

## 11. Key Types & Protocols

| Type | Location | Role |
|------|----------|------|
| `Transcriber` | MurmurCore/Transcriber.swift | Audio → text protocol |
| `AppleSpeechTranscriber` | MurmurCore/AppleSpeechTranscriber.swift | Apple Speech impl |
| `Transcript` | MurmurCore/Transcriber.swift | Text + segments |
| `LLMService` | MurmurCore/LLMService.swift | Agent protocol (extends MurmurAgent) |
| `MurmurAgent` | MurmurCore/LLMService.swift | Core agent protocol |
| `PPQLLMService` | MurmurCore/PPQLLMService.swift | PPQ.ai HTTP impl |
| `LLMPrompt` | MurmurCore/LLMService.swift | System prompt + tools config |
| `LLMConversation` | MurmurCore/LLMService.swift | Opaque message history |
| `AgentContextEntry` | MurmurCore/LLMService.swift | Compact entry snapshot for LLM |
| `AgentAction` | MurmurCore/LLMService.swift | Typed action enum (create/update/complete/archive) |
| `AgentResponse` | MurmurCore/LLMService.swift | Actions + summary + usage |
| `Pipeline` | MurmurCore/Pipeline.swift | Orchestrator (transcriber + LLM + credits) |
| `AgentActionExecutor` | Services/AgentActionExecutor.swift | SwiftData action applier |
| `UndoTransaction` | Services/AgentActionExecutor.swift | Reversible change set |
| `FieldSnapshot` | Services/AgentActionExecutor.swift | Pre-mutation field capture |
| `CreditGate` | MurmurCore/Credits.swift | Credit authorization protocol |
| `LocalCreditGate` | Services/Credits/LocalCreditGate.swift | UserDefaults-backed credit store |
| `AppState` | Services/AppState.swift | Observable pipeline + recording state |
| `Entry` | Models/Entry.swift | SwiftData model |

---

## 12. Gaps & Rough Edges

### Architecture

1. **Transcript not finalized in agent path.** `handleStopRecording()` reads `currentTranscript` (partial), then calls `cancelRecording()`. The 500ms finalization sleep in `stopRecording()` is bypassed. This means the agent may receive an incomplete transcript — the last few words of speech could be missing.

2. **Single-turn only.** The agent makes one LLM call and acts on whatever comes back. No clarifying questions, no "are you sure?", no retries. If the model misunderstands, the user's only recourse is undo.

3. **Tool results are synthetic.** `updateConversation()` appends `"<tool> accepted."` for every tool call regardless of actual execution outcome. The LLM never learns that an action failed (e.g., entry not found). This matters for multi-turn: if multi-turn were exercised, the model would have false beliefs about what happened.

4. **Multi-turn wired but unused.** `Pipeline.processWithAgent()` supports conversation continuation, but `RootView` never passes a conversation. Each interaction starts fresh.

### Data Integrity

5. **Short ID collisions.** 6-character hex prefix = ~16.7 million unique values. With typical entry counts (<1000), collision probability is negligible. But `resolve(shortID:)` returns nil on ambiguity (2+ matches) rather than failing loudly — the action silently fails.

6. **No validation on LLM output.** If the model returns priority=99 or category="invalid", the decode will fail for that tool call. `parseActions` will throw, aborting ALL actions from that response — not just the malformed one.

7. **Date resolution is best-effort.** `NSDataDetector` handles common phrases ("next Thursday", "tomorrow") but can't handle everything ("in 3 business days", "the day after my birthday"). No fallback — unresolvable dates are silently nil.

### Error Handling

8. **All-or-nothing action parsing.** A single malformed tool call from the LLM causes `parseActions()` to throw, which propagates up as `PipelineError.extractionFailed`. The user sees an error toast and loses all actions — including valid ones from other tool calls in the same response.

9. **Conversation state is `[[String: Any]]`.** Untyped dictionary — no compile-time safety, no Codable serialization, easy to corrupt. Works fine for the current single-turn pattern but would be fragile for persistence or debugging.

10. **Silent skip on unknown tools.** If the LLM invents a tool name (e.g., "delete_entries"), `parseActions` silently skips it via `default: continue`. No logging, no user feedback.

### UX

11. **No feedback on partial failures.** `AgentActionExecutor` tracks failures independently, but `showAgentToast()` only checks `execResult.applied.isEmpty`. If 3 of 5 actions applied and 2 failed, the user sees the success toast with no indication of failures.

12. **Undo is all-or-nothing.** The undo button reverses the entire batch. If the agent created 3 entries and completed 1, the user can't undo just the completion — it's all or nothing.

---

## 13. Key Files Reference

| File | Path |
|------|------|
| Pipeline | `Packages/MurmurCore/Sources/MurmurCore/Pipeline.swift` |
| LLM protocol + types | `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift` |
| PPQ implementation | `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift` |
| Transcriber protocol | `Packages/MurmurCore/Sources/MurmurCore/Transcriber.swift` |
| Apple Speech impl | `Packages/MurmurCore/Sources/MurmurCore/AppleSpeechTranscriber.swift` |
| Credits | `Packages/MurmurCore/Sources/MurmurCore/Credits.swift` |
| Enums | `Packages/MurmurCore/Sources/MurmurCore/Enums.swift` |
| Action executor | `Murmur/Services/AgentActionExecutor.swift` |
| App state | `Murmur/Services/AppState.swift` |
| Root view (UI integration) | `Murmur/Views/RootView.swift` |
| Entry model | `Murmur/Models/Entry.swift` |
| Credit gate impl | `Murmur/Services/Credits/LocalCreditGate.swift` |
