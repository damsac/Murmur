---
date: 2026-03-04
topic: composable-layout-diffs
---

# Composable Layout System via Diffs

## What We're Building

A single layout primitive: **diffs**. The agent controls the home screen layout through incremental operations (insert, remove, move, update) applied to a persistent, mutable composition. There is no separate "compose from scratch" tool — a fresh layout is just a big batch of inserts from an empty state. An incremental update is one or two operations.

This is the foundation for a system where the agent has full UI flexibility — different users get different layouts based on their psychological profile, and the agent can evolve the layout over time without blowing away the current state.

## Why Diffs, Not Recomposition

The previous approach (`compose_view` rebuilding the entire layout) has problems that get worse as the system grows:

- **Wasteful:** Regenerating 5 sections and 15 items when one entry changed
- **Lossy:** A full recompose might shuffle things the user or agent liked about the current layout
- **Animation-hostile:** Hard to animate from state A to state B when you don't know what changed
- **Expensive:** Full recompose = full token cost every time

Diffs solve all of these:

- **Token-efficient:** "insert entry X at position 2" is tiny
- **Surgical:** Only what changed, changes
- **Animation-native:** Each operation maps directly to a SwiftUI animation (insert = fade in, remove = fade out, move = matched geometry)
- **Composable:** Same operations work regardless of layout complexity. Add new component types later, diff system still works.
- **Unified:** Cold start and incremental updates use the same tool and the same client code

## Architecture

### Two tools in the agent pipeline

**`get_current_layout`** — read-only, returns the current composition state:
```json
{
  "sections": [
    {
      "title": "NEEDS ATTENTION",
      "density": "relaxed",
      "items": [
        { "type": "entry", "id": "abc123", "emphasis": "hero", "badge": "Overdue" },
        { "type": "entry", "id": "def456", "emphasis": "standard", "badge": "Today" }
      ]
    },
    {
      "title": "ON THE RADAR",
      "density": "compact",
      "items": [
        { "type": "entry", "id": "ghi789", "emphasis": "compact" }
      ]
    }
  ]
}
```

Returns full item details (not just counts) so the agent can make informed decisions about what to move/remove. Returns `{ "sections": [] }` when composition is empty (fresh start).

**`update_layout`** — applies a batch of operations:
```json
{
  "operations": [
    { "op": "add_section", "title": "TOMORROW", "density": "relaxed", "position": 1 },
    { "op": "insert_entry", "entry_id": "xyz789", "section": "TOMORROW", "position": 0, "emphasis": "compact", "badge": "New" },
    { "op": "remove_entry", "entry_id": "abc123" },
    { "op": "move_entry", "entry_id": "def456", "to_section": "TOMORROW", "to_position": 1 },
    { "op": "update_entry", "entry_id": "ghi789", "emphasis": "standard", "badge": "Stale" },
    { "op": "remove_section", "title": "NEEDS ATTENTION" },
    { "op": "update_section", "title": "TOMORROW", "density": "compact" }
  ]
}
```

Operations are applied in order. The client applies the full batch as a single animated transaction.

### Operation types

| Operation | Fields | Animation |
|-----------|--------|-----------|
| `add_section` | title, density, position (optional) | Section slides in |
| `remove_section` | title | Section collapses out |
| `update_section` | title, density (optional), new_title (optional) | Cross-fade |
| `insert_entry` | entry_id, section, position (optional), emphasis, badge (optional) | Fade in + scale spring |
| `remove_entry` | entry_id | Fade out + scale down |
| `move_entry` | entry_id, to_section, to_position (optional) | matchedGeometryEffect |
| `update_entry` | entry_id, emphasis (optional), badge (optional) | Cross-fade |

`position` is optional — if omitted, entry appends to end of section.

### State ownership: MurmurCore

The composition state and diff engine live in `MurmurCore`:

- `HomeComposition` becomes a mutable, persistent data structure
- `LayoutOperation` enum defines the operation types
- `HomeComposition.apply(operations:)` mutates the composition and returns a `LayoutDiff` describing what changed (for animation)
- `HomeCompositionStore` persists to disk (already exists, just needs to handle mutable state)
- No `@MainActor` dependency — accessible from background tasks

The client (AppState) holds the composition, calls `apply()`, and wraps the result in `withAnimation` for SwiftUI.

```swift
// In MurmurCore
public struct LayoutDiff {
    public let insertedEntries: [(id: String, section: String)]
    public let removedEntries: [String]
    public let movedEntries: [(id: String, from: String, to: String)]
    public let updatedEntries: [String]
    public let addedSections: [String]
    public let removedSections: [String]
}

// In AppState
func applyLayoutUpdate(operations: [LayoutOperation]) {
    let diff = homeComposition.apply(operations: operations)
    // Use diff to drive animations
    withAnimation(Animations.cardAppear) {
        // SwiftUI picks up the composition changes via @Observable
    }
    homeCompositionStore.save(homeComposition)
}
```

## Data Flows

### Cold start (app launch, no cached composition)
```
AppState loads composition from disk → empty
Agent pipeline triggers (or explicit compose request)
Agent calls get_current_layout → { sections: [] }
Agent calls update_layout with batch:
  add_section("NEEDS ATTENTION", relaxed)
  add_section("TOMORROW", relaxed)
  add_section("ON THE RADAR", compact)
  insert_entry("abc123", "NEEDS ATTENTION", hero, "Overdue")
  insert_entry("def456", "TOMORROW", standard)
  insert_entry("ghi789", "ON THE RADAR", compact)
  ... (5-15 entries total)
Client applies batch → all entries appear with staggered arrival animation
```

### Incremental update (user says "Buy milk")
```
Agent processes transcript → creates entry via create_entries
Agent calls get_current_layout → sees current sections
Agent calls update_layout:
  insert_entry("xyz789", "TOMORROW", position: 0, compact, "New")
Client applies → entry fades in at position in TOMORROW section
```

### Entry completed
```
Agent completes entry via complete_entries
Agent calls get_current_layout → sees entry in NEEDS ATTENTION
Agent calls update_layout:
  remove_entry("abc123")
  (optionally: remove_section("NEEDS ATTENTION") if now empty)
Client applies → entry fades out, section collapses if removed
```

### Priority change
```
Agent updates entry priority P4 → P1
Agent calls update_layout:
  move_entry("def456", to_section: "NEEDS ATTENTION", to_position: 0)
  update_entry("def456", emphasis: hero, badge: "Urgent")
Client applies → entry animates from TOMORROW to NEEDS ATTENTION with emphasis change
```

## What This Enables Long-Term

- **Psychological profiles:** Agent learns user prefers dense layouts vs. spacious ones, adjusts density and emphasis accordingly. Same diff primitive, different choices.
- **New component types:** Add new emphasis levels (e.g., `timeline`, `grouped`, `progress`) by extending `EntryEmphasis` and adding corresponding views. Diff operations don't change.
- **Section types beyond entries:** Message cards, charts, streaks, summaries — all can be items in the composition, inserted/removed via the same diff system.
- **Per-user layouts:** dam and sac already have different home views. This system lets the agent compose each one differently without separate codepaths.
- **Background intelligence:** Agent can recompose in background tasks (e.g., "it's now 6pm, shift emphasis from work items to evening items") because composition state lives in MurmurCore, not in UI code.

## Key Decisions

- **One primitive (diffs):** No separate compose_view. Cold start = batch insert. This unifies all composition paths.
- **State in MurmurCore:** Persistable, testable, accessible from background. Client wraps with animation.
- **Entry-level operations:** Granular enough for precise animation, coarse enough to keep the tool schema simple.
- **Operations applied in order:** Agent controls sequencing. Client applies as single animated transaction.
- **get_current_layout returns full items:** Agent needs to see what's in each section to make good diff decisions.

## Open Questions

- **Should `update_layout` be available in the main agent pipeline, or only triggered explicitly?** Leaning toward: available in the main pipeline. Agent decides when to update layout based on what it just did.
- **How to handle the agent NOT calling `update_layout` after creating entries?** Fallback: entries without placement appear in `recentInserts` (current behavior). Ensures nothing is invisible.
- **Should operations validate?** E.g., `insert_entry` into a section that doesn't exist. Options: fail silently, create section implicitly, or return error to agent. Leaning toward: fail silently + entry goes to recentInserts.
- **`update_layout` response format?** What does the client return to the agent after applying? Confirmation? Updated section state? Leaning toward: simple confirmation + any errors.
- **Existing `compose_view` one-shot path?** Deprecate or keep as a convenience that expands to add_section + insert_entry operations internally? Leaning toward: deprecate over time, but no rush.

## Migration Path

1. Make `HomeComposition` mutable, add `apply(operations:)` in MurmurCore
2. Add `get_current_layout` + `update_layout` tools to agent pipeline
3. Wire `update_layout` execution in `AgentActionExecutor`
4. Update `DamHomeView` to animate based on `LayoutDiff`
5. Update agent system prompt to mention layout tools
6. Keep `recentInserts` as fallback for entries without placement
7. Keep existing `compose_view` one-shot path working (it still populates the initial composition on app launch until the agent learns to do it via diffs)
8. Eventually: agent handles cold start via diffs too, `compose_view` deprecated

## Next Steps

→ Plan implementation starting from MurmurCore data model changes
