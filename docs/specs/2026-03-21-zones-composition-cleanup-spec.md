# Zones Composition + Navigator Cleanup

**Date:** 2026-03-21
**Status:** Draft

## Summary

Remove the Navigator view entirely. Rename remaining views from dam/sac names to Scanner/Zones. Give Zones full AI composition (cold start + inline layout updates with briefing). Each view gets its own `CompositionVariant` with philosophy-specific prompts and layout instructions.

## What Changes

### 1. Delete Navigator (SacHomeView)

Remove:
- `Murmur/Views/Home/SacHomeView.swift` — the entire file
- `LLMPrompt.navigatorComposition` — the navigator-specific composition prompt
- `CompositionVariant.navigator` — the enum case
- All `"sac"` routing in RootView, DevModeView, AppState
- Navigator-specific layout instructions in `PPQLLMService.layoutInstructions(for:)`
- Navigator test cases in `HomeCompositionTests.swift`

After deletion, only two variants exist: `.scanner` and `.zones`.

### 2. Rename Views

| Before | After | Variant | DevMode Label |
|--------|-------|---------|---------------|
| DamHomeView | ScannerHomeView | `.scanner` | "Scanner" |
| ZonedFocusHomeView | ZonesHomeView | `.zones` | "Zones" |

**AppStorage tag mapping:**
- `"scanner"` → ScannerHomeView (`.scanner` variant)
- `"zones"` → ZonesHomeView (`.zones` variant)

Default homeVariant changes from `"sac"` to `"scanner"`.

### 3. Add `.zones` CompositionVariant

New enum case in `HomeComposition.swift`:

```swift
public enum CompositionVariant: String, Codable, Sendable {
    case scanner
    case zones
}
```

### 4. Zones Composition Prompt

New `LLMPrompt.zonesComposition` — used for cold start `compose_view` on the Zones view.

Philosophy: AI decides the full layout. Three zones — hero (1 most urgent item), standard (supporting items), habits (today's habits). The LLM picks what goes where based on urgency, priority, and due dates.

Prompt guidance:
- One hero item maximum (most urgent/important). Skip hero if nothing is pressing.
- Standard items: 3-5 supporting entries sorted by relevance.
- Habits: today's applicable habits, separate section.
- 7 items max total.
- Briefing: one sentence summarizing the day's state.
- Emphasis: hero for the hero slot, standard for supporting, compact for habits.
- Badges: Overdue, Due today, Due tomorrow, P1, P2, New.

### 5. Zones Layout Instructions

New case in `PPQLLMService.layoutInstructions(for:)`:

```
Three zones: hero (1 urgent item, hero emphasis), standard (supporting items, standard emphasis),
habits (today's habits, compact emphasis). 7 items max total. Hero section optional — skip if
nothing is pressing. Badges: Overdue, Due today, Due tomorrow, P1, P2, New.
Update briefing to reflect current state in one sentence.
```

### 6. Add `briefing` to `update_layout` Tool

Add optional `briefing` string parameter to `updateLayoutToolSchema()`:

```json
{
  "briefing": {
    "type": "string",
    "description": "Update the greeting subtitle. One sentence summarizing the day."
  }
}
```

Parsing: `ToolCallParser` and `PPQLLMService.parseActions` extract `briefing` from the tool call args alongside `operations`.

Application: `HomeComposition.apply(operations:briefing:)` — if briefing is non-nil, update `self.briefing`.

### 7. Zones Agent Prompt — `update_layout` Is Expected

For the `.zones` variant, the system prompt layout section changes from "Calling update_layout is optional" to:

> After entry operations, call update_layout to place entries in the layout and update the briefing.
> Maintain the zones hierarchy — only promote an item to hero if it genuinely takes precedence.
> Items not placed via update_layout will only appear in the All tab.

This makes the agent actively manage the Zones layout as part of its normal response.

### 8. Zones Deterministic Fallback

When composition fails or hasn't loaded yet, `AppState.buildDeterministicComposition(for: .zones)` generates a client-side layout:
- Sort active entries by urgency score (overdue > high priority > due today)
- First item → hero section
- Next 4-5 → standard section
- Today's habits → habits section
- 7 items max
- Briefing: generated from entry counts (e.g., "2 items due today · 1 habit")

This replaces the current client-side `urgencyScore()` sorting in `ZonedFocusTabView.zoneItems()` — that logic moves to the fallback only.

### 9. Zones View Does NOT Use recentInserts

Unlike ScannerHomeView, ZonesHomeView does not render `appState.recentInserts`. Entries not placed by `update_layout` only appear in the All tab. The agent is responsible for placing entries.

### 10. View Template Pattern

Both views follow:
1. Same init signature (entries, callbacks, bindings)
2. Top bar (calendar + settings)
3. Empty state (mic + prompt)
4. Populated state: Focus tab (variant-specific) + All tab (shared `AllEntriesView`)
5. Swipe actions provider
6. Composition-driven Focus rendering with deterministic fallback

## Files Changed

| File | Change |
|------|--------|
| `SacHomeView.swift` | **Delete** |
| `ZonedFocusHomeView.swift` | Rename to `ZonesHomeView.swift`, consume composition for zones |
| `DamHomeView.swift` | Rename to `ScannerHomeView.swift` |
| `HomeComposition.swift` | Replace `.navigator` with `.zones` |
| `LLMService.swift` | Delete `navigatorComposition`, add `zonesComposition`, add briefing to `updateLayoutToolSchema` |
| `PPQLLMService.swift` | Update `layoutInstructions(for:)`, update `composeHomeView` routing, parse briefing from `update_layout` |
| `ToolCallParser.swift` | Parse briefing from `update_layout` tool calls |
| `AppState.swift` | Update deterministic fallback for `.zones`, remove `.navigator` references |
| `RootView.swift` | Update routing: `"scanner"` → ScannerHomeView, `"zones"` → ZonesHomeView, remove `"sac"` |
| `DevModeView.swift` | Two-option picker: "Scanner"/"Zones", tags `"scanner"`/`"zones"`, default `"scanner"` |
| `ToolResultBuilder.swift` | Format briefing update in tool result summary |
| `AgentActionExecutor.swift` | Pass briefing through to composition apply |
| `HomeCompositionTests.swift` | Update tests: `.navigator` → `.zones` |

## Out of Scope

- Standalone debounced layout diff request (deferred — agent handles inline for now)
- Changes to ScannerHomeView behavior (stays as-is with recentInserts)
- Changes to AllEntriesView (shared, unchanged)
