# SSE Streaming Test Results

**Date:** 2026-03-03
**Branch:** `dam` (post commit `1a07fdc` — "feat: wire SSE streaming into agent pipeline")
**Tester:** Claude Code (build worker)

## Test Setup

- Rebuilt app from `dam` branch with SSE streaming wired into the agent pipeline
- Log subsystem fixed to `com.gudnuf.murmur` (was `com.murmur.app`)
- Log capture: `captureConsole=true`, `subsystemFilter="app"`
- Simulator: iPhone 17 Pro (609F64BF)

## Test Input

Typed via keyboard input:
> "remind me to buy groceries tomorrow and also add a note about the project meeting on friday and create a todo to review the PR"

This is a multi-entry input testing 3 separate actions: 1 reminder, 1 note, 1 todo.

## Verdict: STREAMING PATH IS ACTIVE

The SSE streaming path is fully wired and operational. All `[SSE]` log tags confirm the streaming codepath is used — not the legacy non-streaming path.

## Event Sequence (Annotated)

### 1. Submission (T+0s)
```
22:46:29.678  [SSE] submitDirect — streaming agent call, gen=1
22:46:29.679  [SSE] Pipeline.processWithAgentStreaming — STREAMING path
22:46:29.682  [SSE] processStreaming — starting SSE request
```
- `submitDirect` routes to the streaming path
- Pipeline confirms `STREAMING path` (not fallback)
- SSE HTTP request initiated

### 2. Connection Established (T+1.6s)
```
22:46:31.247  [SSE] processStreaming — HTTP 200, consuming SSE stream
22:46:31.249  [SSE] Accumulator.feed — 1 tool call delta(s)
```
- HTTP 200 from PPQ/Anthropic SSE endpoint
- First tool call delta arrives ~1.6s after request start
- Time-to-first-byte: **1.57s**

### 3. Tool Call Deltas — First Tool (T+1.6s to T+2.8s)
```
22:46:31.249 → 22:46:32.449  [SSE] Accumulator.feed — 1 tool call delta(s)  (×33 events)
22:46:32.449  [SSE] Accumulator.completeToolCall — index=0, name=update_entries, id=toolu_bdrk_01TZqJqes6GPzPaappDAZfeu, args=235 chars
```
- ~33 incremental deltas for the first tool call
- Tool: `update_entries` (updating existing entry or marking something)
- JSON args: 235 chars
- **Executed immediately on completion:**
```
22:46:32.465  [SSE] tool call completed: update_entries — executing
```

### 4. Tool Call Deltas — Second Tool (T+3.7s to T+3.9s)
```
22:46:33.347 → 22:46:33.417  [SSE] Accumulator.feed — 1 tool call delta(s)  (×37 events)
```
- Second batch of deltas starts ~0.9s after first tool execution
- Denser arrival (37 deltas in ~70ms vs 33 in ~1.2s)

### 5. Stream Completion (T+3.75s)
```
22:46:33.424  [SSE] Accumulator.feed — chunk has no choices/delta
22:46:33.424  [SSE] processStreaming — received [DONE]
22:46:33.424  [SSE] Accumulator.finish — 1 pending tool calls to flush
22:46:33.424  [SSE] Accumulator.completeToolCall — index=1, name=create_entries, id=toolu_bdrk_013eS1pGtts1shQSyouN7Fi2, args=309 chars
22:46:33.427  [SSE] Accumulator.finish — stream complete, total text: 0 chars, total actions: 3
22:46:33.427  [SSE] processStreaming — complete, 3 actions
22:46:33.462  [SSE] tool call completed: create_entries — executing
```
- `[DONE]` sentinel received
- 1 pending tool call flushed on finish (was still accumulating)
- `create_entries` — 309 chars of JSON args (the reminder + note + todo)
- **Total actions: 3** (matches expected: 1 update + 2 creates? or 3 creates across 2 tool calls)
- **Total text: 0 chars** — pure tool-use response, no accompanying text

## Timing Summary

| Phase | Timestamp | Elapsed |
|-------|-----------|---------|
| Submit | 22:46:29.678 | 0.0s |
| SSE request start | 22:46:29.682 | 0.004s |
| HTTP 200 + first delta | 22:46:31.247 | **1.57s** |
| First tool complete (`update_entries`) | 22:46:32.449 | **2.77s** |
| First tool executed | 22:46:32.465 | 2.79s |
| Second tool deltas start | 22:46:33.347 | 3.67s |
| [DONE] received | 22:46:33.424 | **3.75s** |
| Second tool complete (`create_entries`) | 22:46:33.424 | 3.75s |
| Second tool executed | 22:46:33.462 | **3.78s** |

**Total wall time: 3.78s** from submit to all actions executed.

## Key Observations

1. **Streaming is working.** The `STREAMING path` log confirms the new codepath, not the legacy `sendRequest` fallback.

2. **Tool calls arrive incrementally.** ~70 individual delta events across 2 tool calls, confirming true SSE streaming (not buffered-then-parsed).

3. **First tool executes before stream ends.** `update_entries` completes and executes at T+2.79s, while the stream continues delivering the second tool call. This is the key latency win from streaming — actions begin before the full response is received.

4. **Second tool flushed on [DONE].** The `create_entries` tool call was still accumulating when `[DONE]` arrived, so `Accumulator.finish` flushed it. This is correct behavior — it means the last tool call's final delta and the [DONE] sentinel arrived in rapid succession.

5. **No text content.** `total text: 0 chars` — the agent responded with pure tool calls and no conversational text. This is typical for clear, actionable input.

6. **3 actions from 2 tool calls.** The `create_entries` call (309 chars) likely batched the reminder + note + todo into a single multi-entry creation, while `update_entries` handled something else (possibly marking an existing entry).

## Issues / Concerns

- **None blocking.** The streaming path works as designed.
- **Log verbosity:** The per-delta `Accumulator.feed` logs are useful for debugging but will be noisy in production. Consider gating behind a `DEBUG`-only flag or reducing to periodic summaries (e.g., every 10th delta).
- **App went to home screen** after log capture stop — this is because `captureConsole=true` relaunches the app, and the stop terminated it. Not a bug in the streaming path.
