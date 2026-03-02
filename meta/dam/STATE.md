# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- Agent backend systems shipped: temporal context, agent memory, multi-turn plumbing, tool results
- Next: wiring agent overlay UX, conversation thread UI, or token budget work

## Recent decisions

- `cancelRecording()` over `stopRecording()` in agent path (speed over completeness)
- Per-tool-call error isolation over all-or-nothing (one bad tool call shouldn't nuke the batch)
- Multi-turn is in-memory only — app termination resets conversation naturally
- Tool results use real outcomes via `ToolResultBuilder` + `conversation.replaceToolResults()` — agent sees actual execution results, not synthetic "accepted"
- Agent memory: file-based `AgentMemoryStore` in Documents dir, loaded into `llm.agentMemory` on AppState init
- Temporal context: `SessionSummaryService` provides time-of-day + session history block injected into system prompt
- `ToolCallGroup` maps tool_call_id → action range for per-call error isolation
- `transcriptStream` on LLMService protocol for real-time streaming to overlay

## Open questions

- How should conversation reset work beyond app termination? Timer? Explicit button? After N seconds of silence?
- Category simplification (8 categories → fewer) — still unowned on the roadmap
- Token budget: how many entries in context before we need to truncate?

## What I need from sac

- Review agent-systems PR — thinking section covers architectural rationale
- Coordinate on HomeView changes — sac's visual polish PR (#65) is open
