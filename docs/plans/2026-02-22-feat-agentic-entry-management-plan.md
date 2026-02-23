---
title: Agentic Entry Management
type: feat
status: active
date: 2026-02-22
brainstorm: docs/brainstorms/2026-02-22-agentic-entry-management-brainstorm.md
---

# Agentic Entry Management

Wire the existing agent protocol through the pipeline, build the action execution layer, and simplify the UI to three interactions: smart list, two gestures, and the mic.

## What's Already Built

The MurmurCore agent layer is ~90% complete but disconnected from the app:

- `MurmurAgent` protocol with `process(transcript:existingEntries:conversation:)` — `LLMService.swift:284`
- Four tool schemas: `create_entries`, `update_entries`, `complete_entries`, `archive_entries` — `LLMService.swift:387-539`
- All action types: `AgentAction` enum (.create/.update/.complete/.archive) — `LLMService.swift:245`
- Context injection: `buildAgentUserContent()` — `PPQLLMService.swift:312-336`
- System prompt: `LLMPrompt.entryManager` — `LLMService.swift:39-84`
- Response parsing for all action types — `PPQLLMService.swift:185-228`

Progressive disclosure (L0-L4) and disclosure settings already removed on `remove-progressive-disclosure` branch.

## Phase 1: Wire Agent Through Pipeline

Connect the built agent layer to the app flow.

### Pipeline Changes

- [ ] Add `processWithAgent(transcript:existingEntries:conversation:)` method to `Pipeline` that calls `llm.process()` instead of `llm.extractEntries()` — `Pipeline.swift`
- [ ] Return `AgentResponse` (actions + summary + usage) instead of `LLMResult`
- [ ] Remove the `guard !entries.isEmpty` check for the agent path — a response with zero creates but mutations is valid (`Pipeline.swift:194`)
- [ ] Handle `toolChoice: .auto` text-only responses: when LLM returns no tool calls, return `AgentResponse(actions: [], summary: textContent)` instead of throwing `PPQError.noToolCalls` — `PPQLLMService.swift:185`
- [ ] Credit charging uses `AgentResponse.usage` (same structure, different source)

### Entry-to-Context Bridge

- [ ] Add `Entry.toAgentContext()` -> `AgentContextEntry` mapping function in the app layer (Entry is SwiftData in the app, AgentContextEntry is in MurmurCore)
- [ ] Short ID = first 6 chars of `id.uuidString.lowercased()`
- [ ] Map `EntryStatus` -> `AgentEntryStatus`, include category/priority/dueDate/cadence/status

### RootView Flow Change

- [ ] On mic stop: fetch all active/snoozed entries, map to `[AgentContextEntry]`, call `processWithAgent()`
- [ ] On agent response: execute actions (Phase 2), show toast, return to idle
- [ ] Skip `RecordingState.confirming` entirely — go from `.processing` -> `.idle` + toast
- [ ] Retain `LLMConversation` for multi-turn (user speaks again within session)

## Phase 2: Action Execution Layer

The critical missing bridge between `AgentAction` and `Entry.perform()`.

### AgentActionExecutor

- [ ] Create `AgentActionExecutor` (new file in `Murmur/Services/`)
- [ ] Input: `[AgentAction]`, active `[Entry]`, `ModelContext`, `NotificationPreferences`
- [ ] Output: `ExecutionResult` containing applied actions, failed actions, and `UndoTransaction`

### Short ID Resolution

- [ ] `resolveEntry(shortID:in:)` — prefix match on `entry.id.uuidString`
- [ ] 0 matches: skip action, add to failures with "entry not found"
- [ ] 2+ matches: skip action, add to failures with "ambiguous ID"
- [ ] 1 match: proceed

### Action Handlers

- [ ] **Create**: insert new `Entry` from `CreateAction` fields, resolve dates via `Entry.resolveDate(from:)`
- [ ] **Update**: resolve short ID, apply `UpdateFields` to entry. Route status changes through `Entry.perform()` to maintain notification side effects. Direct field mutations (content, summary, priority, dueDate, category, cadence) applied inline.
- [ ] **Complete**: resolve short ID, call `entry.perform(.complete, ...)`. Idempotent — if already completed, skip.
- [ ] **Archive**: resolve short ID, call `entry.perform(.archive, ...)`. Idempotent — if already archived, skip.
- [ ] **Date resolution**: `UpdateFields.dueDateDescription` and `snoozeUntil` are natural language strings — resolve via `Entry.resolveDate(from:)` or `NSDataDetector`

### Undo Support

- [ ] `UndoTransaction` struct: snapshot of pre-mutation state for each applied action
  - Create: store inserted entry UUID (undo = delete)
  - Update: store changed field values before mutation (undo = restore)
  - Complete: store previous status + clear completedAt (undo = restore)
  - Archive: store previous status (undo = restore)
- [ ] `UndoTransaction.execute(context:preferences:)` — reverses all actions atomically
- [ ] Best-effort execution: each action independent, toast reports successes and failures

### Conflict Handling

- [ ] If agent returns both `complete` and `update` for same ID: complete takes precedence (update is moot)
- [ ] If agent returns ID not in context: skip with warning in toast
- [ ] Race condition (user swipes while agent processes): idempotent status checks prevent double-apply

## Phase 3: Simplified UI

Replace the current multi-screen UI with three interactions.

### Smart List (replaces category stacks in HomeView)

- [x] Flat sorted list of active entries — no category grouping, no tabs, no filters
- [x] Sort order: (1) overdue by staleness, (2) due today by time, (3) future due by proximity, (4) has priority by P value, (5) everything else by `createdAt` desc
- [x] Snoozed entries excluded (they reappear on wake-up)
- [x] Unified row design: category icon (left), summary text, optional due/priority badge (right)
- [ ] Remove: `FilterChips`, `CategoryListView`, `ViewsGridView`, category stack cards from HomeView

### Two Gestures (replaces multi-option swipe menus)

- [x] Swipe right = complete: shrink + fade vanish animation, list reflows
- [x] Swipe left = snooze (1hr default): slides away, reappears after snooze
- [x] Remove all other swipe options (archive, delete, edit from swipe menu)
- [ ] Add `accessibilityCustomAction("Complete")` and `accessibilityCustomAction("Snooze")` on every row — VoiceOver users need these since detail editor is going away

### Tap to Expand (replaces EntryDetailView navigation)

- [ ] Tap entry row -> inline expansion showing full content (read-only)
- [ ] No navigation to separate detail screen
- [ ] Remove: `EntryDetailView` as navigation destination, `EntryEditSheet`

### Response Toast (replaces ConfirmView)

- [x] Enhance `ToastView`/`ToastContainer` to support agent response toasts
- [x] Summary line from `AgentResponse.summary` ("completed 'grocery run', moved dentist to Friday")
- [x] "Undo" button with 10-second window
- [x] Tap to expand: show individual action list
- [x] Auto-dismiss timer pauses on expansion
- [x] `ToastConfig` holds `AgentResponse` + `UndoTransaction`
- [x] Remove: `ConfirmView` card-by-card flow

### Screen Removal

- [x] Remove `ArchiveView` tab from `BottomNavBar` (two tabs: Home + Settings, center mic)
- [x] Keep `TextInputView` as accessibility fallback — route text through same `process()` agent path
- [x] Remove `FocusCardView` (no longer needed without detail navigation)

### Recording Flow Simplification

- [x] Remove `RecordingState.confirming` — after processing, go to `.idle` + toast
- [x] Keep `RecordingState.recording` and `.processing` as-is
- [ ] Multi-turn: if user taps mic within conversation window, pass existing `LLMConversation`

## Phase 4: Daily Brief

- [x] Computed property on active entries: count overdue, due today, due this week, by category
- [x] Format as 1-line string: "3 due today, 1 overdue, 2 new ideas this week"
- [x] Pin at top of smart list as a non-interactive header
- [x] Update immediately after any action execution
- [x] v1 is locally computed — no LLM call

## Acceptance Criteria

- [x] Voice input creates/updates/completes/archives entries via agent (no confirmation screen)
- [x] Toast shows agent summary with working undo (10s window)
- [x] Smart list shows flat sorted entries (no category grouping)
- [x] Swipe right completes with vanish animation
- [x] Swipe left snoozes for 1 hour
- [ ] Tap expands entry inline (read-only)
- [x] Daily brief pinned at top of list
- [x] Text input still works as accessibility path (routed through agent)
- [ ] VoiceOver custom actions for complete/snooze on every row
- [ ] Multi-turn voice ("actually undo that") works within conversation session
- [x] Existing entries work without migration (data model unchanged)

## Context

- Brainstorm: `docs/brainstorms/2026-02-22-agentic-entry-management-brainstorm.md`
- Pipeline refactor plan: `docs/plans/2026-02-21-refactor-two-phase-pipeline-stop-plan.md`
- Toast fix plan: `docs/plans/2026-02-21-fix-empty-transcript-and-toast-timeout-plan.md`
- Post-MVP refactor: `docs/2026-02-18-post-mvp-refactoring-plan.md` (CaptureCoordinator extraction)

## Key Files

| File | Role |
|------|------|
| `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift` | Agent protocol, action types, tool schemas, prompts |
| `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift` | PPQ implementation of process(), context injection, parsing |
| `Packages/MurmurCore/Sources/MurmurCore/Pipeline.swift` | Recording pipeline (needs agent path) |
| `Murmur/Models/Entry.swift` | SwiftData model, EntryAction.perform() |
| `Murmur/Views/Home/HomeView.swift` | Current category stacks -> smart list |
| `Murmur/Views/RootView.swift` | State machine, capture flow orchestration |
| `Murmur/Components/ToastView.swift` | Current toast -> agent response toast |
| `Murmur/Components/BottomNavBar.swift` | Tab bar (remove archive tab) |
| `Murmur/Views/Capture/ConfirmView.swift` | To be removed (replaced by toast) |

## Open Questions (from brainstorm, deferred)

- **Token budget**: how many active entries before truncation? Measure and set threshold.
- **Conversation lifecycle**: when does multi-turn context reset? (timeout? navigation? explicit?)
- **Completed entry access**: v1 has no way to view completed/archived entries. Acceptable for now?
- **Undo stacking**: if user triggers two rapid agent responses, can both be undone independently?
