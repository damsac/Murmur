---
date: 2026-03-03
topic: entry-arrival-animation
---

# Entry Arrival Animation

## What We're Building

Replace the bolted-on confirmation overlay (`ResultsSurfaceView`) with inline entry arrival animations. When the agent creates/updates/completes/archives entries, they animate into their actual positions on the home screen in real-time (via SSE streaming). No confirmation step, no undo — trust the agent.

Text-only agent responses (no actions) surface via a bottom-anchored toast.

## Why This Approach

The confirmation surface was a separate card system — its own layout, its own colors, its own interaction model. It didn't share DNA with the home screen. The agent is right most of the time, so confirmation adds friction without value.

The real need is **feedback**: the user speaks, and they see things happen. The animation itself is the feedback. Entries land where they belong.

Approaches considered:
- **Confirmation overlay** (current) — feels bolted on, parallel card system. Rejected.
- **Inline proposed state** — entries appear ghosted, confirm commits. Beautiful but complex. Deferred to v2.
- **Minimal toast summary** — "Created 2 notes." Too abstract, user doesn't see what landed. Rejected.
- **Auto-commit with undo** — close, but undo adds UI for a rare case. Simplified to no undo.
- **Auto-commit with arrival animation** — chosen. Zero new UI, entries animate into place.

## Key Decisions

- **Rip out `ResultsSurfaceView` and `ConfirmationData` entirely.** Clean break, not dead code.
- **No undo UI.** Trust the agent. User can swipe-to-archive/delete any card if needed.
- **Collapsed section peek:** When a new entry lands in a collapsed section, a peek slot opens below the header showing the card for ~3s, then retracts. This respects the user's layout choices while still showing what arrived.
- **Text-only responses use bottom toast.** Agent text with no actions → toast anchored to bottom (above mic button), not an overlay.
- **Glow = "new".** Category-colored glow border on arrival, fades over ~2s. Same pattern as `FocusCardView` glow.

## Animation Spec

### Expanded section — entry arrives
1. Entry inserts at top of section list
2. Spring animation (scale 0.97 → 1.0, opacity 0 → 1, slight y-offset)
3. Category-colored glow border (`cardStyle(accent:intensity:)`)
4. Glow intensity animates 1.0 → 0 over ~2s
5. Entry is now a normal card

### Collapsed section — peek
1. Section header pulses briefly (category color glow)
2. Peek slot opens below header (height animates from 0 → card height)
3. New entry slides into peek slot with same spring + glow
4. After ~3s, peek slot animates closed (height → 0, clipped)
5. Entry remains inside collapsed section data

### Collapsed section — multiple arrivals (SSE stream)
1. Each new entry replaces previous in peek slot
2. Header badge shows count: "+1", "+2", "+3"
3. Retract timer resets with each arrival (last entry gets full 3s)
4. Peek always shows most recent entry

### User interaction during peek
- Tap peeked card → expand section fully, cancel retract
- Tap section header → normal expand toggle
- Swipe peeked card → same swipe actions as any card

### Cross-section cascade
- Entries from SSE land in different sections independently
- Each section manages its own peek timer
- Creates a ripple effect — things landing across the screen

## What Gets Removed

- `ResultsSurfaceView` (the overlay component)
- `ResultsSurfaceData`, `AppliedActionInfo` models
- `ConfirmationData` model
- `ProposedActionKind` enum (tap-to-cycle)
- `ConversationState.pendingResults`, `pendingConfirmation`, `showResultsSurface`
- Confirm/deny callbacks in `RootView`
- `DenialLogStore` (logged denied confirmations)

## What Gets Modified

- `ConversationState` — new flow: SSE actions → entries appear directly, no pending state
- `HomeView` / `CategorySectionView` — peek slot animation, glow on new entries
- `RootView` — remove `ResultsSurfaceView` overlay, wire bottom toast for text responses
- `ToastView` — anchor to bottom instead of top (or new bottom variant)

## Open Questions

- SSE streaming implementation is in progress (separate work). This design assumes entries arrive one-by-one. If they arrive as a batch, the stagger animation needs to be synthetic (delay between insertions).
- Should the peek auto-expand if the user is actively scrolling that section? Probably not for v1.

## Next Steps

-> Plan implementation: rip out old surface, add peek animation to CategorySectionView, wire bottom toast.
