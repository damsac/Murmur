---
date: 2026-03-04
topic: composable-home-view
---

# Composable Home View: AI-Composed Layout

## What We're Reimagining

The current home view is hardcoded: focus strip (3 curated entries) + category sections (static grouping). The AI only curates the focus strip via `compose_focus`. Everything else — layout, grouping, density, visibility — is fixed SwiftUI.

**The new model:** the AI composes the **entire home view** from composable primitives. The app becomes a rendering engine for AI-composed layouts. The agent controls what you see, how it's grouped, what's prominent, and what's hidden.

**Core insight:** The agent's response IS a layout change, not text. "Show me my ideas" → full-screen ideas. "Add a todo" → entry flows in. "What should I focus on?" → composed focus sections. The UI is the conversation.

## Component Vocabulary

Three primitives. Intentionally minimal — small enough that the LLM uses them well.

### 1. Section

A group of items with optional title and density control.

```
{ title: "Handle today",  density: "relaxed", items: [...] }
{ title: "Backlog",        density: "compact", items: [...] }
{ items: [...] }  // untitled section — just items with space between
```

- `title` (optional): section header text
- `density`: `compact` (tight single-line rows) | `relaxed` (cards with breathing room)
- `items`: ordered array of entries and messages

### 2. Entry

A reference to an entry with display hints. The AI controls emphasis and annotation.

```
{ id: "a3f2c1", emphasis: "hero" }      // large, prominent card
{ id: "b7e4d9", emphasis: "standard" }  // normal card
{ id: "c8f1a2", emphasis: "compact" }   // single line
{ id: "d2e5f8", badge: "Overdue" }      // annotated with badge
```

- `id`: entry short ID (6-char prefix)
- `emphasis` (default `standard`): `hero` | `standard` | `compact`
- `badge` (optional): annotation text — "Overdue", "New", "Today", "Stale", etc.

### 3. Message

AI-written text embedded in the layout. Replaces toasts and text responses.

```
{ text: "Quiet morning — just one thing needs attention." }
{ text: "Moved your grocery run to Saturday." }
```

## Composition Modes

### Standard

The normal home view. Sections of entries and messages arranged by the AI.

```
[Auto-inserted entries (recent, not yet composed)]
[Composed sections...]
```

The AI decides: what's visible, grouping, order, density, prominence. Most entries are NOT shown — only what matters right now.

### Spotlight

Full-screen focused display. One entry or a curated set with nothing else on screen. Dismiss gesture returns to standard.

Use cases:
- "Show me an interesting idea I've had" → spotlight a single idea
- "What's my most urgent thing?" → spotlight the top priority
- "Read me back that note about the API design" → spotlight the note

The spotlight IS the agent's response to a query. Instead of text, the agent shows you the thing.

## Auto-Insert Flow

New entries created during the agent loop appear above the composed layout:

```
┌─────────────────────────┐
│ [new] Grocery list       │  ← just created, flows in
│ [new] Call dentist        │  ← auto-inserted
├─────────────────────────┤
│ ◆ Handle today           │  ← composed section (relaxed)
│   ┌─────────────────┐   │
│   │ Fix auth bug  P1 │   │
│   └─────────────────┘   │
│                          │
│ ◆ Keep in mind           │  ← composed section (compact)
│   API redesign idea      │
│   Research vector DBs    │
│   Weekly review habit    │
│                          │
│ "All clear after these   │  ← composed message
│  two — rest can wait."   │
└─────────────────────────┘
```

**On recompose**: auto-inserts get cleared, everything is re-arranged into the composition. Recompose happens:
- On app open (cached per-day, like current daily focus)
- On dev-mode refresh button
- NOT on every agent mutation (too expensive)

**Agent messages during loop** also auto-insert as message items:
- "Moved grocery run to Saturday" flows in alongside new entries
- Part of "what just happened" — not part of the composed layout

## Data Model

```swift
struct HomeComposition: Codable {
    let mode: CompositionMode       // .standard | .spotlight
    let sections: [ComposedSection]
    let composedAt: Date
}

enum CompositionMode: String, Codable {
    case standard
    case spotlight
}

struct ComposedSection: Codable {
    let title: String?
    let density: SectionDensity
    let items: [ComposedItem]
}

enum SectionDensity: String, Codable {
    case compact   // single-line rows
    case relaxed   // cards with space
}

enum ComposedItem: Codable {
    case entry(ComposedEntry)
    case message(String)
}

struct ComposedEntry: Codable {
    let id: String                  // 6-char short ID
    let emphasis: EntryEmphasis
    let badge: String?
}

enum EntryEmphasis: String, Codable {
    case hero       // large prominent card
    case standard   // normal card
    case compact    // single line
}
```

**View state:**

```swift
struct HomeViewState {
    var composition: HomeComposition?     // AI-composed layout
    var recentInserts: [RecentInsert]     // entries + messages since last compose
    var isComposing: Bool                 // shimmer state
}

enum RecentInsert {
    case entry(UUID)          // reference to SwiftData entry
    case message(String)      // agent response text
}
```

## Tool Schema: `compose_view`

Replaces `compose_focus`. Used for both standard and spotlight compositions.

```json
{
  "name": "compose_view",
  "description": "Compose the user's home view. Decide what to show, how to group it, and what to emphasize. Most entries should be hidden — only surface what matters right now. Use spotlight mode to show a specific entry or curated set full-screen.",
  "parameters": {
    "type": "object",
    "properties": {
      "mode": {
        "type": "string",
        "enum": ["standard", "spotlight"],
        "description": "standard = sectioned home view. spotlight = full-screen focused display."
      },
      "sections": {
        "type": "array",
        "description": "Ordered sections. For spotlight, use 1 section with 1-3 hero entries.",
        "items": {
          "type": "object",
          "properties": {
            "title": { "type": "string", "description": "Optional section header" },
            "density": { "type": "string", "enum": ["compact", "relaxed"], "default": "relaxed" },
            "items": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "type": { "type": "string", "enum": ["entry", "message"] },
                  "id": { "type": "string", "description": "Entry short ID (for type=entry)" },
                  "emphasis": { "type": "string", "enum": ["hero", "standard", "compact"], "default": "standard" },
                  "badge": { "type": "string", "description": "Optional annotation (Overdue, New, Today, etc.)" },
                  "text": { "type": "string", "description": "Message text (for type=message)" }
                },
                "required": ["type"]
              }
            }
          },
          "required": ["items"]
        }
      }
    },
    "required": ["mode", "sections"]
  }
}
```

## Agent Integration

### On App Open

Like current `composeDailyFocus`, but produces a full `HomeComposition`:

1. Check `HomeCompositionStore` for cached composition from today
2. If valid cache → use it
3. Otherwise → call LLM with `compose_view` tool (forced tool_choice)
4. Persist to disk
5. Fallback: deterministic layout (overdue → high priority → recent, grouped by category)

**Prompt guidance:**
- "Compose the home view for this user right now"
- "Surface what matters: overdue, due today, high priority, stale items"
- "Group by context/urgency, not category"
- "Most entries stay hidden — show 5-15 items max"
- "Use compact density for lower-priority groups"
- "Include a brief message if useful"

### During Agent Loop

The agent does NOT recompose during normal entry creation. Instead:

1. Agent creates/updates/completes entries via existing tools
2. New entries auto-insert at the top of the home view
3. Agent messages (text responses) also auto-insert as message items
4. The composed layout sits below, unchanged

**Future enhancement:** Agent could optionally call `compose_view` during the loop for spotlight responses ("show me my ideas" → spotlight).

### Dev Mode

- "Recompose Home" button in dev mode
- Clears cache + recentInserts
- Triggers fresh `compose_view` call
- Shows shimmer during generation

## Rendering Strategy

### Standard Mode

```swift
ScrollView {
    // Recent inserts (above composed content)
    if !recentInserts.isEmpty {
        ForEach(recentInserts) { insert in
            switch insert {
            case .entry(let id): RecentEntryRow(entry: resolve(id))
            case .message(let text): InlineMessageView(text: text)
            }
        }
    }

    // Composed sections
    if let composition = composition {
        ForEach(composition.sections) { section in
            ComposedSectionView(section: section, entries: allEntries)
        }
    }
}
```

### Spotlight Mode

Full-screen overlay with dismiss gesture:

```swift
if composition?.mode == .spotlight {
    SpotlightView(composition: composition, entries: allEntries)
        .transition(.move(edge: .bottom))
        .gesture(DragGesture().onEnded { ... }) // dismiss
}
```

### Entry Emphasis Rendering

- **Hero**: Large card, full content display, colored category dot, prominent badge
- **Standard**: Medium card, summary + metadata, category dot, subtle badge
- **Compact**: Single line — dot + summary + optional badge, minimal chrome

### Section Density

- **Relaxed**: Cards with 12-16pt spacing, rounded containers, shadows
- **Compact**: Tight list, 4-8pt spacing, no containers, just lines with dots

## What This Replaces

| Current | New |
|---------|-----|
| `compose_focus` tool | `compose_view` tool |
| `FocusStripView` | Composed sections (first section often serves same purpose) |
| `CategorySectionView` (hardcoded) | AI-composed sections (dynamic grouping) |
| `AgentToastView` / text responses | Message components in auto-insert flow |
| `ResultsSurfaceView` | Auto-inserted entries + messages |
| Fixed category grouping | AI-chosen grouping (urgency, context, theme) |
| Same layout for everyone always | Personalized, time-aware, context-aware |

## What Stays

- Colored category dots (user explicitly wants these)
- Entry model (SwiftData, same schema)
- Agent tools (create/update/complete/archive) — unchanged
- Recording UI (BottomNavBar, waveform, recording state)
- SwipeableCard gestures on entries
- Entry detail view (tap to expand)

## Key Decisions

1. **Three primitives only**: section, entry, message. Resist adding more until proven necessary.
2. **Auto-insert over recompose**: New entries flow in; recompose is periodic, not reactive.
3. **Spotlight = agent's answer**: Instead of text responses, the agent shows you the thing.
4. **Composition cached per-day**: Like daily focus. Recompose on app open, not on every mutation.
5. **5-15 items max**: The AI hides most entries. Only what matters now.
6. **Grouping by context, not category**: The AI groups by urgency/theme, not by hardcoded category.
7. **Build in DamHomeView**: All composable home work lives in `DamHomeView.swift`. Toggle via dev mode (sac/dam picker). SacHomeView stays untouched. DevMode "Regenerate Daily Focus" becomes "Recompose Home" for dam variant.

## Open Questions

1. **Spotlight dismiss**: Swipe down? Tap outside? Back button? What returns you to standard?
2. **Animation**: How do auto-inserts animate in? (Current: staggered glow.) How does recompose transition?
3. **Feedback loop**: How does the user tell the AI "I don't want this here"? Swipe away? Long-press menu? Verbal?
4. **Prompt engineering**: How much prompt guidance does the AI need to compose well? Need to prototype and iterate.
5. **Compose during agent loop**: When should the agent use spotlight vs auto-insert? Need clear prompt guidance.
6. **Entry visibility**: Entries not in the composition — are they findable? Search? Archive view? "Show all"?
7. **compose_focus migration**: Keep compose_focus for backward compat, or replace entirely?

## Next Steps

→ `/workflows:plan` for implementation — phased approach:
1. Phase 1: Data model + compose_view tool + basic renderer (standard mode only)
2. Phase 2: Auto-insert flow + agent integration
3. Phase 3: Spotlight mode
4. Phase 4: Prompt tuning + polish
