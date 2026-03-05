---
title: "feat: Composable AI-Composed Home View"
type: feat
status: active
date: 2026-03-04
brainstorm: docs/brainstorms/2026-03-04-composable-home-view-brainstorm.md
---

# Composable AI-Composed Home View

## Overview

Replace the hardcoded home view layout with an AI-composed rendering engine. The LLM composes the entire home screen from three primitives (Section, Entry, Message) via a `compose_view` tool. The app renders whatever the AI produces. Build in `DamHomeView.swift`, toggle via dev mode — SacHomeView stays untouched.

**Core insight:** The agent's response IS a layout change, not text. The UI is the conversation medium.

## Problem Statement

The current home view has fixed structure: focus strip (3 curated entries) + hardcoded category sections. The AI only controls which 3 entries appear in focus. Everything else — grouping, density, visibility, prominence — is static SwiftUI. Users see the same layout regardless of context, time of day, or what actually matters right now.

## Proposed Solution

Three composable primitives rendered by a SwiftUI engine:
- **Section**: grouped items with optional title and density (compact/relaxed)
- **Entry**: reference to an entry with emphasis level (hero/standard/compact) and optional badge
- **Message**: AI-written text embedded in the layout

Two composition modes:
- **Standard**: sectioned home view composed on app open, cached per-day
- **Spotlight**: full-screen focused display triggered conversationally (Phase 3)

Auto-insert pattern: new entries from agent loop stack above composed sections like an inbox. Recompose sweeps them into place.

## Technical Approach

### Architecture

```
┌─────────────────────────────────────────┐
│ AppState                                │
│   composition: HomeComposition?         │
│   recentInserts: [RecentInsert]         │
│   isComposing: Bool                     │
│   homeCompositionStore: Store?          │
│                                         │
│   requestHomeComposition(entries:)      │
│   invalidateHomeComposition()           │
├─────────────────────────────────────────┤
│ MurmurCore                              │
│   LLMPrompt.homeComposition             │
│   compose_view tool schema              │
│   PPQLLMService.composeHomeView()       │
│   HomeComposition data types            │
├─────────────────────────────────────────┤
│ DamHomeView                             │
│   ComposedSectionView                   │
│   ComposedEntryView (hero/std/compact)  │
│   ComposedMessageView                   │
│   RecentInsertRow                       │
│   CompositionShimmerView                │
└─────────────────────────────────────────┘
```

### Implementation Phases

---

#### Phase 1: Data Model + Tool + Basic Renderer

Foundation — get a composed view rendering from LLM output.

##### 1.1 Data Types in MurmurCore

**File:** `Packages/MurmurCore/Sources/MurmurCore/HomeComposition.swift` (new)

```swift
public struct HomeComposition: Codable, Sendable {
    public let sections: [ComposedSection]
    public let composedAt: Date

    public var isFromToday: Bool {
        Calendar.current.isDateInToday(composedAt)
    }
}

public struct ComposedSection: Codable, Sendable, Identifiable {
    public let id: UUID  // auto-generated for SwiftUI ForEach
    public let title: String?
    public let density: SectionDensity
    public let items: [ComposedItem]

    public init(title: String? = nil, density: SectionDensity = .relaxed, items: [ComposedItem]) {
        self.id = UUID()
        self.title = title
        self.density = density
        self.items = items
    }
}

public enum SectionDensity: String, Codable, Sendable {
    case compact
    case relaxed
}

public enum ComposedItem: Codable, Sendable, Identifiable {
    case entry(ComposedEntry)
    case message(String)

    public var id: String {
        switch self {
        case .entry(let e): return "entry-\(e.id)"
        case .message(let t): return "msg-\(t.prefix(20).hashValue)"
        }
    }
}

public struct ComposedEntry: Codable, Sendable {
    public let id: String           // 6-char short ID
    public let emphasis: EntryEmphasis
    public let badge: String?

    public init(id: String, emphasis: EntryEmphasis = .standard, badge: String? = nil) {
        self.id = id
        self.emphasis = emphasis
        self.badge = badge
    }
}

public enum EntryEmphasis: String, Codable, Sendable {
    case hero
    case standard
    case compact
}
```

**Codable strategy for `ComposedItem`:** Use a discriminator key `"type"` with custom `init(from:)` / `encode(to:)`. The JSON shape matches the tool schema:

```json
{ "type": "entry", "id": "a3f2c1", "emphasis": "standard", "badge": "Overdue" }
{ "type": "message", "text": "Quiet morning." }
```

- [x] Create `HomeComposition.swift` in MurmurCore with all types above
- [x] Implement custom Codable for `ComposedItem` enum with `"type"` discriminator
- [x] Add unit tests for round-trip encoding/decoding

##### 1.2 compose_view Tool Schema

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

Add `composeViewToolSchema()` following the pattern of `composeFocusToolSchema()` (line 715):

```json
{
  "name": "compose_view",
  "description": "Compose the home view. Surface what matters right now. Most entries stay hidden. Group by urgency/context, not category. 3-5 sections max, 5-15 total items.",
  "parameters": {
    "sections": [{
      "title": "string?",
      "density": "compact|relaxed (default: relaxed)",
      "items": [{
        "type": "entry|message",
        "id": "string (entry short ID, for type=entry)",
        "emphasis": "hero|standard|compact (default: standard)",
        "badge": "string? (Overdue, Today, New, Stale, etc.)",
        "text": "string (for type=message)"
      }]
    }]
  }
}
```

- [x] Add `composeViewToolSchema()` to `LLMPrompt` tools
- [x] Add `LLMPrompt.homeComposition` case with system prompt and forced `tool_choice`
- [x] Add parsing in `PPQLLMService`: `parseHomeComposition()` from tool call arguments

##### 1.3 System Prompt for Home Composition

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift`

New `LLMPrompt.homeComposition` case. Prompt guidance:

```
You are composing a home screen for a personal voice assistant app.
You receive the user's current entries. Compose 3-5 sections showing what matters RIGHT NOW.

Rules:
- Most entries stay hidden. Show 5-15 items total.
- Group by urgency and context, NOT by category.
- First section: what needs attention now (overdue, due today, P1/P2). Use relaxed density, hero emphasis for urgent items.
- Later sections: things to keep in mind, upcoming items. Use compact density.
- Include a brief message (under 15 words) if it adds context. Don't force one.
- Assign badges: "Overdue" for past-due, "Today" for due today, "Stale" for untouched 7+ days.
- Use hero emphasis sparingly (1-2 items max). Compact for low-priority items.
- If nothing is urgent, compose a calm view with a reassuring message.
- If no entries exist, return zero sections.
```

- [x] Write `homeComposition` prompt case
- [ ] Wire temporal context (morning/afternoon, weekday/weekend)
- [ ] Test with `make core-scenarios` (add composition test scenarios)

##### 1.4 PPQLLMService.composeHomeView()

**File:** `Packages/MurmurCore/Sources/MurmurCore/PPQLLMService.swift`

Mirror `composeDailyFocus()` (line 119):

```swift
public func composeHomeView(entries: [AgentContextEntry]) async throws -> HomeComposition
```

- One-shot, non-streaming call
- Fresh `LLMConversation()` (not the ongoing conversation)
- Forced `toolChoice: .function(name: "compose_view")`
- Parse tool call arguments → `HomeComposition`

- [x] Implement `composeHomeView()` in PPQLLMService
- [x] Add `buildCompositionUserContent()` (entry list formatted for composition)
- [x] Add `parseHomeComposition()` for tool call result parsing

##### 1.5 HomeCompositionStore

**File:** `Murmur/Services/HomeCompositionStore.swift` (new)

Mirror `DailyFocusStore.swift`:

```swift
final class HomeCompositionStore {
    func load() -> HomeComposition?
    func save(_ composition: HomeComposition)
    func clear()
}
```

Saves to `Documents/home-composition.json`.

- [x] Create `HomeCompositionStore` following `DailyFocusStore` pattern
- [x] Initialize in `AppState.configurePipeline()`

##### 1.6 AppState Integration

**File:** `Murmur/Services/AppState.swift`

Add alongside `dailyFocus`:

```swift
var homeComposition: HomeComposition?
var isHomeCompositionLoading: Bool = false
var homeCompositionStore: HomeCompositionStore?

func requestHomeComposition(entries: [Entry]) async { ... }
func invalidateHomeComposition() { ... }
```

`requestHomeComposition` follows same pattern as `requestDailyFocus` (line 105):
1. Cache check → `homeCompositionStore?.load()`, check `isFromToday`
2. Authorize credits
3. Call `llmService.composeHomeView(entries:)`
4. Charge credits, persist, set `homeComposition`
5. Fallback: `buildDeterministicComposition(entries:)`

**Deterministic fallback** builds a proper `HomeComposition`:
- Section 1 "Needs attention" (relaxed): overdue + P1/P2 entries as hero/standard
- Section 2 "Recent" (compact): last 5 created entries as compact
- No message (deterministic = no LLM personality)

- [x] Add composition state properties to AppState
- [x] Implement `requestHomeComposition(entries:)`
- [x] Implement `invalidateHomeComposition()`
- [x] Implement `buildDeterministicComposition(entries:)`
- [x] Initialize `homeCompositionStore` in `configurePipeline()`

##### 1.7 DamHomeView — Basic Renderer

**File:** `Murmur/Views/Home/DamHomeView.swift`

Replace placeholder with composition renderer:

```swift
struct DamHomeView: View {
    @Environment(AppState.self) private var appState
    // ... existing interface props ...

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if appState.isHomeCompositionLoading && appState.homeComposition == nil {
                    CompositionShimmerView()
                }

                if let composition = appState.homeComposition {
                    ForEach(composition.sections) { section in
                        ComposedSectionView(
                            section: section,
                            entries: entries,
                            onEntryTap: onEntryTap,
                            onAction: onAction
                        )
                    }
                }

                if entries.isEmpty && !appState.isHomeCompositionLoading {
                    emptyState
                }
            }
        }
        .onAppear {
            Task {
                await appState.requestHomeComposition(entries: entries)
            }
        }
    }
}
```

##### 1.8 Composed Section View

**File:** `Murmur/Views/Home/DamHomeView.swift` (private views within, or separate file)

```swift
struct ComposedSectionView: View {
    let section: ComposedSection
    let entries: [Entry]
    let onEntryTap: (Entry) -> Void
    let onAction: (Entry, EntryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            if let title = section.title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.horizontal, Theme.Spacing.screenPadding)
            }

            VStack(spacing: itemSpacing) {
                ForEach(resolvedItems) { item in
                    switch item {
                    case .entry(let entry, let composed):
                        ComposedEntryView(
                            entry: entry,
                            emphasis: composed.emphasis,
                            badge: composed.badge,
                            onTap: { onEntryTap(entry) },
                            onAction: { action in onAction(entry, action) }
                        )
                    case .message(let text):
                        ComposedMessageView(text: text)
                    }
                }
            }
        }
    }

    // Resolve entry short IDs against actual entries, drop unresolvable
    private var resolvedItems: [ResolvedItem] { ... }

    private var sectionSpacing: CGFloat {
        section.density == .compact ? 8 : 16
    }
    private var itemSpacing: CGFloat {
        section.density == .compact ? 4 : 8
    }
}
```

- [x] Implement `ComposedSectionView` with entry resolution
- [x] Silently drop entries that fail `Entry.resolve(shortID:in:)`
- [x] Hide sections that become empty after resolution

##### 1.9 Entry Emphasis Renderers

Three visual treatments in `ComposedEntryView`:

**Hero** — large card, full content:
- `.cardStyle(accent: categoryColor)` with subtle glow
- `CategoryBadge(size: .medium)`
- Full summary text, priority badge, due date, badge annotation
- Tappable, swipeable

**Standard** — medium card (like current `SmartListRow`):
- `.cardStyle()` without glow
- `CategoryBadge(size: .small)`
- Summary + metadata row
- Tappable, swipeable

**Compact** — single line:
- Category dot (6pt) + summary text + optional badge
- No card container, just a row with subtle bottom border
- Tappable (no swipe — too small)
- `Theme.Spacing.screenPadding` horizontal padding

- [x] Implement `ComposedEntryView` with emphasis switch
- [x] Hero: reuse patterns from `FocusCardView`
- [x] Standard: reuse patterns from `SmartListRow`
- [x] Compact: new minimal row
- [x] Wire `SwipeableCard` for hero and standard (not compact)

##### 1.10 Message Renderer

```swift
struct ComposedMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.vertical, 8)
    }
}
```

- [x] Implement `ComposedMessageView`

##### 1.11 Composition Shimmer

Simple loading placeholder while LLM composes:

- 2 sections with faded placeholder rows
- Breathing pulse animation (reuse pattern from `FocusShimmerView`)
- "Composing your view..." text

- [x] Implement `CompositionShimmerView`

##### 1.12 DevMode — Recompose Button

**File:** `Murmur/DevMode/DevModeView.swift`

Add "Recompose Home" button after "Regenerate Daily Focus" (line 151), following same visual pattern but with `accentBlue`:

```swift
Button {
    appState.invalidateHomeComposition()
    dismiss()
} label: {
    HStack(spacing: 8) {
        Image(systemName: "rectangle.3.group")
        Text("Recompose Home")
    }
    // ... accentBlue styling ...
}
```

Wire in RootView: on DevModeView dismiss, if `homeVariant == "dam"`, trigger `requestHomeComposition`.

- [x] Add "Recompose Home" button to DevModeView
- [x] Wire dismiss handler in RootView to trigger recomposition

##### 1.13 Empty State

When `entries.isEmpty`, show a hardcoded empty state (no LLM call on zero entries — burns credits for nothing):

- Reuse pulse animation concept from SacHomeView's empty state
- "Say or type anything to get started"
- Mic button tap

- [x] Implement empty state in DamHomeView (skip LLM composition when zero entries)

##### Phase 1 Acceptance Criteria

- [ ] DamHomeView renders AI-composed sections from `compose_view` tool output
- [ ] Composition is cached per-day, loaded from cache on subsequent opens
- [ ] Deterministic fallback works when LLM unavailable
- [ ] Dev mode "Recompose Home" triggers fresh composition
- [ ] Three emphasis levels render visually distinct
- [ ] Two density levels render with appropriate spacing
- [ ] Stale entry references silently dropped, empty sections hidden
- [ ] Empty state shown when no entries exist
- [ ] Entry tap navigates to detail view
- [ ] Swipe actions work on hero/standard entries

---

#### Phase 2: Auto-Insert Flow

New entries from the agent loop appear above the composed layout.

##### 2.1 RecentInsert State

**File:** `Murmur/Services/AppState.swift`

```swift
enum RecentInsert: Identifiable {
    case entry(UUID)
    case message(String, UUID)  // text + unique ID for ForEach

    var id: String { ... }
}

var recentInserts: [RecentInsert] = []

func addRecentEntry(_ id: UUID) { recentInserts.insert(.entry(id), at: 0) }
func addRecentMessage(_ text: String) { recentInserts.insert(.message(text, UUID()), at: 0) }
func clearRecentInserts() { recentInserts.removeAll() }
```

Ephemeral — in-memory only, not persisted. Cleared on recompose.

- [x] Add `RecentInsert` enum and `recentInserts` to AppState
- [x] Add helper methods for insert and clear

##### 2.2 Wire Agent Loop → Auto-Insert

**File:** `Murmur/Services/ConversationState.swift`

In `consumeAgentStream()` (line 311), after `AgentActionExecutor.execute()`:

```swift
case .toolCallCompleted(let result):
    let execResult = AgentActionExecutor.execute(...)
    // Existing: track arrived entries for animation
    trackArrivedEntries(execResult.applied)
    // New: add to recent inserts for DamHomeView
    for applied in execResult.applied where applied.action == .create {
        appState.addRecentEntry(applied.entry.id)
    }
```

For text-only responses (agent returns text, no tool calls):

```swift
case .completed(let response):
    if let text = response.textResponse, !text.isEmpty {
        appState.addRecentMessage(text)
    }
```

- [x] Wire `addRecentEntry` calls for created entries in `consumeAgentStream`
- [x] Wire `addRecentMessage` for text-only agent responses
- [x] Clear recent inserts in `invalidateHomeComposition()`

##### 2.3 Render Recent Inserts in DamHomeView

```swift
var body: some View {
    ScrollView {
        VStack(spacing: 0) {
            // Recent inserts above composed content
            if !appState.recentInserts.isEmpty {
                ForEach(appState.recentInserts) { insert in
                    switch insert {
                    case .entry(let id):
                        if let entry = entries.first(where: { $0.id == id }) {
                            ComposedEntryView(entry: entry, emphasis: .standard, ...)
                        }
                    case .message(let text, _):
                        ComposedMessageView(text: text)
                    }
                }
                .padding(.bottom, 16)
            }

            // Composed sections below
            ...
        }
    }
}
```

- [x] Render recent inserts above composed sections
- [ ] Entry arrivals use existing glow animation (`arrivedEntryIDs`)
- [x] Visual separator between recent inserts and composed content

##### Phase 2 Acceptance Criteria

- [ ] New entries created by agent appear at top of home view
- [ ] Agent text responses appear as inline messages
- [ ] Recent inserts stack newest-first
- [ ] Recompose clears recent inserts
- [ ] Entries in recent area are tappable and swipeable
- [ ] Arrival glow animation works on recent inserts

---

#### Phase 3: Spotlight Mode

Full-screen focused display triggered conversationally.

##### 3.1 Spotlight Tool Integration

Add `compose_view` to the `entryManager` tool list with `toolChoice: .auto`. Add prompt guidance:

```
You also have compose_view available. Use it ONLY for spotlight mode when the user asks to see specific entries ("show me my ideas", "what's most urgent?"). Never use it for standard recomposition during normal conversation.
```

- [ ] Add `compose_view` to `entryManager` tools
- [ ] Add prompt guidance restricting to spotlight-only during agent loop
- [ ] Parse `compose_view` tool calls in `consumeAgentStream`

##### 3.2 Spotlight View

Full-screen overlay rendered at zIndex 10 (below BottomNavBar at 50, below recording at 20):

```swift
if let spotlight = appState.spotlightComposition {
    SpotlightView(composition: spotlight, entries: entries)
        .zIndex(10)
        .transition(.move(edge: .bottom))
        .gesture(DragGesture().onEnded { value in
            if value.translation.height > 100 {
                withAnimation { appState.spotlightComposition = nil }
            }
        })
}
```

- [ ] Add `spotlightComposition: HomeComposition?` to AppState
- [ ] Implement `SpotlightView` — renders one section full-screen with hero entries
- [ ] Swipe-down dismiss gesture (threshold: 100pt)
- [ ] BottomNavBar stays visible during spotlight
- [ ] Starting recording dismisses spotlight
- [ ] App backgrounding dismisses spotlight

##### Phase 3 Acceptance Criteria

- [ ] "Show me my ideas" triggers spotlight with curated idea entries
- [ ] Spotlight renders full-screen with dismiss gesture
- [ ] BottomNavBar visible during spotlight
- [ ] Recording dismisses spotlight first
- [ ] Backgrounding app clears spotlight

---

#### Phase 4: Polish + Prompt Tuning

##### 4.1 Prompt Iteration

- [ ] Test with 0, 5, 20, 50, 100 entries
- [ ] Tune section count and item limits
- [ ] Test temporal awareness (morning vs evening compositions)
- [ ] Validate badge assignment accuracy

##### 4.2 Stale Entry Handling

- [ ] Count stale entries on cache load
- [ ] If >50% of composed entries fail resolution, auto-recompose
- [ ] Log stale resolutions for debugging

##### 4.3 "All Entries" Escape Hatch

- [ ] Add "Show all entries" button at bottom of composed view
- [ ] Navigates to a full entry list (category-grouped, reusing SacHomeView's `entriesByCategory` logic)
- [ ] Ensures no entries feel "lost"

##### 4.4 Animations

- [ ] Shimmer → composed view transition (crossfade)
- [ ] Recompose transition (old fades out → shimmer → new fades in)
- [ ] Auto-insert arrival (spring + glow, reusing existing `Animations.cardAppear`)

---

## Acceptance Criteria

### Functional Requirements

- [ ] DamHomeView renders AI-composed layout from `compose_view` tool
- [ ] Three entry emphasis levels (hero/standard/compact) visually distinct
- [ ] Two section densities (compact/relaxed) with appropriate spacing
- [ ] Composition cached per-day, loaded from cache on app open
- [ ] Deterministic fallback when LLM unavailable
- [ ] New entries auto-insert above composed sections
- [ ] Agent text responses render as inline messages
- [ ] Dev mode "Recompose Home" triggers fresh composition
- [ ] Empty state when no entries exist (no LLM call)
- [ ] Entry tap → detail view works on all emphasis levels
- [ ] Swipe actions work on hero/standard entries
- [ ] Colored category dots preserved on all entry renderings
- [ ] Stale entries silently dropped, empty sections hidden
- [ ] Spotlight mode renders full-screen with dismiss gesture (Phase 3)

### Quality Gates

- [ ] Builds without warnings (`make build`)
- [ ] SacHomeView completely unaffected (no regressions)
- [ ] Composition round-trip encode/decode unit tests pass
- [ ] LLM composition tested with `make core-scenarios`

## Dependencies & Prerequisites

- Existing `compose_focus` and `DailyFocusStore` patterns (template)
- Existing `SmartListRow`, `FocusCardView`, `SwipeableCard` components (reuse)
- Existing `Theme` system (colors, spacing, animations)
- Existing `arrivedEntryIDs` tracking in `ConversationState`
- PPQ.ai API access for LLM calls

## Risk Analysis & Mitigation

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| LLM produces poor compositions | Medium | Strong prompt guidance + deterministic fallback + dev mode refresh |
| LLM returns invalid JSON | Low | Existing `ToolCallParser` handles this; fallback to deterministic |
| Composition burns too many credits | Medium | One-shot call per day (cached); cap entry context to 50 entries |
| Users can't find hidden entries | High | "All entries" escape hatch at bottom of composed view |
| Stale cached compositions | Medium | Auto-recompose when >50% entries stale |

## References

### Internal References

- Brainstorm: `docs/brainstorms/2026-03-04-composable-home-view-brainstorm.md`
- Current focus system: `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:715` (compose_focus schema)
- DailyFocusStore pattern: `Murmur/Services/DailyFocusStore.swift`
- AppState focus flow: `Murmur/Services/AppState.swift:105` (requestDailyFocus)
- DamHomeView target: `Murmur/Views/Home/DamHomeView.swift`
- DevMode toggle: `Murmur/DevMode/DevModeView.swift:68` (homeVariant picker)
- Entry resolution: `Murmur/Models/Entry.swift:220` (resolve shortID)
- Theme system: `Murmur/Theme/Theme.swift`
- Arrival animations: `Murmur/Services/ConversationState.swift:453` (trackArrivedEntries)
- Agent stream consumption: `Murmur/Services/ConversationState.swift:311` (consumeAgentStream)
