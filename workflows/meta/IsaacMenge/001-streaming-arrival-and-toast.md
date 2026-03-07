---
id: "001"
title: "Streaming arrival system + toast"
status: completed
author: IsaacMenge
project: Murmur
tags: [streaming, animation, ux, swiftui, toast, convo-state]
previous: "000"
sessions:
  - id: 63b5638e
    slug: sse-streaming-pr86
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: 0fe25443
    slug: card-arrival-toast
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: (current)
    slug: polish-due-reason-color
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
prompts: []
created: "2026-03-04T00:00:00Z"
updated: "2026-03-04T00:00:00Z"
---

# 001: Streaming arrival system + toast

## Context

PR #86 shipped full SSE streaming: tool calls execute progressively as they arrive. Entries now materialize in the view one-by-one rather than all-at-once after the LLM finishes. The remaining UX question was: how do you close the loop with the user? When does the app signal "done"? This entry documents the card arrival animation system and the toast that answers that question — plus the bugs discovered in testing.

---

## Timeline

### Phase 1: SSE streaming + confirmation removal (`63b5638e`, ~March 4 2026)

**What**: Built the streaming pipeline end-to-end and deleted the confirmation surface.

**Decisions**:
- **Progressive execution** — execute each tool call immediately when it completes streaming, not after the full response. Entries appear as the LLM generates them.
- **Delete ResultsSurfaceView** — the "confirm these entries" review screen was cognitive overhead. With streaming, the progressive reveal IS the feedback loop.
- **Dedup by first-seen** — `deduplicateByEntryID()` in `PPQLLMService` filters duplicate actions for the same entry (e.g., complete + archive). First-wins chosen as a safe default; flagged for dam review.
- **Shimmer → text loading indicator** — `FocusShimmerView` (3 placeholder cards) replaced with `FocusLoadingView` (pulsing "Murmur is selecting your focus…" text). Removes fixed-height reservation.

**Problems**:
- Tool calls arrive as partial JSON over SSE — can't parse until the closing brace. `StreamingResponseAccumulator` buffers incrementally and attempts parse on each newline, emitting `.toolCallCompleted` only when JSON is valid.
- Confirmation UI and streaming pipeline were incompatible architecturally. Solution: just delete the confirmation surface rather than trying to adapt it.

---

### Phase 2: Card arrival animations + toast (`0fe25443`, ~March 3–4 2026)

**What**: Built the system that hides new entries until their staggered reveal moment, plays an arrival glow, and fires a toast after the last card lands.

**Decisions**:
- **`pendingRevealEntryIDs: Set<UUID>`** — entries are hidden from `activeEntries` in `RootView` immediately after creation (before the reveal task fires). This prevents a visible pop-in at full opacity.
- **`arrivedEntryIDs: Set<UUID>`** — entries are added here at reveal time (driving the glow animation in `CategorySectionView`), then removed after 5 seconds.
- **`lastRevealTime: Date`** — tracks the wall-clock time of the latest scheduled reveal across all batches. Correctly handles multi-batch streaming by always keeping the maximum.
- **`toastTask: Task<Void, Never>?`** stored as a class property — cancellable; cancelled at the start of every new request. Toast delay = `max(0, lastRevealTime.timeIntervalSinceNow) + 1.5s`.
- **`completionText: String?`** — observable property on `ConversationState`; set by the toast task, observed by an `.onChange` in `RootView`.
- **Toast delay settled at 1.5s** after several iterations (tried 0.5, 1.2, 2.0, 2.5, back to 1.5).

**Problems**:
- **Cards re-popped after toast appeared** — `CategorySectionView.onChange(of: arrivedEntryIDs)` used `{ _, newIDs in }` and checked all of `newIDs`. When entries were *removed* from `arrivedEntryIDs` (glow expiry after 5s), remaining entries still in `newIDs` triggered `showPeek()` again. Fixed by diffing: `let added = newIDs.subtracting(oldIDs)`.
- **First card in a new category silently dropped** — `onChange` doesn't fire on initial render. If a new `CategorySectionView` is created mid-stream (first entry in a category creates it), the peek never triggers. Fixed with `onAppear` that checks `arrivedEntryIDs` immediately on mount, guarded by `!arrivedEntryIDs.isEmpty` to prevent firing on normal app launch.

---

### Phase 3: Focus section polish (`current session`, ~March 4 2026)

**What**: Two display correctness fixes on the home screen.

**Decisions**:
- **`dueText` category guard** — `GlowingEntryRow.dueText` showed "Due tomorrow" on any entry with a `dueDate`, including habits. Added `guard entry.category == .todo || entry.category == .reminder` to match the same filter `EntryDetailView` already used for due date UI. The LLM can emit `dueDate` on habits; the view shouldn't render it.
- **Focus card reason color semantics** — `FocusCardView` always rendered the LLM reason (e.g., "Due", "Stale") in red with an exclamation mark. "Due tomorrow" shouldn't be alarming. Added `isOverdue`/`isDueSoon` computed properties; now: overdue → red + `exclamationmark.circle.fill`, due soon → yellow + `calendar`, everything else → secondary text + `circle.fill`.

---

## Architecture Snapshot

```
ConversationState
  pendingRevealEntryIDs: Set<UUID>   — entries hidden during reveal delay
  arrivedEntryIDs: Set<UUID>         — entries currently glowing
  lastRevealTime: Date               — latest scheduled reveal across all batches
  toastTask: Task<Void, Never>?      — cancellable; fires completionText
  completionText: String?            — observed by RootView onChange → toast

RootView
  activeEntries (computed)           — filters out pendingRevealEntryIDs + pendingDeleteEntry
  onChange(completionText)           — shows toast, clears completionText

CategorySectionView
  onChange(arrivedEntryIDs) { old, new }  — peeks on additions only
  onAppear                                — peek if entries already arrived (new-category case)
```

---

## Developer Patterns Observed

- **Diffing SwiftUI onChange is easy to get wrong** — using `{ _, newIDs in }` (ignoring old) is almost always a bug when the set can shrink. Always destructure to `{ old, new in }` and check additions/removals separately.
- **`onAppear` as the `onChange` fallback for initial state** — when a view can be created into an "already interesting" state (entries already arrived before the view existed), `onChange` alone is insufficient. `onAppear` + a guard against empty initial state is the pattern.
- **Wall-clock anchoring for multi-batch delays** — using `Date()` snapshots to compute future delays (rather than accumulating `asyncSleep` durations) is robust to batching. `lastRevealTime = max(lastRevealTime, Date().addingTimeInterval(delay))` just works.
- **Stored cancellable `Task` for deferred work** — `toastTask?.cancel()` on every request start is lightweight and correct. Avoids needing a structured concurrency hierarchy for "show toast after streaming completes."
- **View-level urgency overrides LLM labels** — the LLM's 1-word reason ("Overdue", "Due", "Stale") is a hint, but actual due date math should drive color. String-matching LLM output for visual treatment is fragile; real entry data is reliable.

---

## Open Questions

- **Dedup policy**: is first-wins correct, or should "stronger" actions win (archive > complete)? Flagged for dam — relevant if a user voice note says "finish and archive all the old tasks."
- **Uncancellable anonymous tasks in `trackArrivedEntries`** — the individual card reveal tasks (`.sleep` → `pendingRevealEntryIDs.remove`) can't be cancelled if a new request starts mid-reveal. In practice this is fine (the entry just glows briefly on the new request), but a fully correct implementation would cancel them too.

## What's Next

- Ship post-#86 cleanup PR: dedup logic + transcript UI removal + shimmer → `FocusLoadingView`
- Consider whether dedup-by-first or dedup-by-strongest makes more sense (coordinate with dam)
