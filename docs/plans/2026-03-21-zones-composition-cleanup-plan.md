# Zones Composition + Navigator Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Navigator view, rename remaining views to Scanner/Zones, give Zones full AI composition with briefing support in update_layout.

**Architecture:** Two home views (ScannerHomeView, ZonesHomeView) each with their own `CompositionVariant` (.scanner, .zones), composition prompts, layout instructions, and deterministic fallbacks. The `update_layout` tool gains an optional `briefing` field. Zones is fully AI-composed — agent places entries via `update_layout` inline; client-side sorting is fallback only.

**Tech Stack:** SwiftUI, MurmurCore (Swift Package), XcodeGen

**Spec:** `docs/specs/2026-03-21-zones-composition-cleanup-spec.md`

---

### Task 1: Replace `.navigator` with `.zones` in CompositionVariant

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift:8-11`
- Modify: `Packages/MurmurCore/Tests/MurmurCoreTests/HomeCompositionTests.swift`

- [ ] **Step 1: Update the enum**

In `HomeComposition.swift`, replace the `.navigator` case:

```swift
public enum CompositionVariant: String, Codable, Sendable {
    case scanner
    case zones
}
```

- [ ] **Step 2: Fix test references**

In `HomeCompositionTests.swift`, find all `.navigator` references and replace with `.zones`. Search for `navigator` in the file.

- [ ] **Step 3: Build MurmurCore to find all remaining `.navigator` references**

Run: `cd Packages/MurmurCore && swift build 2>&1 | head -40`

This will surface every compiler error from the enum rename. Don't fix them yet — just verify the errors are in the files we expect (LLMService, PPQLLMService, AppState).

- [ ] **Step 4: Commit**

```bash
git add Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift Packages/MurmurCore/Tests/MurmurCoreTests/HomeCompositionTests.swift
git commit -m "refactor: replace CompositionVariant.navigator with .zones"
```

---

### Task 2: Add `briefing` to `update_layout` tool

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:816-859` (tool schema)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:423` (AgentAction enum)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift:41-48` (apply method)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:1009-1011` (UpdateLayoutArguments)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/ToolCallParser.swift:64-68` (parse update_layout)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:598-601` (non-streaming parse)

- [ ] **Step 1: Add briefing to tool schema**

In `LLMService.swift`, `updateLayoutToolSchema()`, add `briefing` to the `properties` dict alongside `operations`:

```swift
"briefing": [
    "type": "string",
    "description": "Update the greeting subtitle. One sentence summarizing the day's state.",
] as [String: Any],
```

Do NOT add it to `required` — it stays optional.

- [ ] **Step 2: Add briefing to AgentAction.layoutUpdate**

In `LLMService.swift`, change the enum case:

```swift
case layoutUpdate([LayoutOperation], briefing: String?)
```

- [ ] **Step 3: Add briefing to UpdateLayoutArguments**

In `PPQLLMService.swift`, update the struct:

```swift
struct UpdateLayoutArguments: Decodable {
    let operations: [RawLayoutOperation]
    let briefing: String?
}
```

- [ ] **Step 4: Update ToolCallParser to pass briefing through**

In `ToolCallParser.swift`, update the `"update_layout"` case:

```swift
case "update_layout":
    let wrapper = try JSONDecoder().decode(UpdateLayoutArguments.self, from: argumentsData)
    let ops = wrapper.operations.compactMap { $0.asOperation }
    if ops.isEmpty && wrapper.briefing == nil {
        actions = []
    } else {
        actions = [.layoutUpdate(ops, briefing: wrapper.briefing)]
    }
```

- [ ] **Step 5: Update PPQLLMService non-streaming parse**

In `PPQLLMService.swift` around line 598-601, update the `"update_layout"` case:

```swift
case "update_layout":
    let wrapper = try JSONDecoder().decode(UpdateLayoutArguments.self, from: argumentsData)
    let operations = wrapper.operations.compactMap { $0.asOperation }
    actions.append(.layoutUpdate(operations, briefing: wrapper.briefing))
```

- [ ] **Step 6: Update HomeComposition.apply to accept briefing**

In `HomeComposition.swift`, update the method signature:

```swift
public mutating func apply(operations: [LayoutOperation], briefing: String? = nil) -> LayoutDiff {
    var diff = LayoutDiff()
    for op in operations {
        applyOne(op, diff: &diff)
    }
    if let briefing {
        self.briefing = briefing
    }
    composedAt = Date()
    return diff
}
```

- [ ] **Step 7: Build MurmurCore to find all call sites that need updating**

Run: `cd Packages/MurmurCore && swift build 2>&1 | head -40`

The `.layoutUpdate` pattern match changes will surface in AgentActionExecutor, ConversationState, ToolResultBuilder, and ThreadItem. Don't fix them yet.

- [ ] **Step 8: Commit**

```bash
git add Packages/MurmurCore/
git commit -m "feat: add briefing field to update_layout tool"
```

---

### Task 3: Fix app-layer call sites for updated `.layoutUpdate`

**Files:**
- Modify: `Murmur/Services/AgentActionExecutor.swift:174,229-244`
- Modify: `Murmur/Services/ConversationState.swift:429`
- Modify: `Murmur/Services/ToolResultBuilder.swift:52`
- Modify: `Murmur/Models/ThreadItem.swift:70`

- [ ] **Step 1: Update AgentActionExecutor**

In `AgentActionExecutor.swift`, update the pattern match at line 174:

```swift
case .layoutUpdate(let operations, let briefing):
    return executeLayoutUpdate(operations, briefing: briefing, context: ctx)
```

Update `executeLayoutUpdate` at line 229:

```swift
private static func executeLayoutUpdate(
    _ operations: [LayoutOperation],
    briefing: String?,
    context ctx: ExecutionContext
) -> ActionResult {
    guard let appState = ctx.appState else {
        return .failed("No app state for layout update")
    }
    if appState.homeComposition == nil {
        appState.homeComposition = HomeComposition(sections: [])
    }
    let diff = withAnimation(Animations.layoutSpring) {
        appState.homeComposition!.apply(operations: operations, briefing: briefing)
    }
    try? appState.homeCompositionStore?.save(appState.homeComposition!)
    return .layoutUpdated(diff: diff)
}
```

- [ ] **Step 2: Update ConversationState pattern match**

In `ConversationState.swift` at line 429, the existing code matches `.layoutUpdated(let diff)` — this doesn't change since `ActionResult` stays the same. Verify no compile errors.

- [ ] **Step 3: Update ThreadItem pattern match**

In `ThreadItem.swift` at line 70, update if it pattern-matches `.layoutUpdate`:

```swift
case .layoutUpdate: return .updated
```

This should still work since we're matching on the enum case name, but verify.

- [ ] **Step 4: Update ToolResultBuilder**

In `ToolResultBuilder.swift`, if the briefing was updated, include it in the result summary. At line 52:

```swift
case .layoutUpdated(let diff):
    return formatLayoutDiff(diff)
```

This stays the same — the diff summary already covers what changed.

- [ ] **Step 5: Build the full project**

Run: `make build 2>&1 | tail -20`

Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add Murmur/Services/ Murmur/Models/
git commit -m "fix: update app-layer call sites for layoutUpdate briefing parameter"
```

---

### Task 4: Add zones composition prompt and layout instructions

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:127-146` (agent prompt layout section)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:198-223` (replace navigatorComposition)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:130` (composeHomeView routing)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:279-295` (layoutInstructions)

- [ ] **Step 1: Replace `navigatorComposition` with `zonesComposition`**

In `LLMService.swift`, replace the entire `navigatorComposition` prompt (lines 198-223):

```swift
/// Zones composition prompt: AI-composed hero/standard/habits layout with briefing.
public static let zonesComposition = LLMPrompt(
    systemPrompt: """
        You are composing a home screen for a personal voice assistant app.
        You receive the user's current entries. Select up to 7 entries that deserve attention today.

        Layout: three zones.
        - Hero zone: 1 entry maximum. The single most urgent or important item. Use hero emphasis. \
          Skip this zone entirely if nothing is pressing.
        - Standard zone: 3-5 supporting entries. Use standard emphasis.
        - Habits zone: today's applicable habits. Use compact emphasis. Section title "Today's habits".

        Rules:
        - Badges: "Overdue", "Due today", "Due tomorrow", "P1", "P2", "New".
        - Produce a briefing: one sentence summarizing the day's state.
          Example: "2 items due today, 1 overdue."
        - If nothing deserves focus, return zero sections and a calm briefing like "All clear — nothing pressing today."

        Selection criteria (in priority order):
        1. Overdue entries (due date has passed)
        2. Due today
        3. High priority (P1, P2)
        4. New entries (recently created)
        5. Habits not yet done for the current period
        """,
    tools: [composeViewToolSchema()],
    toolChoice: .function(name: "compose_view")
)
```

- [ ] **Step 2: Update composeHomeView routing in PPQLLMService**

In `PPQLLMService.swift` at line 130, change:

```swift
let prompt: LLMPrompt = variant == .scanner ? .homeComposition : .zonesComposition
```

- [ ] **Step 3: Update layoutInstructions for .zones**

In `PPQLLMService.swift`, replace the `.navigator` case in `layoutInstructions(for:)`:

```swift
static func layoutInstructions(for variant: CompositionVariant) -> String {
    switch variant {
    case .scanner:
        return """
            Group by urgency/context, not category. 3-5 sections, up to 7 items. \
            Hero for urgent (1-2 max), compact for low-priority. \
            Badges: Overdue, Today, Stale, P1, New.
            """
    case .zones:
        return """
            Three zones: hero (1 most urgent item, hero emphasis — skip if nothing pressing), \
            standard (supporting items, standard emphasis), habits (today's habits, compact emphasis). \
            7 items max total. Badges: Overdue, Due today, Due tomorrow, P1, P2, New. \
            Update briefing to reflect current state in one sentence.
            """
    }
}
```

- [ ] **Step 4: Update agent prompt layout section for zones**

In `LLMService.swift`, update the layout tools section of the `agentPrompt` (around line 127-133). Change "Calling update_layout is optional" to be variant-aware. Since the prompt is shared across variants, keep it general but remove the "optional" language:

```swift
Layout tools:
- get_current_layout reads the current home screen layout as JSON.
- update_layout applies incremental changes as an animated batch. Include a briefing sentence summarizing the day.
- After entry operations, call get_current_layout then update_layout to reflect changes.
- If the layout is empty (cold start), build it with add_section + insert_entry.
- See ## Layout Instructions in the user message for the active layout style.
```

- [ ] **Step 5: Build MurmurCore**

Run: `cd Packages/MurmurCore && swift build 2>&1 | head -20`

Expected: Builds clean.

- [ ] **Step 6: Commit**

```bash
git add Packages/MurmurCore/
git commit -m "feat: add zones composition prompt and layout instructions"
```

---

### Task 5: Update AppState — deterministic fallback and variant routing

**Files:**
- Modify: `Murmur/Services/AppState.swift:312-450` (deterministic fallback)

- [ ] **Step 1: Replace navigator fallback with zones fallback**

In `AppState.swift`, update `buildDeterministicComposition`:

```swift
func buildDeterministicComposition(
    entries: [Entry],
    variant: CompositionVariant
) -> HomeComposition {
    switch variant {
    case .scanner:
        return buildScannerFallback(entries: entries)
    case .zones:
        return buildZonesFallback(entries: entries)
    }
}
```

- [ ] **Step 2: Write buildZonesFallback**

Replace `buildNavigatorFallback` with:

```swift
private func buildZonesFallback(entries: [Entry]) -> HomeComposition {
    let now = Date()
    var sections: [ComposedSection] = []
    let maxTotal = 7
    var totalCount = 0
    var usedIDs: Set<String> = []

    // Urgency scoring for hero selection
    func urgencyScore(_ entry: Entry) -> Int {
        var score = 0
        if let due = entry.dueDate, due < now, entry.status == .active { score += 100 }
        if let p = entry.priority { score += p == 1 ? 60 : p == 2 ? 40 : 0 }
        if let due = entry.dueDate, Calendar.current.isDateInToday(due) { score += 25 }
        return score
    }

    // Non-habit entries sorted by urgency
    let tasks = entries
        .filter { $0.category != .habit }
        .sorted { urgencyScore($0) > urgencyScore($1) }

    // Hero zone — top urgent item if score > 0
    if let top = tasks.first, urgencyScore(top) > 0, totalCount < maxTotal {
        let badge: String? = top.isOverdue ? "Overdue" :
            top.dueDate.map { Calendar.current.isDateInToday($0) ? "Due today" : nil } ?? nil
        sections.append(ComposedSection(
            title: "Hero",
            density: .relaxed,
            items: [.entry(ComposedEntry(id: top.shortID, emphasis: .hero, badge: badge))]
        ))
        usedIDs.insert(top.shortID)
        totalCount += 1
    }

    // Standard zone — next items
    var standardItems: [ComposedItem] = []
    for entry in tasks where !usedIDs.contains(entry.shortID) && totalCount < maxTotal {
        standardItems.append(.entry(ComposedEntry(
            id: entry.shortID,
            emphasis: .standard,
            badge: entry.isOverdue ? "Overdue" : nil
        )))
        usedIDs.insert(entry.shortID)
        totalCount += 1
    }
    if !standardItems.isEmpty {
        sections.append(ComposedSection(title: "Up next", density: .relaxed, items: standardItems))
    }

    // Habits zone
    let habits = entries.filter { $0.category == .habit && $0.appliesToday }
    var habitItems: [ComposedItem] = []
    for habit in habits where totalCount < maxTotal {
        habitItems.append(.entry(ComposedEntry(id: habit.shortID, emphasis: .compact)))
        totalCount += 1
    }
    if !habitItems.isEmpty {
        sections.append(ComposedSection(title: "Today's habits", density: .compact, items: habitItems))
    }

    // Deterministic briefing
    let overdueCount = entries.filter { $0.isOverdue }.count
    let dueTodayCount = entries.filter { $0.dueDate.map { Calendar.current.isDateInToday($0) } ?? false }.count
    let habitCount = habits.count
    var parts: [String] = []
    if overdueCount > 0 { parts.append("\(overdueCount) overdue") }
    if dueTodayCount > 0 { parts.append("\(dueTodayCount) due today") }
    if habitCount > 0 { parts.append("\(habitCount) habit\(habitCount == 1 ? "" : "s") today") }
    let briefing = parts.isEmpty ? "All clear — nothing pressing today." : parts.joined(separator: " · ") + "."

    return HomeComposition(sections: sections, composedAt: now, briefing: briefing, variant: .zones)
}
```

- [ ] **Step 3: Delete `buildNavigatorFallback`**

Remove the entire `buildNavigatorFallback` method.

- [ ] **Step 4: Build**

Run: `make build 2>&1 | tail -10`

- [ ] **Step 5: Commit**

```bash
git add Murmur/Services/AppState.swift
git commit -m "feat: zones deterministic fallback, delete navigator fallback"
```

---

### Task 6: Delete SacHomeView and update routing

**Files:**
- Delete: `Murmur/Views/Home/SacHomeView.swift`
- Modify: `Murmur/Views/RootView.swift:27,363-400,500-502`
- Modify: `Murmur/DevMode/DevModeView.swift:7,77-91`
- Modify: `project.yml` (if SacHomeView is listed explicitly)

- [ ] **Step 1: Delete SacHomeView.swift**

```bash
rm Murmur/Views/Home/SacHomeView.swift
```

- [ ] **Step 2: Update DevModeView picker**

In `DevModeView.swift`, change the default and picker:

Update `@AppStorage("homeVariant")` default from `"sac"` to `"scanner"`.

Replace the picker segment with two options:

```swift
Picker("Home View", selection: $homeVariant) {
    Text("Scanner").tag("scanner")
    Text("Zones").tag("zones")
}
.pickerStyle(.segmented)
.frame(width: 180)
```

- [ ] **Step 3: Update RootView default and routing**

In `RootView.swift`, change the AppStorage default:

```swift
@AppStorage("homeVariant") private var homeVariant: String = "scanner"
```

Update `homeContent` view builder:

```swift
@ViewBuilder
private var homeContent: some View {
    if homeVariant == "zones" {
        ZonesHomeView(
            inputText: $inputText,
            entries: activeEntries,
            onMicTap: toggleRecording,
            onSubmit: submitInput,
            onEntryTap: { selectedEntry = $0 },
            onKeyboardTap: { showTextInputBar.toggle() },
            onSettingsTap: { showSettings = true },
            onCalendarTap: { showCalendar = true },
            onAction: { handleEntryAction($0, $1) }
        )
    } else {
        ScannerHomeView(
            inputText: $inputText,
            entries: activeEntries,
            onMicTap: toggleRecording,
            onSubmit: submitInput,
            onEntryTap: { selectedEntry = $0 },
            onSettingsTap: { showSettings = true },
            onAction: { handleEntryAction($0, $1) }
        )
    }
}
```

Update `currentVariant`:

```swift
var currentVariant: CompositionVariant {
    homeVariant == "zones" ? .zones : .scanner
}
```

- [ ] **Step 4: Build to check for any remaining SacHomeView/navigator references**

Run: `make build 2>&1 | tail -20`

Fix any remaining references.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: delete SacHomeView, route scanner/zones only"
```

---

### Task 7: Rename DamHomeView → ScannerHomeView

**Files:**
- Rename: `Murmur/Views/Home/DamHomeView.swift` → `Murmur/Views/Home/ScannerHomeView.swift`

- [ ] **Step 1: Rename the file**

```bash
git mv Murmur/Views/Home/DamHomeView.swift Murmur/Views/Home/ScannerHomeView.swift
```

- [ ] **Step 2: Rename the struct inside**

In `ScannerHomeView.swift`, replace `struct DamHomeView: View` with `struct ScannerHomeView: View`. Also update the Preview at the bottom if it references `DamHomeView`.

- [ ] **Step 3: Update RootView reference**

In `RootView.swift`, the reference was already updated in Task 6 to `ScannerHomeView`. Verify it compiles.

- [ ] **Step 4: Build**

Run: `make build 2>&1 | tail -10`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename DamHomeView to ScannerHomeView"
```

---

### Task 8: Rename ZonedFocusHomeView → ZonesHomeView

**Files:**
- Rename: `Murmur/Views/Home/ZonedFocusHomeView.swift` → `Murmur/Views/Home/ZonesHomeView.swift`

- [ ] **Step 1: Rename the file**

```bash
git mv Murmur/Views/Home/ZonedFocusHomeView.swift Murmur/Views/Home/ZonesHomeView.swift
```

- [ ] **Step 2: Rename the struct inside**

In `ZonesHomeView.swift`, replace `struct ZonedFocusHomeView: View` with `struct ZonesHomeView: View`. Also rename `ZonedFocusTabView` → `ZonesTabView`, `ZonedFocusItem` → `ZonesItem`, `ZonedItems` → `ZonesItems`.

Update the Preview at the bottom too.

- [ ] **Step 3: Update RootView reference**

Already updated in Task 6. Verify no stale references.

- [ ] **Step 4: Build**

Run: `make build 2>&1 | tail -10`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: rename ZonedFocusHomeView to ZonesHomeView"
```

---

### Task 9: Wire Zones view to use composition for cold start

**Files:**
- Modify: `Murmur/Views/Home/ZonesHomeView.swift`

- [ ] **Step 1: Verify ZonesTabView already reads from composition**

The current `ZonedFocusTabView` (now `ZonesTabView`) already reads `composition: appState.homeComposition` and uses `zoneItems(composition:)` to split into hero/standard/habits. This is already wired — the composition just wasn't being generated with the right variant before.

Verify that `ZonesHomeView.populatedState` passes `appState.homeComposition` to `ZonesTabView`. It should from the existing code.

- [ ] **Step 2: Ensure no recentInserts dependency**

Grep `ZonesHomeView.swift` for `recentInserts`. It should have zero references. If any exist, remove them.

- [ ] **Step 3: Build and test cold start**

Run: `make run`

Expected: App launches, Zones view loads composition via LLM (now using `zonesComposition` prompt), displays hero/standard/habits zones.

- [ ] **Step 4: Commit (if any changes were needed)**

```bash
git add Murmur/Views/Home/ZonesHomeView.swift
git commit -m "feat: verify Zones view uses AI composition for cold start"
```

---

### Task 10: Update layout refresh path for briefing

**Files:**
- Modify: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:225-246` (refresh prompt)
- Modify: `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift:148-166,224-236` (refresh return type + parsing)
- Modify: `Murmur/Services/AppState.swift:270-301` (refresh caller)

- [ ] **Step 1: Update layoutRefresh prompt to include briefing**

In `LLMService.swift`, update the layout refresh prompt:

```swift
public static let layoutRefresh = LLMPrompt(
    systemPrompt: """
        You are refreshing a home screen layout for a voice assistant app.
        You receive the current layout (JSON) and the current entries.
        Compare them and output update_layout operations to bring the layout up to date.

        Rules:
        - Remove entries no longer active (completed, archived, deleted).
        - Add entries that deserve attention but are missing from the layout.
        - Update badges based on current dates: "Overdue" if past due, "Today" if due today, etc.
        - Move entries whose urgency or context has changed.
        - Update emphasis if priority has shifted.
        - Update the briefing to reflect the current state in one sentence.
        - Preserve the overall layout structure — minimize churn.
        - If no changes are needed, call update_layout with an empty operations array (but still update the briefing).
        - See ## Layout Instructions for the active layout style constraints.

        Always call update_layout exactly once.
        """,
    tools: [updateLayoutToolSchema()],
    toolChoice: .function(name: "update_layout")
)
```

- [ ] **Step 2: Update parseLayoutOperations to return briefing**

In `PPQLLMService.swift`, change `parseLayoutOperations` to return both:

```swift
private func parseLayoutResult(from assistantMessage: [String: Any]) -> (operations: [LayoutOperation], briefing: String?) {
    guard let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]],
          let firstCall = toolCalls.first,
          let function = firstCall["function"] as? [String: Any],
          let name = function["name"] as? String, name == "update_layout",
          let argsString = function["arguments"] as? String,
          let argsData = argsString.data(using: .utf8),
          let wrapper = try? JSONDecoder().decode(UpdateLayoutArguments.self, from: argsData)
    else {
        return ([], nil)
    }
    return (wrapper.operations.compactMap { $0.asOperation }, wrapper.briefing)
}
```

- [ ] **Step 3: Update refreshLayout return type**

In `PPQLLMService.swift`, update `refreshLayout` to return briefing:

```swift
public func refreshLayout(
    entries: [AgentContextEntry],
    currentLayout: HomeComposition,
    variant: CompositionVariant
) async throws -> (operations: [LayoutOperation], briefing: String?, usage: TokenUsage) {
    sseLog.info("[SSE] refreshLayout(\(variant.rawValue)) called — \(entries.count) entries")
    let conversation = LLMConversation()
    let userContent = buildRefreshUserContent(entries: entries, layout: currentLayout, variant: variant)

    let turn = try await runTurn(
        userContent: userContent,
        prompt: .layoutRefresh,
        conversation: conversation
    )

    let result = parseLayoutResult(from: turn.assistantMessage)
    sseLog.info("[SSE] refreshLayout() complete — \(result.operations.count) operations, usage: in=\(turn.usage.inputTokens) out=\(turn.usage.outputTokens)")
    return (result.operations, result.briefing, turn.usage)
}
```

- [ ] **Step 4: Update AppState.requestLayoutRefresh caller**

In `AppState.swift`, update the refresh caller around line 270-301:

Change the guard to allow briefing-only updates (no operations but has briefing):

```swift
let result = try await llmService.refreshLayout(
    entries: agentEntries,
    currentLayout: currentComposition,
    variant: variant
)

try Task.checkCancellation()

event.tokensIn = result.usage.inputTokens
event.tokensOut = result.usage.outputTokens
event.toolCalls = result.operations.isEmpty ? [] : ["update_layout"]
event.actionCount = result.operations.count
event.track()

guard !result.operations.isEmpty || result.briefing != nil else { return }

let receipt = try await creditGate.charge(
    authorization,
    usage: result.usage,
    pricing: pricing
)
StudioAnalytics.track(CreditCharged(
    requestId: event.requestId.uuidString,
    credits: receipt.creditsCharged,
    balanceAfter: receipt.newBalance
))
await self.refreshCreditBalance()

_ = withAnimation(Animations.layoutSpring) {
    self.homeComposition!.apply(operations: result.operations, briefing: result.briefing)
}
try? self.homeCompositionStore?.save(self.homeComposition!)
```

- [ ] **Step 5: Update LLMService protocol if refreshLayout is defined there**

Check if `refreshLayout` has a protocol signature in `LLMService.swift`. If so, update the return type to match.

- [ ] **Step 6: Build full project**

Run: `make build 2>&1 | tail -20`

- [ ] **Step 7: Commit**

```bash
git add Packages/MurmurCore/ Murmur/Services/AppState.swift
git commit -m "feat: layout refresh path now returns and applies briefing"
```

---

### Task 11: Full build + generate + manual test

**Files:** None (verification only)

- [ ] **Step 1: Regenerate Xcode project**

Run: `make generate`

- [ ] **Step 2: Full build**

Run: `make build`

Expected: Clean build, zero errors.

- [ ] **Step 3: Run unit tests**

Run: `make core-test`

Expected: All MurmurCore tests pass.

- [ ] **Step 4: Run on simulator**

Run: `make run`

Manual verification:
1. App launches in Scanner view (default)
2. Switch to Zones in DevMode — composition loads with hero/standard/habits zones
3. Create an entry via keyboard — agent calls update_layout with briefing
4. Briefing updates after entry creation
5. All tab still works on both views
6. Switch back to Scanner — recentInserts behavior unchanged

- [ ] **Step 5: Verify no navigator references remain**

Run: `grep -ri "navigator\|SacHomeView\|DamHomeView\|sac2\|\"sac\"" Murmur/ Packages/ --include="*.swift" | grep -v ".build/"`

Expected: Zero results (or only in git history/comments).

- [ ] **Step 6: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final cleanup and verification"
```
