---
id: "000"
title: "Focus strip polish + confirmation flow cleanup"
status: completed
author: IsaacMenge
project: Murmur
tags: [focus-strip, confirmation, UX, animation, LLM]
sessions:
  - id: 0fe25443
    slug: focus-strip-height-and-confirmation-start
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: current
    slug: confirmation-flow-completion
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
prompts: []
created: "2026-03-03"
updated: "2026-03-03"
---

# 000: Focus strip polish + confirmation flow cleanup

## Context

Two adjacent PRs shipped in the same arc. The focus strip (#80) had a layout hack that caused visible
empty space on days with few focus items. The confirmation surface (#84) had dead transcript UI,
no way to edit proposed entries before confirming, and a silent UX bug where the LLM could propose
conflicting actions for the same entry.

---

## Timeline

### Phase 1: Focus strip height fix → PR #80 (`0fe25443`, ~1 session)

**What**: Replaced a fixed-height shimmer hack with natural sizing + layout animations.

**The problem**: `FocusContainerView` used a `GeometryReader` inside a `ZStack` to lock the section
height to the shimmer's height while focus cards staggered in. This prevented the categories below
from jumping down on each card appearing — but the inverse broke: when the LLM returned fewer items
than shimmer reserved (or nothing at all), the section sat padded with dead air.

**Decision — remove the hack entirely**: Let the section be naturally sized. Instead, gate layout
animations on the outer container so categories slide smoothly when focus height changes. Two
`.animation()` modifiers on the parent `VStack`, keyed to `isFocusLoading` and `items.count`.

**Decision — LazyVStack → VStack**: The outer category container was `LazyVStack`. `LazyVStack`
doesn't participate reliably in layout animations — it's a rendering optimization, not a layout
primitive. With at most 7 categories, the swap is safe and gives SwiftUI what it needs to animate
position changes.

**Decision — shimmer → text indicator**: Replaced 3 skeleton card placeholders (`FocusShimmerView`)
with a minimal `FocusLoadingView`: dimmed greeting + pulsing "Murmur is selecting your focus…"
subtitle. Less visual noise, communicates intentionality vs. generic loading bars.

**Problems**: None significant. The `LazyVStack` → `VStack` insight came from recognizing that
layout animations require SwiftUI to know all children upfront.

---

### Phase 2: Confirmation flow cleanup → PR #84 (`0fe25443` + current session)

**What**: Removed dead transcript UI, added tap-to-edit on proposed create cards, fixed LLM action
deduplication, added a user-facing hint header.

**Decision — remove transcript UI**: `EntryDetailView` had an `onViewTranscript` callback and
"View transcript" button. Raw transcripts are internal data — no user-facing value. Removed from
`EntryDetailView`, `RootView`, `DevScreen`. Clean deletion, no replacement needed.

**Decision — tap-to-edit on create cards**: Confirmation mode showed proposed create actions as
static cards. If the LLM extracted the wrong category or misspelled the summary, the only option
was Deny + re-record. Added pencil icon → `EntryEditSheet` flow. Edits stored in
`createOverrides[Int: CreateAction]`, merged in `buildFinalActions` before `onConfirm` fires.
Cycling (complete↔archive) and editing are mutually exclusive by action type — one gesture per
card type.

**Decision — dedup by first occurrence**: Discovered in testing that the LLM sometimes proposes
both `complete_entries` and `archive_entries` for the same entry ID in a single confirmation call.
The user saw two conflicting cards with no clear resolution path. Fixed in `parseProposedActions`
by filtering to the first action per entry ID using a `Set<String>`. Added `mutationEntryID`
computed property on `AgentAction` to keep the filter logic clean and reusable. The dedup-first
policy is a simplification — if the LLM's intent is genuinely ambiguous, surfacing one action
(the first) is better than surfacing the conflict.

**Decision — confirmation header**: The surface appeared with no explanation — the pill badges
were tappable to cycle actions but there was nothing telling the user that. Added a header row:
`sparkles` icon + "Murmur wants to…" left-aligned, "Tap action to change" tertiary caption
right-aligned. Subtle but present on first view.

**Problems**:
- SwiftLint caught `Int? = nil` (implicit optional init) on new `@State` vars — fixed to `Int?`
- `confirmationContent` body hit function body length limit after adding the header — extracted
  `confirmationHeader` as a computed property
- `parseProposedActions` hit cyclomatic complexity limit after adding dedup — extracted
  `deduplicateByEntryID` helper

---

## Developer Patterns Observed

- **Hacks that fix one thing break the inverse** — the shimmer height lock prevented jump-on-load
  but caused empty space on sparse days. The right fix was to not lock height at all and trust
  SwiftUI's animation system.
- **`LazyVStack` is not a drop-in for `VStack` when animations matter** — this is a non-obvious
  SwiftUI constraint worth remembering.
- **SwiftLint as a forcing function for structure** — function body length violations pushed
  extraction of `confirmationHeader` and `deduplicateByEntryID`, both of which are genuinely
  cleaner as named units.
- **Test the inverse case** — the focus strip bug only appeared on days with 0–1 focus items.
  Worth checking both the happy path and the sparse/empty case for any dynamic-height UI.

---

## Artifacts

_No screenshots captured for this arc._

---

## Open Questions

- Is dedup-by-first the right policy for conflicting LLM actions? Alternative: prefer a specific
  action type (e.g. always keep `complete` over `archive`). Current approach is simpler and
  adequate given the LLM rarely produces conflicts.
- Is 3 the right focus item cap, or should it adapt to screen space?

---

## What's Next

PR #84 is open for review. Next available frontend work from the board:
- Waveform audio visualization (#35)
- Archive swipe actions (#43)
- Zero-extraction handling (#38)
