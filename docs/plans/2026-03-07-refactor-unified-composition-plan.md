# Unified Home Composition Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace two separate LLM composition systems (DailyFocus + HomeComposition) with a single `HomeComposition` model consumed by both DamHomeView and SacHomeView.

**Architecture:** Add a `briefing: String?` field to `HomeComposition` for sac's greeting message. Add a `CompositionVariant` enum to route between dam's urgency-based prompt and a new category-based prompt for sac. SacHomeView's `FocusTabView` re-reads from `appState.homeComposition` instead of `appState.dailyFocus`, re-grouping items by category client-side (same as today). Delete `DailyFocus`, `FocusCluster`, `FocusItem`, `compose_focus` tool, `dailyBriefing` prompt, `DailyFocusStore`, and all `requestDailyFocus`/`invalidateDailyFocus` paths.

**Tech Stack:** Swift, SwiftUI, MurmurCore (SPM), PPQ.ai LLM API

---

## Design Decisions

### D1: Schema addition — `briefing` field on HomeComposition

Add `public var briefing: String?` to `HomeComposition`. This carries sac's overall message ("Busy day — tackle these in order."). Dam's view ignores it. The existing `.message()` items are inline section content — different purpose.

Why not use the first `.message()` item? Because sac's briefing is a top-level greeting that appears above all sections, not inside a section. Overloading `.message()` would require the renderer to treat position 0 specially.

### D2: Per-view prompt via `CompositionVariant`

Two variants: `.curated` (dam) and `.organized` (sac). The variant is passed to `requestHomeComposition()`. Each variant has its own `LLMPrompt` and tool schema.

- Dam's `.curated` prompt: unchanged — group by urgency/context, 3-5 sections, 5-15 items, use emphasis/density.
- Sac's `.organized` prompt: new — group by category, select up to 7 items, assign badge per item, produce a briefing message. The LLM groups by `EntryCategory` directly (since the UI enforces that anyway — no more wasted thematic clustering).

### D3: Sac prompt groups by category

The current `compose_focus` asks for thematic clusters, but `resolvedClusters()` immediately throws them away and re-groups by `EntryCategory`. Waste of LLM reasoning.

The new `.organized` prompt asks the LLM to group by category directly:
- Each section title is the category name (e.g., "todo", "reminder", "habit")
- Each item gets a `badge` (= reason): "Overdue", "Today", "Stale", etc.
- The response includes a top-level `briefing` string
- Density is always `.relaxed`, emphasis is always `.standard` (sac treats all items equally)

### D4: Discrepancy resolutions

| Issue | Resolution |
|-------|-----------|
| Item cap: dam 5-15, sac up to 7 | Per-variant. Dam prompt says 5-15, sac prompt says up to 7. |
| Grouping: dam by urgency, sac by category | Per-variant prompts handle this. |
| Density: dam uses it, sac ignores | Sac prompt produces `.relaxed` always. SacHomeView ignores it. Fine. |
| Emphasis: dam uses hero/standard/compact, sac treats all equal | Sac prompt produces `.standard` always. SacHomeView ignores emphasis. Fine. |
| `.message()` items: dam inline, sac doesn't use | Sac prompt doesn't produce `.message()` items. Briefing goes in top-level `briefing` field. |
| `update_layout` | Both views get layout tools. The entryManager prompt has variant-aware layout instructions — dam groups by urgency, sac groups by category. Same tool schemas, different instructions. |
| Invalidation: same trigger? | Yes. `invalidateHomeComposition()` serves both. `scheduleFocusRefresh()` in RootView calls the unified path. |
| Cache: one file or two? | One file. Both variants produce `HomeComposition`. The cache doesn't care which prompt generated it. |
| Variant switch mid-session | Invalidate composition cache, reset agent conversation, recompose fresh. Full isolation — no stale prompt context or wrong-variant cache. |

### D5: Both views get `update_layout` with variant-aware instructions

The tool schemas (`get_current_layout`, `update_layout`) are identical for both variants — same 7 operation types. What changes is the **instructions paragraph** in the entryManager prompt:

- **Dam (`.curated`):** "Group by urgency/context. Use hero emphasis for urgent items. 3-5 sections, 5-15 items. Use insert_entry to place in urgency-based sections."
- **Sac (`.organized`):** "Each section is a category name (todo, reminder, habit, etc.). Use standard emphasis for all entries. Insert entries into their matching category section. Create the section if it doesn't exist. Keep to 7 items max."

This means the agent can do cheap incremental updates for both views — no full recomposition needed after creating/completing entries. `LLMPrompt.entryManager` becomes a static method accepting a variant parameter.

### D7: Variant switch = full reset

When the user toggles `homeVariant` in DevMode:
1. `invalidateHomeComposition()` — clears cache + in-memory composition
2. Reset the agent `ConversationState` — the conversation was built with a prompt containing layout instructions for the old variant. Stale context.
3. Request fresh composition with the new variant

This is done via `.onChange(of: homeVariant)` in RootView.

### D6: Deterministic fallback unification

Both fallbacks produce `HomeComposition`. The dam fallback (urgency-based) and sac fallback (flat list by priority) merge into one method that accepts the variant:
- `.curated`: current `buildDeterministicComposition` logic (sections: "Needs attention" + "Recent")
- `.organized`: current `buildDeterministicFocus` logic, but output as `HomeComposition` sections grouped by category

---

## Files Overview

| Action | File | Purpose |
|--------|------|---------|
| Modify | `Packages/MurmurCore/.../HomeComposition.swift` | Add `briefing` field |
| Modify | `Packages/MurmurCore/.../LLMService.swift` | Add variant enum, new prompt, delete DailyFocus types |
| Modify | `Packages/MurmurCore/.../PPQLLMService.swift` | Delete `composeDailyFocus`, modify `composeHomeView` |
| Modify | `Murmur/Services/AppState.swift` | Unified request path, delete DailyFocus state |
| Delete | `Murmur/Services/DailyFocusStore.swift` | Replaced by HomeCompositionStore |
| Modify | `Murmur/Views/Home/SacHomeView.swift` | FocusTabView reads homeComposition |
| Modify | `Murmur/Views/RootView.swift` | Unified composition requests, variant-switch handler, delete focus-specific calls |
| Modify | `Murmur/DevMode/DevModeView.swift` | Update "Regenerate" button |
| Modify | `Packages/MurmurCore/Tests/...` | Update tests for deleted types, add new tests |

---

## Task 1: Add `briefing` field to HomeComposition

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift`

**Step 1: Add the `briefing` property**

In `HomeComposition`, add a `briefing` field:

```swift
public struct HomeComposition: Codable, Sendable {
    public var sections: [ComposedSection]
    public var composedAt: Date
    public var briefing: String?

    // ... isFromToday unchanged ...

    public init(sections: [ComposedSection], composedAt: Date = Date(), briefing: String? = nil) {
        self.sections = sections
        self.composedAt = composedAt
        self.briefing = briefing
    }
```

The `briefing` field is optional and `Codable` — existing cached JSON without it decodes fine (nil default).

**Step 2: Build and verify**

Run: `cd Packages/MurmurCore && swift build`
Expected: Build succeeds. The new optional field doesn't break existing callers.

**Step 3: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift
git commit -m "feat: add briefing field to HomeComposition"
```

---

## Task 2: Add `CompositionVariant` enum and sac's prompt

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

**Step 1: Add the `CompositionVariant` enum**

Add near the top of the `LLMPrompt` extension (after the existing static properties), before the `dailyBriefing` prompt:

```swift
/// Which home view variant to compose for.
public enum CompositionVariant: String, Sendable {
    case curated    // dam: urgency-grouped, emphasis levels, 5-15 items
    case organized  // sac: category-grouped, up to 7 items, briefing message
}
```

**Step 2: Add the sac-variant prompt**

Add a new static property on `LLMPrompt`:

```swift
/// Organized composition prompt: groups entries by category for the Focus tab.
public static let organizedComposition = LLMPrompt(
    systemPrompt: """
        You are composing a daily focus dashboard for a personal voice assistant app.
        You receive the user's current entries. Select up to 7 entries that deserve attention today.

        Selection criteria (in priority order):
        1. Overdue entries (due date has passed)
        2. Due today
        3. High priority (P1, P2)
        4. Stale entries (created long ago, never updated)
        5. Habits not yet done for the current period

        Group selected entries by their category (todo, reminder, habit, idea, list, note, question).
        Each section title MUST be the exact category name in lowercase.
        Only include sections for categories that have selected entries.

        For each entry, assign a 1-word badge: Overdue, Today, Urgent, Stale, Due, etc.

        Write a briefing message (under 12 words) summarizing the day's focus:
        - "Busy day — tackle these in order."
        - "Light load today — one thing needs you."
        - "All clear — nothing pressing today."

        Rules:
        - Use standard emphasis for all entries.
        - Use relaxed density for all sections.
        - Do not include message items in sections.
        - If nothing deserves focus, return zero sections with a calm briefing.
        """,
    tools: [composeViewToolSchema()],
    toolChoice: .function(name: "compose_view")
)
```

Note: This reuses the `compose_view` tool schema — same output shape as dam's prompt, just different instructions. The `briefing` field is added to the tool schema in the next step.

**Step 3: Add `briefing` to the `compose_view` tool schema**

In `composeViewToolSchema()`, add `briefing` as an optional top-level property:

```swift
static func composeViewToolSchema() -> [String: Any] {
    [
        "type": "function",
        "function": [
            "name": "compose_view",
            "description": "Compose the home view. Surface what matters right now. Most entries stay hidden.",
            "parameters": [
                "type": "object",
                "properties": [
                    "sections": [
                        // ... existing sections schema unchanged ...
                    ] as [String: Any],
                    "briefing": [
                        "type": "string",
                        "description": "Optional top-level briefing message, under 12 words. Used by the organized variant.",
                    ],
                ],
                "required": ["sections"],
            ] as [String: Any],
        ] as [String: Any],
    ]
}
```

**Step 4: Build and verify**

Run: `cd Packages/MurmurCore && swift build`
Expected: Build succeeds.

**Step 5: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/LLMService.swift
git commit -m "feat: add CompositionVariant and organized composition prompt"
```

---

## Task 3: Modify `PPQLLMService` — variant-aware composition, delete `composeDailyFocus`

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift`

**Step 1: Add variant parameter to `composeHomeView`**

Change the signature to accept a variant:

```swift
public func composeHomeView(
    entries: [AgentContextEntry],
    variant: CompositionVariant = .curated
) async throws -> HomeComposition {
    let prompt: LLMPrompt = variant == .organized ? .organizedComposition : .homeComposition
    sseLog.info("[SSE] composeHomeView(\(variant)) called — NON-STREAMING, \(entries.count) entries")
    let userContent = variant == .organized
        ? buildBriefingUserContent(entries: entries)
        : buildCompositionUserContent(entries: entries)
    let conversation = LLMConversation()

    let turn = try await runTurn(
        userContent: userContent,
        prompt: prompt,
        conversation: conversation
    )

    let composition = try parseHomeComposition(from: turn.assistantMessage)
    sseLog.info("[SSE] composeHomeView(\(variant)) complete — \(composition.sections.count) sections")
    return composition
}
```

**Step 2: Update `parseHomeComposition` to extract briefing**

In `parseHomeComposition(from:)`, after decoding sections, also extract the `briefing` field:

```swift
// In the args parsing section, after getting the sections array:
let briefing = args["briefing"] as? String
return HomeComposition(sections: parsedSections, briefing: briefing)
```

Find the exact existing code in `parseHomeComposition` and add the briefing extraction. The init call currently passes `sections:` only — update to include `briefing:`.

**Step 3: Delete `composeDailyFocus` and supporting methods**

Delete these methods from `PPQLLMService.swift`:
- `composeDailyFocus(entries:)` (lines ~120-134)
- `buildBriefingUserContent(entries:)` — WAIT: keep this, it's reused by the organized variant. Actually, rename or share it.

On second look: `buildBriefingUserContent` formats entries for the focus/briefing context with `[BRIEFING]` prefix. `buildCompositionUserContent` formats for composition with `[COMPOSITION]` prefix. The organized variant should use the briefing-style content. So keep `buildBriefingUserContent` but it can be called by `composeHomeView` when variant is `.organized`.

Delete only:
- `composeDailyFocus(entries:)` method
- `parseDailyFocus(from:)` method

**Step 4: Delete `composeFocusToolSchema` from LLMService.swift**

In `LLMService.swift`, delete:
- The `composeFocusToolSchema()` function (lines ~911-961)

**Step 5: Build and verify**

Run: `cd Packages/MurmurCore && swift build`
Expected: Build errors in AppState.swift (references to deleted methods). That's expected — fixed in Task 5.

**Step 6: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift
git add Packages/MurmurCore/Sources/MurmurCore/LLMService.swift
git commit -m "feat: variant-aware composeHomeView, delete composeDailyFocus"
```

---

## Task 4: Delete DailyFocus types from LLMService.swift

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

**Step 1: Delete DailyFocus types**

Delete these types (lines ~234-278):
- `FocusItem`
- `FocusCluster`
- `DailyFocus`

**Step 2: Delete the `dailyBriefing` prompt**

Delete `LLMPrompt.dailyBriefing` (lines ~184-229).

**Step 3: Delete `ComposeFocusArguments` if it exists**

Search for `ComposeFocusArguments` in PPQLLMService.swift and delete it.

**Step 4: Build — expect errors**

Run: `cd Packages/MurmurCore && swift build`
Expected: Errors in files referencing `DailyFocus`. These are resolved in subsequent tasks.

**Step 5: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/LLMService.swift
git add Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift
git commit -m "refactor: delete DailyFocus types and dailyBriefing prompt"
```

---

## Task 5: Unify AppState — single composition path

**Files:**
- Modify: `Murmur/Services/AppState.swift`
- Delete: `Murmur/Services/DailyFocusStore.swift`

**Step 1: Delete DailyFocus state from AppState**

Remove these properties:
```swift
// DELETE these:
var dailyFocus: DailyFocus?
var isFocusLoading: Bool = false
var dailyFocusStore: DailyFocusStore?
```

**Step 2: Delete DailyFocus methods from AppState**

Remove these methods entirely:
- `invalidateDailyFocus()`
- `requestFocusIfStale(entries:stalenessInterval:)`
- `requestDailyFocus(entries:)`
- `buildDeterministicFocus(entries:)`

**Step 3: Remove `dailyFocusStore` initialization from `configurePipeline()`**

Delete the line:
```swift
dailyFocusStore = DailyFocusStore()
```

**Step 4: Add variant parameter to `requestHomeComposition`**

```swift
func requestHomeComposition(entries: [Entry], variant: CompositionVariant = .curated) async {
    // Check cache first
    if let cached = homeCompositionStore?.load(), cached.isFromToday {
        homeComposition = cached
        return
    }

    guard let llmService, let creditGate else {
        homeComposition = buildDeterministicComposition(entries: entries, variant: variant)
        return
    }

    isHomeCompositionLoading = true
    defer { isHomeCompositionLoading = false }

    do {
        let authorization = try await creditGate.authorize()
        let agentEntries = entries.map { $0.toAgentContext() }
        let composition = try await llmService.composeHomeView(entries: agentEntries, variant: variant)

        let pricing = ServicePricing(
            inputUSDPer1MMicros: 1_000_000,
            outputUSDPer1MMicros: 5_000_000,
            minimumChargeCredits: 1
        )
        _ = try await creditGate.charge(
            authorization,
            usage: TokenUsage(inputTokens: 200, outputTokens: 100),
            pricing: pricing
        )
        await refreshCreditBalance()

        try? homeCompositionStore?.save(composition)
        homeComposition = composition
    } catch {
        homeComposition = buildDeterministicComposition(entries: entries, variant: variant)
    }
}
```

**Step 5: Add `resetConversation()` method**

Add a method to nil out the lazy conversation so a fresh one is allocated on next access. This is used by variant-switch handling in RootView (Task 6):

```swift
func resetConversation() {
    _conversation = nil
}
```

**Step 6: Add staleness check method**

Replace `requestFocusIfStale` with a unified version:

```swift
func requestCompositionIfStale(
    entries: [Entry],
    variant: CompositionVariant = .curated,
    stalenessInterval: TimeInterval = 3 * 3600
) async {
    if let existing = homeComposition {
        let age = Date().timeIntervalSince(existing.composedAt)
        guard age >= stalenessInterval else { return }
    }
    await requestHomeComposition(entries: entries, variant: variant)
}
```

**Step 7: Update `buildDeterministicComposition` to handle both variants**

```swift
private func buildDeterministicComposition(
    entries: [Entry],
    variant: CompositionVariant = .curated
) -> HomeComposition {
    switch variant {
    case .curated:
        return buildDeterministicCurated(entries: entries)
    case .organized:
        return buildDeterministicOrganized(entries: entries)
    }
}

/// Dam's fallback: urgency sections
private func buildDeterministicCurated(entries: [Entry]) -> HomeComposition {
    // ... existing buildDeterministicComposition logic, unchanged ...
}

/// Sac's fallback: category-grouped, priority-sorted, up to 7 items
private func buildDeterministicOrganized(entries: [Entry]) -> HomeComposition {
    let now = Date()
    var candidates: [(entry: Entry, reason: String)] = []

    for entry in entries {
        let isOverdue = entry.dueDate.map { $0 < now } ?? false
        let isHighPriority = (entry.priority ?? Int.max) <= 2
        if isOverdue {
            candidates.append((entry, "Overdue"))
        } else if isHighPriority {
            candidates.append((entry, "P\(entry.priority ?? 1)"))
        }
    }

    candidates.sort { lhs, rhs in
        let lo = lhs.entry.dueDate.map { $0 < now } ?? false
        let ro = rhs.entry.dueDate.map { $0 < now } ?? false
        if lo != ro { return lo }
        let pa = lhs.entry.priority ?? Int.max
        let pb = rhs.entry.priority ?? Int.max
        return pa < pb
    }

    let selected = Array(candidates.prefix(7))

    // Group by category
    let order: [EntryCategory] = [.todo, .reminder, .habit, .idea, .list, .note, .question]
    var byCategory: [EntryCategory: [(entry: Entry, reason: String)]] = [:]
    for item in selected {
        byCategory[item.entry.category, default: []].append(item)
    }

    var sections: [ComposedSection] = []
    for category in order {
        guard let items = byCategory[category], !items.isEmpty else { continue }
        let composedItems = items.map { pair in
            ComposedItem.entry(ComposedEntry(
                id: pair.entry.shortID,
                emphasis: .standard,
                badge: pair.reason
            ))
        }
        sections.append(ComposedSection(
            title: category.rawValue,
            density: .relaxed,
            items: composedItems
        ))
    }

    let briefing = selected.isEmpty
        ? "All clear — nothing pressing today."
        : "Focus on these things today."
    return HomeComposition(sections: sections, composedAt: now, briefing: briefing)
}
```

**Step 8: Delete `DailyFocusStore.swift`**

Delete the file `Murmur/Services/DailyFocusStore.swift`.

Also update `project.yml` if `DailyFocusStore.swift` is explicitly listed there (check first — XcodeGen may use glob patterns).

**Step 9: Build — expect errors in RootView and SacHomeView**

Run: `make build`
Expected: Errors in `RootView.swift` and `SacHomeView.swift` (references to deleted `dailyFocus`, `isFocusLoading`, etc.). Fixed in next tasks.

**Step 10: Commit**

```bash
git rm Murmur/Services/DailyFocusStore.swift
git add Murmur/Services/AppState.swift
git commit -m "refactor: unify AppState to single composition path, delete DailyFocusStore"
```

---

## Task 6: Update RootView — unified composition requests

**Files:**
- Modify: `Murmur/Views/RootView.swift`

**Step 1: Replace all focus-specific calls with composition calls**

Replace in `RootView`:

1. In `.onAppear` (line ~263): replace `requestDailyFocus` with `requestHomeComposition`
```swift
// OLD:
Task { @MainActor in
    await appState.requestDailyFocus(entries: activeEntries)
}
// NEW:
Task { @MainActor in
    let variant: CompositionVariant = homeVariant == "dam" ? .curated : .organized
    await appState.requestHomeComposition(entries: activeEntries, variant: variant)
}
```

2. In `.onChange(of: scenePhase)` (line ~270): replace `requestFocusIfStale` with `requestCompositionIfStale`
```swift
// OLD:
await appState.requestFocusIfStale(entries: activeEntries)
// NEW:
let variant: CompositionVariant = homeVariant == "dam" ? .curated : .organized
await appState.requestCompositionIfStale(entries: activeEntries, variant: variant)
```

3. In `scheduleFocusRefresh()` (line ~512): replace both calls
```swift
func scheduleFocusRefresh() {
    focusRefreshTask?.cancel()
    focusRefreshTask = Task { @MainActor in
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        appState.invalidateHomeComposition()
        let variant: CompositionVariant = homeVariant == "dam" ? .curated : .organized
        await appState.requestHomeComposition(entries: activeEntries, variant: variant)
    }
}
```

Rename `scheduleFocusRefresh` to `scheduleCompositionRefresh` for clarity.

4. In the `#if DEBUG` sheet dismiss handler (line ~190): remove the `dailyFocus` check block, keep the `homeComposition` check but make it work for both variants:
```swift
.sheet(isPresented: $showDevMode, onDismiss: {
    if appState.homeComposition == nil && !appState.isHomeCompositionLoading {
        Task { @MainActor in
            let variant: CompositionVariant = homeVariant == "dam" ? .curated : .organized
            await appState.requestHomeComposition(entries: activeEntries, variant: variant)
        }
    }
}) {
```

5. Remove `focusRefreshTask` state variable if renamed, or just rename all references.

**Step 2: Add variant-switch handler**

Add an `.onChange(of: homeVariant)` to RootView's body that performs a full reset:

```swift
.onChange(of: homeVariant) { _, newVariant in
    // Full isolation: clear composition, reset conversation, recompose fresh
    appState.invalidateHomeComposition()
    appState.resetConversation()
    Task { @MainActor in
        let variant: CompositionVariant = newVariant == "dam" ? .curated : .organized
        await appState.requestHomeComposition(entries: activeEntries, variant: variant)
    }
}
```

This requires adding a `resetConversation()` method to AppState (see Task 5). The method nils out the lazy `_conversation` so a fresh one is allocated on next access — no stale prompt context from the old variant.

Add to AppState (in Task 5):
```swift
func resetConversation() {
    _conversation = nil
}
```

**Step 3: Also update `DamHomeView` if it doesn't pass variant**

`DamHomeView.composedContent` calls `appState.requestHomeComposition(entries:)` in `.onAppear` (line ~107). This defaults to `.curated` which is correct. No change needed.

**Step 4: Build — expect errors in SacHomeView only**

Run: `make build`
Expected: Errors only in `SacHomeView.swift` (references to `dailyFocus`, `isFocusLoading`).

**Step 5: Commit**

```bash
git add Murmur/Views/RootView.swift
git commit -m "refactor: RootView uses unified composition requests"
```

---

## Task 7: Update SacHomeView — FocusTabView reads HomeComposition

**Files:**
- Modify: `Murmur/Views/Home/SacHomeView.swift`

This is the core refactor. `FocusTabView` currently reads `appState.dailyFocus: DailyFocus?`. Change it to read `appState.homeComposition: HomeComposition?`.

**Step 1: Update SacHomeView's `populatedState` to pass new props**

```swift
// In SacHomeView.populatedState:
if appState.selectedTab == .focus {
    FocusTabView(
        isLoading: appState.isHomeCompositionLoading,
        composition: appState.homeComposition,
        isProcessing: appState.conversation.isProcessing,
        allEntries: entries,
        activeSwipeEntryID: $activeSwipeEntryID,
        messageVisible: $focusMessageVisible,
        visibleCardCount: $focusVisibleCardCount,
        onEntryTap: onEntryTap,
        swipeActionsProvider: swipeActions(for:),
        onAction: onAction
    )
    // ... transition unchanged ...
}
```

**Step 2: Rewrite `FocusTabView` internals**

Change the stored properties:
```swift
private struct FocusTabView: View {
    let isLoading: Bool
    let composition: HomeComposition?    // was: dailyFocus: DailyFocus?
    let isProcessing: Bool
    let allEntries: [Entry]
    @Binding var activeSwipeEntryID: UUID?
    @Binding var messageVisible: Bool
    @Binding var visibleCardCount: Int
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
```

**Step 3: Rewrite `resolvedClusters` to read from `HomeComposition`**

The logic changes from reading `DailyFocus.clusters[].items[]` to reading `HomeComposition.sections[].items[]`:

```swift
private func resolvedClusters(composition: HomeComposition) -> [ResolvedCluster] {
    // Flatten all LLM-selected items and re-group by entry.category client-side.
    var byCategory: [EntryCategory: [(entry: Entry, reason: String)]] = [:]
    for section in composition.sections {
        for item in section.items {
            guard case .entry(let composed) = item,
                  let entry = Entry.resolve(shortID: composed.id, in: allEntries)
            else { continue }
            byCategory[entry.category, default: []].append((entry, composed.badge ?? ""))
        }
    }
    let order: [EntryCategory] = [.todo, .reminder, .habit, .idea, .list, .note, .question]
    var globalIndex = 0
    var result: [ResolvedCluster] = []
    for category in order {
        guard let pairs = byCategory[category], !pairs.isEmpty else { continue }
        let items = pairs.map { pair -> FocusItemResolved in
            let item = FocusItemResolved(entry: pair.entry, reason: pair.reason, globalIndex: globalIndex)
            globalIndex += 1
            return item
        }
        result.append(ResolvedCluster(message: "", items: items))
    }
    return result
}
```

Key mapping: `composed.badge` → `reason`. The `badge` field in `ComposedEntry` serves the same role as `FocusItem.reason`.

**Step 4: Update the body to use `composition` instead of `dailyFocus`**

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 16) {
            if isLoading && composition == nil {
                FocusLoadingView()
                    .transition(.opacity)
            } else if let composition {
                // Greeting + briefing header
                VStack(alignment: .leading, spacing: 4) {
                    Text(Greeting.current + ".")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)

                    if let briefing = composition.briefing {
                        Text(briefing)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(messageVisible ? 1 : 0)
                .offset(y: messageVisible ? 0 : 6)

                // Focus clusters (category-grouped)
                let clusters = resolvedClusters(composition: composition)
                // ... rest identical, using clusters ...
```

**Step 5: Update `onAppear` and `onChange` to use `composition`**

```swift
.onAppear {
    guard visibleCardCount == 0, let composition else { return }
    let count = resolvedClusters(composition: composition).reduce(0) { $0 + $1.items.count }
    staggerIn(count: count)
}
.onChange(of: composition?.composedAt) { _, _ in
    guard let composition else { return }
    messageVisible = false
    visibleCardCount = 0
    let count = resolvedClusters(composition: composition).reduce(0) { $0 + $1.items.count }
    staggerIn(count: count)
}
```

**Step 6: Add `.onAppear` composition request**

SacHomeView needs to trigger composition on appear (like DamHomeView does). Add to `SacHomeView.populatedState` or the `FocusTabView`:

```swift
// In SacHomeView, inside the ZStack of populatedState, or on the FocusTabView itself:
.onAppear {
    Task {
        await appState.requestHomeComposition(entries: entries, variant: .organized)
    }
}
```

Actually, looking at the current code: RootView already calls `requestDailyFocus` in `.onAppear`. After Task 6, it calls `requestHomeComposition` with the correct variant. So SacHomeView doesn't need its own request — RootView handles it. But DamHomeView has its own `.onAppear` request too (line 107). To be consistent, we can leave RootView as the single request point. Remove the `.onAppear` from DamHomeView if desired, or leave both (the cache check makes duplicate calls free).

**Step 7: Build and test**

Run: `make build`
Expected: Clean build. The app should show the same UI but powered by `HomeComposition` instead of `DailyFocus`.

**Step 8: Commit**

```bash
git add Murmur/Views/Home/SacHomeView.swift
git commit -m "refactor: SacHomeView FocusTabView reads HomeComposition"
```

---

## Task 8: Update DevModeView

**Files:**
- Modify: `Murmur/DevMode/DevModeView.swift`

**Step 1: Update the regenerate button**

Find the "Regenerate Daily Focus" button and change it to use the unified composition invalidation:

```swift
// OLD:
Button {
    appState.invalidateDailyFocus()
    dismiss()
} label: {
    // ...
    Text("Regenerate Daily Focus")
    // ...
}

// NEW:
Button {
    appState.invalidateHomeComposition()
    dismiss()
} label: {
    // ...
    Text("Recompose Home")
    // ...
}
```

If there's a separate "Recompose Home" button for dam, merge them into one button since both variants use the same invalidation path.

**Step 2: Build and verify**

Run: `make build`
Expected: Clean build.

**Step 3: Commit**

```bash
git add Murmur/DevMode/DevModeView.swift
git commit -m "refactor: unify DevMode regenerate button"
```

---

## Task 9: Make entryManager prompt variant-aware (both views get layout tools)

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`
- Modify: call sites that reference `.entryManager` (find with grep)

**Step 1: Convert `entryManager` from static property to static method**

The `entryManager` prompt is currently a static property. Change it to a static method that accepts a variant. Both variants get all the same tools (including `get_current_layout` and `update_layout`). Only the layout **instructions** paragraph changes:

```swift
public static func entryManager(variant: CompositionVariant = .curated) -> LLMPrompt {
    let layoutInstructions: String
    switch variant {
    case .curated:
        layoutInstructions = """
            Layout tools:
            - After creating/completing/updating entries, call get_current_layout to see the current home screen.
            - Then call update_layout to place new entries or remove completed ones from the layout.
            - If the layout is empty (cold start), compose a full layout with add_section + insert_entry operations.
            - Keep the layout focused: 3-5 sections, 5-15 items total.
            - Group sections by urgency and context, NOT by category.
            - Use hero emphasis for the most urgent items (1-2 max). Compact for low-priority.
            - Use insert_entry to add new entries to the appropriate section.
            - Use remove_entry after completing/archiving entries.
            - Use move_entry when an entry's urgency changes (e.g., becomes overdue).
            - Calling update_layout is optional — entries without placement appear in a "recent" area above the layout.
            """
    case .organized:
        layoutInstructions = """
            Layout tools:
            - After creating/completing/updating entries, call get_current_layout to see the current home screen.
            - Then call update_layout to place new entries or remove completed ones from the layout.
            - Sections are named by category (todo, reminder, habit, idea, list, note, question).
            - Use standard emphasis for all entries. Use relaxed density for all sections.
            - Insert new entries into their matching category section. Create the section if it doesn't exist.
            - Remove entries after completing/archiving.
            - Keep to 7 items max across all sections.
            - Calling update_layout is optional — entries without placement appear in a "recent" area above the layout.
            """
    }

    return LLMPrompt(
        systemPrompt: """
            You are Murmur, an intelligent voice assistant...
            ... (existing prompt text, everything before "Layout tools:" line) ...
            \(layoutInstructions)
            """,
        tools: [
            createEntriesToolSchema(),
            updateEntriesToolSchema(),
            completeEntriesToolSchema(),
            archiveEntriesToolSchema(),
            updateMemoryToolSchema(),
            confirmActionsToolSchema(),
            getCurrentLayoutToolSchema(),
            updateLayoutToolSchema(),
        ],
        toolChoice: .auto
    )
}
```

Note: The tool list is identical for both variants. Only the instructions change.

**Step 2: Find and update all call sites**

Run: `grep -rn '\.entryManager' Packages/ Murmur/` to find every reference.

The main call site is in `ConversationState` (or wherever the agent pipeline constructs its prompt). Update each to pass the variant:

```swift
let prompt = LLMPrompt.entryManager(variant: compositionVariant)
```

**Step 3: Thread the variant into ConversationState**

`ConversationState` already has access to `appState`. Add a computed property to read the variant:

```swift
// In ConversationState:
var compositionVariant: CompositionVariant {
    let variant = UserDefaults.standard.string(forKey: "homeVariant") ?? "sac"
    return variant == "dam" ? .curated : .organized
}
```

Reading `UserDefaults` directly is fine here — it's a simple string read, no SwiftUI dependency, and `ConversationState` is `@MainActor` so thread safety is guaranteed. This also means the variant is read fresh each time a conversation turn starts, picking up any change immediately.

**Step 4: Build and test**

Run: `make build`
Expected: Clean build.

**Step 5: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/LLMService.swift
# Also add any files where .entryManager call sites were updated
git commit -m "feat: variant-aware layout instructions in entryManager prompt"
```

---

## Task 10: Update tests

**Files:**
- Modify: `Packages/MurmurCore/Tests/MurmurCoreTests/` — any tests referencing DailyFocus
- Add tests for new variant behavior

**Step 1: Find and fix broken tests**

Run: `cd Packages/MurmurCore && swift test 2>&1 | head -50`

Fix any test that references `DailyFocus`, `FocusItem`, `FocusCluster`, `composeDailyFocus`, etc.

**Step 2: Add test for organized variant fallback**

```swift
func testDeterministicOrganizedComposition() {
    // Test that buildDeterministicOrganized groups by category
    // with proper briefing message
}
```

**Step 3: Add test for briefing field encoding/decoding**

```swift
func testHomeCompositionBriefingRoundtrips() {
    let composition = HomeComposition(
        sections: [],
        briefing: "Light load today."
    )
    let data = try! JSONEncoder().encode(composition)
    let decoded = try! JSONDecoder().decode(HomeComposition.self, from: data)
    XCTAssertEqual(decoded.briefing, "Light load today.")
}

func testHomeCompositionNilBriefingBackwardCompatible() {
    // JSON without "briefing" key decodes to nil
    let json = """
    {"sections":[],"composedAt":0}
    """
    let data = json.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(HomeComposition.self, from: data)
    XCTAssertNil(decoded.briefing)
}
```

**Step 4: Run all tests**

Run: `make core-test`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add Packages/MurmurCore/Tests/
git commit -m "test: update tests for unified composition model"
```

---

## Task 11: Full build and smoke test

**Step 1: Clean build**

Run: `make clean && make build`
Expected: Clean build, no warnings related to our changes.

**Step 2: Run all tests**

Run: `make test && make core-test`
Expected: All pass.

**Step 3: Manual verification checklist**

If the app is runnable:
- [ ] Switch to dam variant in DevMode — composition loads, sections render, layout tools work
- [ ] Switch to sac variant — composition loads, Focus tab shows category-grouped cards with badges, greeting + briefing message displays
- [ ] Sac's All tab is completely unchanged
- [ ] "Recompose Home" in DevMode clears and regenerates for whichever variant is active
- [ ] Deterministic fallback works (disable network or LLM service)
- [ ] Variant switch in DevMode: composition clears, conversation resets, fresh composition loads for new variant
- [ ] After variant switch, agent uses correct layout instructions (dam: urgency sections, sac: category sections)
- [ ] Cache works: kill and relaunch app, composition loads from cache without LLM call

**Step 4: Final commit**

```bash
git add -A
git commit -m "refactor: unified home composition — one model, two renderers"
```

---

## Migration Summary

### Types Deleted
- `FocusItem` (LLMService.swift)
- `FocusCluster` (LLMService.swift)
- `DailyFocus` (LLMService.swift)
- `ComposeFocusArguments` (PPQLLMService.swift, if exists)
- `DailyFocusStore` (DailyFocusStore.swift — entire file)

### Types Added
- `CompositionVariant` enum (LLMService.swift)

### Types Modified
- `HomeComposition` — added `briefing: String?`

### Prompts Deleted
- `LLMPrompt.dailyBriefing`
- `composeFocusToolSchema()`

### Prompts Added
- `LLMPrompt.organizedComposition`

### Prompts Modified
- `LLMPrompt.entryManager` — static property → static method with variant parameter; both variants get layout tools, different instructions
- `composeViewToolSchema()` — added optional `briefing` parameter

### Methods Deleted (PPQLLMService)
- `composeDailyFocus(entries:)`
- `parseDailyFocus(from:)`

### Methods Modified (PPQLLMService)
- `composeHomeView(entries:)` → `composeHomeView(entries:variant:)`
- `parseHomeComposition(from:)` — extracts `briefing` field

### AppState Changes
- Deleted: `dailyFocus`, `isFocusLoading`, `dailyFocusStore`, `invalidateDailyFocus()`, `requestDailyFocus(entries:)`, `requestFocusIfStale(entries:)`, `buildDeterministicFocus(entries:)`
- Modified: `requestHomeComposition(entries:)` → `requestHomeComposition(entries:variant:)`
- Added: `requestCompositionIfStale(entries:variant:)`, `buildDeterministicOrganized(entries:)`, `resetConversation()`

### View Changes
- `SacHomeView.FocusTabView`: reads `HomeComposition?` instead of `DailyFocus?`
- `RootView`: all focus-specific calls replaced with unified composition calls; `.onChange(of: homeVariant)` invalidates composition + resets conversation
- `DevModeView`: "Regenerate Daily Focus" → "Recompose Home"
