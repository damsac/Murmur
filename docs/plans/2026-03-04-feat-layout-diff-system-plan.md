---
title: "feat: Layout Diff System for Composable Home View"
type: feat
status: active
date: 2026-03-04
brainstorm: docs/brainstorms/2026-03-04-entry-placement-hints-brainstorm.md
evolved-from: docs/plans/2026-03-04-feat-composable-ai-home-view-plan.md
---

# Layout Diff System for Composable Home View

## Overview

Evolve the composable home view from one-shot `compose_view` recomposition to an incremental diff system. Two new agent tools — `get_current_layout` (read) and `update_layout` (write diffs) — give the agent surgical control over the home screen. Each operation maps directly to a SwiftUI animation. Cold start and incremental updates use the same primitive: diffs.

**Why this matters:** `compose_view` regenerates the entire layout on every call. This is wasteful (full token cost), lossy (shuffles things the user liked), and animation-hostile (can't animate what you don't know changed). Diffs solve all three: token-efficient, surgical, and animation-native.

**Migration strategy:** `compose_view` continues working throughout. It populates the initial composition on app launch. The diff tools are additive — the agent gains new capabilities without losing existing ones. Eventually the agent handles cold start via diffs too, and `compose_view` becomes the one-shot fallback.

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────────────────┐
│ MurmurCore (no @MainActor)                          │
│                                                     │
│   HomeComposition (mutable struct)                  │
│     sections: [ComposedSection]                     │
│     composedAt: Date                                │
│     mutating apply(ops:) → LayoutDiff               │
│                                                     │
│   LayoutOperation (enum, 7 cases)                   │
│   LayoutDiff (struct, animation hints)              │
│                                                     │
│   LLMPrompt.entryManager (updated tools list)       │
│   get_current_layout / update_layout tool schemas   │
│   AgentAction.layoutRead / .layoutUpdate cases      │
├─────────────────────────────────────────────────────┤
│ App Layer (@MainActor)                              │
│                                                     │
│   AppState                                          │
│     homeComposition: HomeComposition?                │
│     applyLayoutUpdate(ops:) → LayoutDiff            │
│                                                     │
│   AgentActionExecutor                               │
│     case .layoutRead → return current JSON           │
│     case .layoutUpdate → apply + animate             │
│                                                     │
│   ConversationState                                 │
│     consumeAgentStream handles layout tool calls     │
│                                                     │
│   DamHomeView                                       │
│     Uses LayoutDiff for targeted animations          │
│     matchedGeometryEffect for moves                 │
│     Staggered arrival for batch inserts             │
└─────────────────────────────────────────────────────┘
```

---

## Phase 1: MurmurCore Data Model

Make `HomeComposition` mutable and add the diff engine. All changes in `Packages/MurmurCore/`.

### 1.1 LayoutOperation Enum

**File:** `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift`

Add below existing types:

```swift
/// A single operation in a layout diff batch.
public enum LayoutOperation: Sendable {
    case addSection(title: String, density: SectionDensity, position: Int?)
    case removeSection(title: String)
    case updateSection(title: String, density: SectionDensity?, newTitle: String?)
    case insertEntry(entryID: String, section: String, position: Int?,
                     emphasis: EntryEmphasis, badge: String?)
    case removeEntry(entryID: String)
    case moveEntry(entryID: String, toSection: String, toPosition: Int?)
    case updateEntry(entryID: String, emphasis: EntryEmphasis?, badge: String?)
}
```

**Design notes:**
- Section identification is by `title` (case-insensitive `.lowercased()` match). Titles are unique within a composition.
- `position` is 0-indexed, optional. `nil` = append to end.
- `removeEntry` needs only the entry ID — searches all sections.
- `moveEntry` removes from current section and inserts into `toSection`.
- **Title optionality:** `ComposedSection.title` is currently `String?`. Consider making it `String` since titleless sections are untargetable by the diff system. For now, `findSection` treats `nil` titles as empty string `""` for matching.

- [ ] Add `LayoutOperation` enum to `HomeComposition.swift`
- [ ] `LayoutOperation` does NOT need `Codable` — it's decoded via `RawLayoutOperation` in Phase 2, never serialized

### 1.2 LayoutDiff Return Type

**File:** `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift`

```swift
/// Describes what changed after applying operations. Used by the UI for targeted animations.
/// Also serves as its own accumulator during apply() — no separate DiffAccumulator needed.
public struct LayoutDiff: Sendable {
    public private(set) var insertedEntries: [(id: String, section: String)] = []
    public private(set) var removedEntries: [String] = []
    public private(set) var movedEntries: [(id: String, fromSection: String, toSection: String)] = []
    public private(set) var updatedEntries: [String] = []
    public private(set) var addedSections: [String] = []
    public private(set) var removedSections: [String] = []
    public private(set) var updatedSections: [String] = []

    public var isEmpty: Bool {
        insertedEntries.isEmpty && removedEntries.isEmpty && movedEntries.isEmpty
            && updatedEntries.isEmpty && addedSections.isEmpty && removedSections.isEmpty
            && updatedSections.isEmpty
    }

    public init() {}
}
```

**Note:** `LayoutDiff` doubles as its own accumulator — no separate `DiffAccumulator` type needed. Use `private(set) var` so `apply()` can mutate it directly, but callers only read.
```

- [ ] Add `LayoutDiff` struct to `HomeComposition.swift`

### 1.3 Make HomeComposition Mutable

**File:** `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift`

Change `HomeComposition` from immutable `let` properties to mutable:

```swift
public struct HomeComposition: Codable, Sendable {
    public var sections: [ComposedSection]  // was: let
    public var composedAt: Date             // was: let

    // ... existing isFromToday, init ...

    /// Apply a batch of operations in order. Returns a diff for animation.
    public mutating func apply(operations: [LayoutOperation]) -> LayoutDiff {
        var diff = LayoutDiff()
        for op in operations {
            applyOne(op, diff: &diff)
        }
        composedAt = Date()
        return diff
    }
}
```

Also make `ComposedSection` mutable:

```swift
public struct ComposedSection: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String?       // was: let
    public var density: SectionDensity  // was: let
    public var items: [ComposedItem]    // was: let
    // ... rest unchanged ...
}
```

**Implementation of `applyOne`** (private, within `HomeComposition`):

```swift
private mutating func applyOne(_ op: LayoutOperation, diff: inout LayoutDiff) {
    switch op {
    case .addSection(let title, let density, let position):
        let section = ComposedSection(title: title, density: density, items: [])
        let idx = position.map { min($0, sections.count) } ?? sections.count
        sections.insert(section, at: idx)
        diff.addedSections.append(title)

    case .removeSection(let title):
        if let idx = findSection(title: title) {
            // Collect removed entry IDs for diff
            for item in sections[idx].items {
                if case .entry(let e) = item { diff.removedEntries.append(e.id) }
            }
            sections.remove(at: idx)
            diff.removedSections.append(title)
        }

    case .updateSection(let title, let density, let newTitle):
        if let idx = findSection(title: title) {
            if let density { sections[idx].density = density }
            if let newTitle { sections[idx].title = newTitle }
            diff.updatedSections.append(newTitle ?? title)
        }

    case .insertEntry(let entryID, let section, let position, let emphasis, let badge):
        if let idx = findSection(title: section) {
            let entry = ComposedEntry(id: entryID, emphasis: emphasis, badge: badge)
            let item = ComposedItem.entry(entry)
            let pos = position.map { min($0, sections[idx].items.count) }
                ?? sections[idx].items.count
            sections[idx].items.insert(item, at: pos)
            diff.insertedEntries.append((id: entryID, section: section))
        }
        // Fail silently if section doesn't exist — entry falls to recentInserts

    case .removeEntry(let entryID):
        for sIdx in sections.indices {
            if let iIdx = sections[sIdx].items.firstIndex(where: {
                if case .entry(let e) = $0 { return e.id == entryID }
                return false
            }) {
                sections[sIdx].items.remove(at: iIdx)
                diff.removedEntries.append(entryID)
                break
            }
        }

    case .moveEntry(let entryID, let toSection, let toPosition):
        // CRITICAL: Verify target section exists BEFORE removing from source.
        // Without this guard, the entry would be destroyed if the target is invalid.
        guard let targetIdx = findSection(title: toSection) else { return }

        // Find and remove from current location
        var movedItem: ComposedItem?
        var fromSectionTitle: String?
        for sIdx in sections.indices {
            if let iIdx = sections[sIdx].items.firstIndex(where: {
                if case .entry(let e) = $0 { return e.id == entryID }
                return false
            }) {
                movedItem = sections[sIdx].items.remove(at: iIdx)
                fromSectionTitle = sections[sIdx].title ?? "untitled"
                break
            }
        }
        // Insert into target section (targetIdx already validated)
        if let item = movedItem {
            let pos = toPosition.map { min($0, sections[targetIdx].items.count) }
                ?? sections[targetIdx].items.count
            sections[targetIdx].items.insert(item, at: pos)
            diff.movedEntries.append((
                id: entryID,
                fromSection: fromSectionTitle ?? "unknown",
                toSection: toSection
            ))
        }

    case .updateEntry(let entryID, let emphasis, let badge):
        for sIdx in sections.indices {
            if let iIdx = sections[sIdx].items.firstIndex(where: {
                if case .entry(let e) = $0 { return e.id == entryID }
                return false
            }) {
                if case .entry(var entry) = sections[sIdx].items[iIdx] {
                    if let emphasis { entry = ComposedEntry(id: entry.id, emphasis: emphasis, badge: entry.badge) }
                    if let badge { entry = ComposedEntry(id: entry.id, emphasis: entry.emphasis, badge: badge) }
                    sections[sIdx].items[iIdx] = .entry(entry)
                    diff.updatedEntries.append(entryID)
                }
                break
            }
        }
    }
}

private func findSection(title: String) -> Int? {
    let target = title.lowercased()
    return sections.firstIndex { ($0.title ?? "").lowercased() == target }
}
```

- [ ] Change `HomeComposition.sections` and `composedAt` from `let` to `var`
- [ ] Change `ComposedSection.title`, `density`, `items` from `let` to `var`
- [ ] Add `apply(operations:) -> LayoutDiff` mutating method
- [ ] Add `findSection(title:)` helper (`.lowercased()` comparison — simpler than locale-sensitive compare for agent-generated strings)
- [ ] `moveEntry` MUST guard target section exists before removing from source (prevents data loss)

### 1.4 Make ComposedEntry Mutable for updateEntry

`ComposedEntry` is currently a struct with `let` properties. Since `updateEntry` needs to modify emphasis/badge, either:
- Option A: Reconstruct with new values (shown above — creates new `ComposedEntry` instances)
- Option B: Change to `var` properties

**Chosen: Option A** — keeps `ComposedEntry` immutable externally, reconstruction is cheap.

No changes needed to `ComposedEntry` itself.

### 1.5 Unit Tests

**File:** `Packages/MurmurCore/Tests/MurmurCoreTests/HomeCompositionTests.swift`

Add a new `@Suite("LayoutOperations")` section:

```swift
@Suite("LayoutOperations")
struct LayoutOperationTests {
    // MARK: - Section Operations

    @Test("add_section appends to end when no position")
    func addSectionAppend() { ... }

    @Test("add_section inserts at position")
    func addSectionAtPosition() { ... }

    @Test("remove_section removes section and reports removed entries")
    func removeSection() { ... }

    @Test("remove_section is no-op for unknown title")
    func removeSectionUnknown() { ... }

    @Test("update_section changes density")
    func updateSectionDensity() { ... }

    @Test("update_section renames title")
    func updateSectionRename() { ... }

    // MARK: - Entry Operations

    @Test("insert_entry appends when no position")
    func insertEntryAppend() { ... }

    @Test("insert_entry at position 0")
    func insertEntryAtZero() { ... }

    @Test("insert_entry into nonexistent section is silent no-op")
    func insertEntryBadSection() { ... }

    @Test("remove_entry removes from any section")
    func removeEntry() { ... }

    @Test("remove_entry is no-op for unknown entry")
    func removeEntryUnknown() { ... }

    @Test("move_entry between sections")
    func moveEntry() { ... }

    @Test("move_entry to position")
    func moveEntryWithPosition() { ... }

    @Test("update_entry changes emphasis")
    func updateEntryEmphasis() { ... }

    @Test("update_entry changes badge")
    func updateEntryBadge() { ... }

    // MARK: - Batch Operations

    @Test("batch operations applied in order")
    func batchOrder() { ... }

    @Test("cold start: add sections + insert entries from empty")
    func coldStartBatch() { ... }

    @Test("LayoutDiff reports all changes correctly")
    func diffAccuracy() { ... }

    // MARK: - Edge Cases

    @Test("position beyond bounds clamps to end")
    func positionClamping() { ... }

    @Test("section title matching is case-insensitive")
    func caseInsensitiveTitle() { ... }

    @Test("removing last entry from section leaves section intact")
    func removeLastEntry() { ... }

    @Test("composedAt is updated after apply")
    func composedAtUpdated() { ... }

    @Test("move entry to nonexistent section is no-op — entry preserved")
    func moveEntryBadTarget() { ... }

    @Test("rename section then insert into new name works")
    func renameThenInsert() { ... }

    @Test("add section with duplicate title creates second section")
    func duplicateSectionTitle() { ... }

    @Test("insert entry that already exists in another section is no-op or allowed")
    func duplicateEntryID() { ... }

    @Test("remove section that was just added in same batch")
    func addThenRemoveSection() { ... }

    @Test("empty operations array returns empty diff")
    func emptyOperations() { ... }
}
```

- [ ] Write 24+ unit tests covering all operation types, edge cases, batch scenarios, and defensive guards
- [ ] Tests run with `make core-test`

### Phase 1 Acceptance Criteria

- [x] `HomeComposition` is mutable with `apply(operations:)` → `LayoutDiff`
- [x] All 7 `LayoutOperation` types implemented with correct behavior
- [x] `LayoutDiff` accurately reports all changes
- [x] Existing `compose_view` path still works (one-shot recompose still builds `HomeComposition` from tool output)
- [x] `HomeCompositionStore` can save/load mutable compositions (already works — Codable unchanged)
- [x] All existing `HomeCompositionTests` still pass
- [x] All new `LayoutOperationTests` pass
- [x] `make core-test` passes

---

## Phase 2: Tool Schemas + Agent Integration

Wire the layout tools into the agent pipeline alongside existing entry tools.

### 2.1 AgentAction Cases

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

Add two new `AgentAction` cases:

```swift
public enum AgentAction: Sendable {
    // ... existing cases ...
    case layoutRead                           // get_current_layout
    case layoutUpdate([LayoutOperation])      // update_layout with operations
}
```

- [x] Add `.layoutRead` and `.layoutUpdate([LayoutOperation])` to `AgentAction`

### 2.2 Tool Schemas

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

Add two new schema functions following the pattern of `composeViewToolSchema()` (line 746):

```swift
static func getCurrentLayoutToolSchema() -> [String: Any] {
    [
        "type": "function",
        "function": [
            "name": "get_current_layout",
            "description": "Read the current home screen layout. Returns sections with their entries, emphasis levels, and badges. Call this before update_layout to understand what's on screen.",
            "parameters": [
                "type": "object",
                "properties": [:] as [String: Any],
            ] as [String: Any],
        ] as [String: Any],
    ]
}

static func updateLayoutToolSchema() -> [String: Any] {
    [
        "type": "function",
        "function": [
            "name": "update_layout",
            "description": """
                Apply incremental changes to the home screen layout. Operations are applied in order as a single animated transaction.
                Use after create_entries/complete_entries/update_entries to place or remove entries on screen.
                For a fresh layout (cold start), use a batch of add_section + insert_entry operations.
                """,
            "parameters": [
                "type": "object",
                "properties": [
                    "operations": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "op": [
                                    "type": "string",
                                    "enum": ["add_section", "remove_section", "update_section",
                                             "insert_entry", "remove_entry", "move_entry", "update_entry"],
                                ],
                                "title": ["type": "string", "description": "Section title (for section ops)"],
                                "density": ["type": "string", "enum": ["compact", "relaxed"]],
                                "position": ["type": "integer", "description": "0-indexed position (optional, omit to append)"],
                                "new_title": ["type": "string", "description": "New title for update_section"],
                                "entry_id": ["type": "string", "description": "Entry short ID (for entry ops)"],
                                "section": ["type": "string", "description": "Target section title (for insert_entry)"],
                                "to_section": ["type": "string", "description": "Destination section (for move_entry)"],
                                "to_position": ["type": "integer", "description": "Destination position (for move_entry)"],
                                "emphasis": ["type": "string", "enum": ["hero", "standard", "compact"]],
                                "badge": ["type": "string", "description": "Badge text: Overdue, Today, New, Stale, etc."],
                            ] as [String: Any],
                            "required": ["op"],
                        ] as [String: Any],
                    ] as [String: Any],
                ],
                "required": ["operations"],
            ] as [String: Any],
        ] as [String: Any],
    ]
}
```

- [x] Add `getCurrentLayoutToolSchema()` to `LLMPrompt`
- [x] Add `updateLayoutToolSchema()` to `LLMPrompt`

### 2.3 Add Layout Tools to entryManager Prompt

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

Update `LLMPrompt.entryManager` tools list (line 113):

```swift
tools: [
    createEntriesToolSchema(),
    updateEntriesToolSchema(),
    completeEntriesToolSchema(),
    archiveEntriesToolSchema(),
    updateMemoryToolSchema(),
    confirmActionsToolSchema(),
    getCurrentLayoutToolSchema(),   // NEW
    updateLayoutToolSchema(),       // NEW
],
```

Add to the system prompt (after existing output rules):

```
Layout tools:
- After creating/completing/updating entries, call get_current_layout to see the current home screen.
- Then call update_layout to place new entries or remove completed ones from the layout.
- If the layout is empty (cold start), compose a full layout with add_section + insert_entry operations.
- Keep the layout focused: 3-5 sections, 5-15 items total.
- Use insert_entry to add new entries to the appropriate section.
- Use remove_entry after completing/archiving entries.
- Use move_entry when an entry's urgency changes (e.g., becomes overdue).
- Calling update_layout is optional — entries without placement appear in a "recent" area above the layout.
```

- [x] Add layout tool schemas to `entryManager` tools array
- [x] Add layout tool guidance to `entryManager` system prompt

### 2.4 Parse Layout Tool Calls

**File:** `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift`

In `parseActions(from:)` (line 483), add cases for the new tools:

```swift
case "get_current_layout":
    actions.append(.layoutRead)

case "update_layout":
    let wrapper = try JSONDecoder().decode(UpdateLayoutArguments.self, from: argumentsData)
    let operations = wrapper.operations.compactMap { $0.asOperation }
    actions.append(.layoutUpdate(operations))
```

Add decoding types:

```swift
private struct UpdateLayoutArguments: Decodable {
    let operations: [RawLayoutOperation]
}

private struct RawLayoutOperation: Decodable {
    let op: String
    let title: String?
    let density: String?
    let position: Int?
    let newTitle: String?
    let entryId: String?
    let section: String?
    let toSection: String?
    let toPosition: Int?
    let emphasis: String?
    let badge: String?

    enum CodingKeys: String, CodingKey {
        case op, title, density, position
        case newTitle = "new_title"
        case entryId = "entry_id"
        case section
        case toSection = "to_section"
        case toPosition = "to_position"
        case emphasis, badge
    }

    var asOperation: LayoutOperation? {
        switch op {
        case "add_section":
            guard let title else { return nil }
            let d = density.flatMap { SectionDensity(rawValue: $0) } ?? .relaxed
            return .addSection(title: title, density: d, position: position)
        case "remove_section":
            guard let title else { return nil }
            return .removeSection(title: title)
        case "update_section":
            guard let title else { return nil }
            let d = density.flatMap { SectionDensity(rawValue: $0) }
            return .updateSection(title: title, density: d, newTitle: newTitle)
        case "insert_entry":
            guard let entryId, let section else { return nil }
            let e = emphasis.flatMap { EntryEmphasis(rawValue: $0) } ?? .standard
            return .insertEntry(entryID: entryId, section: section, position: position, emphasis: e, badge: badge)
        case "remove_entry":
            guard let entryId else { return nil }
            return .removeEntry(entryID: entryId)
        case "move_entry":
            guard let entryId, let toSection else { return nil }
            return .moveEntry(entryID: entryId, toSection: toSection, toPosition: toPosition)
        case "update_entry":
            guard let entryId else { return nil }
            let e = emphasis.flatMap { EntryEmphasis(rawValue: $0) }
            return .updateEntry(entryID: entryId, emphasis: e, badge: badge)
        default:
            return nil
        }
    }
}
```

- [x] Add `"get_current_layout"` and `"update_layout"` cases to `parseActions`
- [x] Add `UpdateLayoutArguments` and `RawLayoutOperation` decoding types
- [x] Add `asOperation` conversion with defensive nil-coalescing

### 2.5 Execute Layout Actions in AgentActionExecutor

**File:** `Murmur/Services/AgentActionExecutor.swift`

Add handling for the two new action types. These are different from entry actions — they don't operate on SwiftData entries, they operate on `AppState.homeComposition`.

Add a new `ActionOutcome` case:

```swift
enum ActionOutcome {
    // ... existing ...
    case layoutRead(json: String)
    case layoutUpdated(diff: LayoutDiff)
}
```

In `executeOne(_:context:completedIDs:)`, add:

```swift
case .layoutRead:
    let json = buildCurrentLayoutJSON(context: ctx)
    return .layoutRead(json: json)

case .layoutUpdate(let operations):
    guard var composition = ctx.appState?.homeComposition else {
        // No composition yet — create empty one and apply
        var empty = HomeComposition(sections: [])
        let diff = empty.apply(operations: operations)
        ctx.appState?.homeComposition = empty
        ctx.appState?.homeCompositionStore?.save(empty)
        return .layoutUpdated(diff: diff)
    }
    let diff = composition.apply(operations: operations)
    ctx.appState?.homeComposition = composition
    ctx.appState?.homeCompositionStore?.save(composition)
    return .layoutUpdated(diff: diff)
```

**Note:** `ExecutionContext` needs a reference to `AppState` for layout operations. Add:

```swift
struct ExecutionContext {
    // ... existing ...
    weak var appState: AppState?  // NEW — needed for layout operations
}
```

`buildCurrentLayoutJSON` serializes the current composition to the JSON format the agent expects:

```swift
private static func buildCurrentLayoutJSON(context ctx: ExecutionContext) -> String {
    guard let composition = ctx.appState?.homeComposition else {
        return #"{"sections":[]}"#
    }
    guard let data = try? JSONEncoder().encode(composition),
          let json = String(data: data, encoding: .utf8) else {
        return #"{"sections":[]}"#
    }
    return json
}
```

- [x] Add `appState` weak reference to `ExecutionContext`
- [x] Add `.layoutRead` and `.layoutUpdate` cases to `ActionOutcome`
- [x] Handle `.layoutRead` → serialize current composition to JSON
- [x] Handle `.layoutUpdate` → apply operations, return diff
- [x] Update `ExecutionContext` initialization in `ConversationState.submitDirect` to pass `appState`

### 2.6 Wire Tool Results for Layout Tools

**File:** `Murmur/Services/ToolResultBuilder.swift`

Layout tool results need to be fed back to the agent conversation so the agent sees the outcome:

- `get_current_layout` → return the JSON layout as tool result content
- `update_layout` → return confirmation like `"Applied 3 operations: 1 section added, 2 entries inserted"`

Update `ToolResultBuilder.build()` to handle the new outcome types:

```swift
case .layoutRead(let json):
    return json
case .layoutUpdated(let diff):
    return buildLayoutUpdateConfirmation(diff)
```

```swift
private static func buildLayoutUpdateConfirmation(_ diff: LayoutDiff) -> String {
    var parts: [String] = []
    if !diff.addedSections.isEmpty { parts.append("\(diff.addedSections.count) section(s) added") }
    if !diff.removedSections.isEmpty { parts.append("\(diff.removedSections.count) section(s) removed") }
    if !diff.insertedEntries.isEmpty { parts.append("\(diff.insertedEntries.count) entry(ies) inserted") }
    if !diff.removedEntries.isEmpty { parts.append("\(diff.removedEntries.count) entry(ies) removed") }
    if !diff.movedEntries.isEmpty { parts.append("\(diff.movedEntries.count) entry(ies) moved") }
    if !diff.updatedEntries.isEmpty { parts.append("\(diff.updatedEntries.count) entry(ies) updated") }
    return parts.isEmpty ? "No changes applied." : "Layout updated: " + parts.joined(separator: ", ") + "."
}
```

- [x] Handle `.layoutRead` and `.layoutUpdated` outcomes in `ToolResultBuilder`
- [x] Build human-readable confirmation string for `update_layout` results

### 2.7 Handle Layout Updates in ConversationState

**File:** `Murmur/Services/ConversationState.swift`

In `consumeAgentStream`, after `AgentActionExecutor.execute()` (line 335), clear `recentInserts` for entries that are now placed by the layout:

```swift
// After executing actions, clear recentInserts for entries placed by layout
for outcome in execResult.outcomes {
    if case .layoutUpdated(let diff) = outcome {
        for (id, _) in diff.insertedEntries {
            appState.clearRecentInsertForEntry(shortID: id, entries: entries)
        }
    }
}
```

Animation handling (stagger, matchedGeometry) is deferred to Phase 3 — no stub code here.

- [x] Clear `recentInserts` for entries placed via `update_layout`
- [x] Add `clearRecentInsertForEntry(shortID:entries:)` helper to `AppState`

### Phase 2 Acceptance Criteria

- [x] `get_current_layout` returns correct JSON of current composition state
- [x] `get_current_layout` returns `{"sections":[]}` when composition is empty
- [x] `update_layout` applies operations and persists updated composition
- [x] `update_layout` from empty state creates composition (cold start)
- [x] Agent can call `get_current_layout` → `update_layout` in sequence during a conversation turn
- [x] Layout changes appear in DamHomeView (composition is @Observable, SwiftUI updates)
- [x] Tool results are correctly fed back to agent conversation history
- [x] Existing entry tools (create/update/complete/archive) still work unchanged
- [x] Existing `compose_view` one-shot path still works for app-open composition
- [x] `make build` succeeds, `make core-test` passes

---

## Phase 3: DamHomeView Animations

Use `LayoutDiff` to drive targeted SwiftUI animations instead of whole-view transitions.

### 3.1 Animation Namespace

**File:** `Murmur/Views/Home/DamHomeView.swift`

Add matched geometry namespace for move animations:

```swift
@Namespace private var layoutNamespace
```

Pass entry IDs as matched geometry IDs:

```swift
// In ComposedEntryView, wrap the view with:
.matchedGeometryEffect(id: "entry-\(entry.shortID)", in: layoutNamespace)
```

- [x] Add `@Namespace` to `DamHomeView`
- [x] Pass namespace to `ComposedSectionView` and `ComposedEntryView`
- [x] Apply `matchedGeometryEffect` to entry views using short ID

### 3.2 Animation Types per Operation

Map each diff type to a SwiftUI animation:

| Diff | Animation | Implementation |
|------|-----------|---------------|
| `insertedEntries` | Fade in + scale spring | `.transition(.opacity.combined(with: .scale(scale: 0.95)))` with `.spring(response: 0.4, dampingFraction: 0.8)` |
| `removedEntries` | Fade out + scale down | `.transition(.opacity.combined(with: .scale(scale: 0.95)))` |
| `movedEntries` | matchedGeometryEffect | Automatic via `@Namespace` — SwiftUI interpolates position |
| `updatedEntries` | Cross-fade | `.animation(.easeInOut(duration: 0.3))` on emphasis/badge changes |
| `addedSections` | Section slides in | `.transition(.move(edge: .top).combined(with: .opacity))` |
| `removedSections` | Section collapses | `.transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))` |

### 3.3 Staggered Arrival for Batch Inserts (Cold Start)

**File:** `Murmur/Views/Home/DamHomeView.swift`

When the composition goes from nil → populated (cold start batch), stagger entry reveals:

```swift
// Track which entries are revealed (for stagger animation)
@State private var revealedEntryIDs: Set<String> = []

// In ComposedEntryView: only render if revealed
if revealedEntryIDs.contains(entry.shortID) {
    // ... entry view ...
}

// On composition change, stagger reveals
.onChange(of: appState.homeComposition?.sections.count) {
    staggerRevealEntries()
}
```

```swift
private func staggerRevealEntries() {
    guard let composition = appState.homeComposition else { return }
    let allEntryIDs = composition.sections.flatMap { section in
        section.items.compactMap { item in
            if case .entry(let e) = item { return e.id }
            return nil
        }
    }

    for (index, id) in allEntryIDs.enumerated() {
        let delay = Double(index) * 0.06  // 60ms stagger
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                revealedEntryIDs.insert(id)
            }
        }
    }
}
```

- [x] Add stagger reveal state tracking to `DamHomeView`
- [x] Implement 60ms staggered reveal for cold start batch inserts
- [x] Only apply stagger on initial composition (not on incremental updates)

### 3.4 recentInserts Fallback

Entries created by the agent that don't get an `insert_entry` operation still appear via the existing `recentInserts` mechanism. This is already implemented — no changes needed, just validation.

When `update_layout` inserts an entry, clear it from `recentInserts` if present:

**File:** `Murmur/Services/AppState.swift`

```swift
func applyLayoutUpdate(operations: [LayoutOperation]) -> LayoutDiff {
    guard homeComposition != nil else {
        homeComposition = HomeComposition(sections: [])
        // fall through
    }
    let diff = homeComposition!.apply(operations: operations)
    // Clear any recent inserts that are now placed in the layout
    for (id, _) in diff.insertedEntries {
        recentInserts.removeAll { insert in
            if case .entry(let uuid) = insert,
               let entry = /* resolve shortID to UUID */ nil {
                return false // TODO: resolve
            }
            return false
        }
    }
    homeCompositionStore?.save(homeComposition!)
    return diff
}
```

- [x] Clear recentInserts for entries placed by `update_layout`
- [x] Validate that entries without layout placement still appear in recentInserts area

### Phase 3 Acceptance Criteria

- [x] Inserted entries fade in with spring animation
- [x] Removed entries fade out
- [x] Moved entries animate smoothly between sections (matchedGeometryEffect)
- [x] Updated entries cross-fade emphasis/badge changes
- [x] Cold start batch insert has staggered 60ms reveal animation
- [x] Sections slide in when added, collapse when removed
- [x] Entries without `insert_entry` placement appear in recentInserts (existing behavior preserved)
- [x] No animation regression on existing compose_view recomposition
- [x] `make build` succeeds

---

## Phase 4: Settings Toggle (Focus/Browse)

Based on the design psychology analysis, add a "View" setting with two modes.

### 4.1 Setting Storage

**File:** `Murmur/Views/Settings/SettingsView.swift` (or wherever settings are)

```swift
// Already exists in DevMode as @AppStorage("homeVariant")
// Evolve to a proper setting:
@AppStorage("homeViewMode") var homeViewMode: String = "focus"
```

Two modes:
- **Focus** — `DamHomeView`: AI-composed layout, diffs, 5-15 items, no categories
- **Browse** — `SacHomeView`: Focus strip + collapsible category sections, all entries visible

### 4.2 Settings UI

**File:** `Murmur/Views/Settings/SettingsView.swift`

Add a "View" section:

```swift
Section {
    Picker("View", selection: $homeViewMode) {
        Text("Focus").tag("focus")
        Text("Browse").tag("browse")
    }
    .pickerStyle(.segmented)

    Text(homeViewMode == "focus"
        ? "AI picks what matters. One screen, no scrolling."
        : "All entries by category. Collapse what you've seen.")
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
} header: {
    Text("HOME")
}
```

- [ ] Add "View" section to SettingsView with Focus/Browse picker
- [ ] Add description text below picker
- [ ] Wire to `@AppStorage("homeViewMode")`

### 4.3 Both Views Use AI Composition

Both modes benefit from AI composition — they just render differently:

- **Focus (DamHomeView):** Renders `HomeComposition` directly with emphasis levels, messages, etc.
- **Browse (SacHomeView):** Uses `DailyFocus` for the focus strip (already working). Optionally could use `HomeComposition` to inform which entries get attention badges, but categories remain user-controlled.

No changes needed to SacHomeView for Phase 4 — it already works with `compose_focus`.

### 4.4 RootView Wiring

**File:** `Murmur/Views/RootView.swift`

Replace the DevMode-only `homeVariant` check with the new setting:

```swift
@AppStorage("homeViewMode") private var homeViewMode: String = "focus"

// In body:
if homeViewMode == "focus" {
    DamHomeView(...)
} else {
    SacHomeView(...)
}
```

Keep the DevMode picker functional (it should write to the same `@AppStorage` key).

- [ ] Wire `@AppStorage("homeViewMode")` in RootView
- [ ] Replace DevMode `homeVariant` with `homeViewMode`
- [ ] Default new users to "browse" (conventional, safe default)
- [ ] Surface "Try Focus view" prompt after 7 days or 20+ entries (future enhancement)

### Phase 4 Acceptance Criteria

- [ ] Settings shows "View" section with Focus/Browse picker
- [ ] Picker toggles between DamHomeView and SacHomeView
- [ ] Both views functional — no regressions on either
- [ ] Setting persists across app launches
- [ ] DevMode picker still works (writes to same key)
- [ ] Default is "browse" for new users

---

## Dependencies & Prerequisites

- **Phase 1 compose_view** already committed and working on `dam` branch
- Existing `HomeComposition`, `ComposedSection`, `ComposedItem`, `ComposedEntry` types (template)
- Existing `AgentActionExecutor` patterns (executeOne dispatch, ActionOutcome)
- Existing `ToolResultBuilder` + `ToolCallGroup` tool result pattern
- Existing `ConversationState.consumeAgentStream` streaming execution
- Existing `@AppStorage("homeVariant")` DevMode toggle
- PPQ.ai API access for LLM calls

## Risk Analysis & Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Agent doesn't call layout tools consistently | High | `recentInserts` fallback ensures entries are always visible. System prompt guidance. Iterate on prompt. |
| Agent calls `update_layout` with bad operations | Medium | Silent failure per-operation. Invalid ops are no-ops. Composition never left in broken state. |
| matchedGeometryEffect glitches | Medium | Fall back to simple opacity transitions. matchedGeometry is notoriously finicky — test on device. |
| Cold start via diffs is slower than one-shot compose_view | Low | Keep compose_view as the cold start path. Diffs are for incremental updates. |
| Token cost of get_current_layout | Low | Layout JSON is small (< 200 tokens for 5 sections, 15 entries). Much cheaper than full recompose. |
| Breaking existing compose_view | Very Low | compose_view is untouched. Layout tools are additive. No migration needed. |

## References

### Internal References

- Diff brainstorm: `docs/brainstorms/2026-03-04-entry-placement-hints-brainstorm.md`
- Phase 1 plan: `docs/plans/2026-03-04-feat-composable-ai-home-view-plan.md`
- Original brainstorm: `docs/brainstorms/2026-03-04-composable-home-view-brainstorm.md`
- Psychology analysis: `docs/brainstorms/2026-03-04-dam-sac-design-psychology.md`
- HomeComposition types: `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift`
- HomeComposition tests: `Packages/MurmurCore/Tests/MurmurCoreTests/HomeCompositionTests.swift`
- Tool schemas: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:746` (compose_view pattern)
- Agent parsing: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:483` (parseActions)
- Action executor: `Murmur/Services/AgentActionExecutor.swift:45` (execute dispatch)
- Tool results: `Murmur/Services/ToolResultBuilder.swift`
- Stream consumption: `Murmur/Services/ConversationState.swift:307` (consumeAgentStream)
- DamHomeView: `Murmur/Views/Home/DamHomeView.swift`
- AppState composition: `Murmur/Services/AppState.swift:196` (layout state management)
- HomeCompositionStore: `Murmur/Services/HomeCompositionStore.swift`
