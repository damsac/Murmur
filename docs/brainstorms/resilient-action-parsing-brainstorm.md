# Resilient Action Parsing — Brainstorm

> Addressing gaps #6 (no LLM output validation) and #8 (all-or-nothing parsing) from the agent pipeline review.
> Date: 2026-02-28

---

## The Problem, Concretely

In `PPQLLMService.parseActions()` (line 185-230), the for-loop over tool calls uses bare `try` on JSONDecoder:

```swift
case "create_entries":
    let wrapper = try JSONDecoder().decode(CreateEntriesArguments.self, from: argumentsData)
    actions.append(contentsOf: wrapper.entries.map { .create($0.asAction) })
```

If the LLM returns `category: "grocery"` instead of `category: "list"`, the `EntryCategory` Decodable init throws → the entire `parseActions()` throws → `Pipeline.processWithAgent()` wraps it as `PipelineError.extractionFailed` → user sees error toast → all 5 tool calls lost.

The irony: `EntryCategory` already has a defensive initializer at `Enums.swift:28` that falls back to `.note`. But `Decodable` doesn't use it — it uses the synthesized `init(from:)` which throws on unknown raw values.

---

## 1. Per-Action Error Isolation

### Approach: do/catch inside the for-loop

The simplest fix. Wrap each tool call's decode in its own do/catch:

```swift
for toolCall in toolCalls {
    guard let function = toolCall["function"] as? [String: Any],
          let name = function["name"] as? String,
          let argumentsString = function["arguments"] as? String,
          let argumentsData = argumentsString.data(using: .utf8)
    else {
        continue
    }

    do {
        switch name {
        case "create_entries":
            let wrapper = try JSONDecoder().decode(CreateEntriesArguments.self, from: argumentsData)
            actions.append(contentsOf: wrapper.entries.map { .create($0.asAction) })
        // ... other cases
        default:
            continue
        }
    } catch {
        parseFailures.append(ParseFailure(toolName: name, error: error))
    }
}
```

### What about failures WITHIN a batch tool call?

A single `create_entries` call can contain multiple entries in its array. If one entry in the array is bad, the current Decodable decode fails the entire wrapper. Two options:

**Option A: Fail the whole tool call.** If `create_entries` has 3 entries and 1 is malformed, lose all 3 from that tool call but keep other tool calls. Simple, and the LLM typically uses one create call per batch anyway.

**Option B: Parse entries individually.** Decode the `entries` array manually — iterate the JSON array and decode each element in its own try/catch. More resilient but more code.

**Recommendation: Option A first.** The per-tool-call boundary is the natural isolation point. If we see real-world cases where the LLM stuffs many entries into one call and only one is bad, we can go to Option B later. Keep it simple.

### Error type

```swift
struct ParseFailure {
    let toolName: String
    let rawArguments: String  // for debugging
    let error: Error
}
```

Lightweight. Don't need to model what went wrong — the `Error` already carries that (DecodingError has path info).

### Return type change

`parseActions()` currently returns `[AgentAction]`. Change to:

```swift
struct ParseResult {
    let actions: [AgentAction]
    let failures: [ParseFailure]
}
```

This keeps the happy path clean — callers that don't care about failures just use `.actions`.

---

## 2. Defensive Decoding

### Category: custom Decodable init with fallback

`EntryCategory` already has the logic at `Enums.swift:28`:
```swift
public init(from rawValue: String) {
    self = EntryCategory(rawValue: rawValue) ?? .note
}
```

But this isn't the `Decodable` init. Add a custom `init(from decoder:)`:

```swift
public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    self = EntryCategory(rawValue: raw) ?? .note
}
```

If the LLM says `"grocery"`, we get `.note` instead of a crash. This is the right default — `.note` is the least-assuming category.

**Alternative considered:** map to closest match (Levenshtein distance, semantic similarity). Over-engineered for a voice app. If the LLM gets the category wrong, the user fixes it with one tap. `.note` as fallback is fine.

### HabitCadence: same pattern

Currently no defensive init. Add the same `init(from decoder:)` with `nil` fallback (since cadence is optional):

```swift
public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(String.self)
    guard let value = HabitCadence(rawValue: raw) else {
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown cadence: \(raw)")
    }
    self = value
}
```

Wait — cadence is `HabitCadence?` in the action types. If the LLM invents a cadence value, we'd rather drop it to nil than crash. But the `?` optional wrapping already handles the "key missing" case. The problem is when the key IS present but has a garbage value like `"biweekly"`.

**Better approach:** make the `RawCreateAction.cadence` decode defensively:

```swift
let cadence: HabitCadence?

init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    // ... other fields ...
    if let rawCadence = try container.decodeIfPresent(String.self, forKey: .cadence) {
        self.cadence = HabitCadence(rawValue: rawCadence)  // nil if unknown
    } else {
        self.cadence = nil
    }
}
```

This way unknown cadence values silently become nil rather than throwing. Since cadence is always optional, this is fine.

### AgentEntryStatus: same as category

Used in update_entries for status transitions. Fallback to `.active` makes sense — if the LLM sends a garbage status, treating it as "no status change" is safer than crashing. But actually, we should probably reject unknown statuses rather than silently defaulting, since a wrong status transition is worse than no transition. Let the per-tool-call isolation catch it.

**Decision:** Keep `AgentEntryStatus` strict (let it throw). The per-action error isolation will catch it, and the user will see the other actions succeed. An unknown status is likely a real bug worth surfacing.

### Priority: clamp to valid range

Priority is `Int?` — any integer decodes fine. But what range is valid? Looking at the UI:
- Entries use P1-P5 display convention (lower = more important)
- The sorting in `buildAgentUserContent` uses `?? 6` as default (lower than any real priority)

**Approach:** Clamp to 1-5 after decode, in `RawCreateAction.asAction` and `RawUpdateFields.asFields`:

```swift
let clampedPriority = priority.map { max(1, min(5, $0)) }
```

If the LLM says `priority: 0` or `priority: 99`, it becomes 1 or 5. No crash, reasonable behavior.

### Dates: already fine

`dueDateDescription` is a `String?` that gets resolved later by `NSDataDetector`. If it's garbage, resolution returns nil and no due date is set. No change needed.

### Short IDs: already fine

`Entry.resolve(shortID:in:)` returns nil on 0 or 2+ matches. The executor reports it as a failure. No change needed.

---

## 3. Partial Success UX

### Current state

`AgentActionExecutor` already supports partial success! It has `ExecutionResult.failures` and processes each action independently. The problem is upstream — `parseActions` throws before the executor ever sees the actions.

Once we fix `parseActions` to return `ParseResult`, we have TWO layers of partial failure:
1. **Parse failures** — tool calls that couldn't be decoded
2. **Execution failures** — actions that decoded but couldn't be applied (entry not found, etc.)

### What the user should see

**If everything succeeds:** Current behavior (success toast with summary).

**If some actions succeed, some fail (parse or execution):**
- Show the success toast for what worked
- Append a note: "2 actions couldn't be processed" (or similar)
- Don't show the raw error — it's a DecodingError stack trace, not user-readable

**If everything fails:**
- Show error toast: "Couldn't process your request. Try again?"

### Undo behavior

No change needed. `UndoTransaction` only contains items for actions that actually succeeded. The undo button already reverses exactly the successful set. Parse failures never made it to the executor, so they have no undo items.

### Implementation

The toast-showing code is in `RootView.showAgentToast()`. It currently checks `execResult.applied.isEmpty`. We'd expand it to also report `parseResult.failures.count + execResult.failures.count`:

```swift
let failCount = parseFailures.count + execResult.failures.count
if failCount > 0 && !execResult.applied.isEmpty {
    summary += " (\(failCount) couldn't be processed)"
}
```

Light touch. No modal, no detail view. Voice app — keep it fast.

---

## 4. Error Reporting to the Agent (Future: Multi-Turn)

### Current state

`updateConversation()` appends `"<tool> accepted."` for every tool call, regardless of actual outcome. If multi-turn were active, the LLM would think everything succeeded.

### What should change (when multi-turn lands)

For tool calls that failed to parse:
```json
{"role": "tool", "content": "create_entries failed: invalid category 'grocery'"}
```

For actions that parsed but failed execution:
```json
{"role": "tool", "content": "update_entries partially failed: entry abc123 not found"}
```

This gives the LLM a chance to retry or adjust.

### Should we do this now?

**No.** Multi-turn is wired but unused. Adding failure feedback to conversation history now would be dead code. When multi-turn is activated, this becomes essential — add it then.

**One thing to wire now:** make sure `ParseResult.failures` is accessible at the `process()` return level, so when multi-turn does land, the information is available without another refactor. This means `AgentResponse` should carry parse failures:

```swift
public struct AgentResponse: Sendable {
    public let actions: [AgentAction]
    public let parseFailures: [ParseFailure]  // NEW
    public let summary: String
    public let usage: TokenUsage
}
```

---

## 5. Summary: What to Actually Do

Ordered by impact and simplicity:

### Must do (fixes the user-facing bug)

1. **Wrap each tool call decode in do/catch** — per-action isolation in `parseActions()`. Return `ParseResult` instead of `[AgentAction]`.

2. **Defensive `EntryCategory` Decodable init** — fall back to `.note` on unknown values. The code for this literally already exists, just needs to be wired to the Decodable protocol.

3. **Clamp priority to 1-5** — one-liner in `asAction` / `asFields`.

### Should do (completes the story)

4. **Defensive cadence decoding** — unknown cadence becomes nil, not a throw. Custom decode in `RawCreateAction` and `RawUpdateFields`.

5. **Surface parse failure count in toast** — "3 created, 1 couldn't be processed". Small UX change.

6. **Carry `parseFailures` in `AgentResponse`** — future-proofs for multi-turn without adding dead code.

### Don't do yet

- Fuzzy category matching (over-engineered)
- Per-entry isolation within a single tool call (Option B above — wait for evidence)
- Feed failures back into conversation history (wait for multi-turn)
- Detailed failure UI (modal, expandable errors — not worth it for a voice app)

---

## 6. Risk Assessment

**Risk of the change:** Low. The defensive decoding changes are additive — they only affect error paths. The per-action isolation is a straightforward refactor of the for-loop. No changes to the happy path.

**Risk of NOT changing:** Medium. Every time the LLM hallucinates a category or returns a slightly-off field name, the user loses their entire voice input. This is the kind of thing that makes people stop using the app.

**Testing approach:**
- Unit test `parseActions` with one good tool call + one bad tool call → verify good one survives
- Unit test `EntryCategory(from decoder:)` with "grocery", "TODO", "" → verify fallback
- Unit test priority clamping with 0, -1, 99, 5, 1 → verify clamp

---

## Appendix: Current Error Path Trace

```
LLM returns: tool_calls: [create_entries({category: "grocery"}), complete_entries({id: "abc"})]
                                          ↓
PPQLLMService.parseActions()
  → for toolCall in toolCalls
    → case "create_entries": try JSONDecoder().decode(...)
      → EntryCategory.init(from decoder:) → unknown raw value "grocery" → THROWS
    → throw propagates out of parseActions()
                                          ↓
PPQLLMService.process()
  → let actions = try parseActions(from: turn.assistantMessage)  → THROWS
                                          ↓
Pipeline.processWithAgent()
  → catch → PipelineError.extractionFailed(underlying: DecodingError)
                                          ↓
RootView
  → shows error toast: "Entry extraction failed: ..."
  → user loses BOTH the create AND the complete ← this is the bug
```

After the fix:
```
LLM returns: tool_calls: [create_entries({category: "grocery"}), complete_entries({id: "abc"})]
                                          ↓
PPQLLMService.parseActions()
  → for toolCall in toolCalls
    → case "create_entries": EntryCategory.init(from decoder:) → "grocery" → .note (fallback)
    → case "complete_entries": decodes fine
  → returns ParseResult(actions: [.create(..., .note), .complete(...)], failures: [])
                                          ↓
AgentActionExecutor.execute()
  → both actions applied successfully
                                          ↓
User sees: "Created 1, completed 1" ← correct behavior
```
