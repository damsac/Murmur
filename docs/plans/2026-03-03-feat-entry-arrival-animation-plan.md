---
title: "feat: Entry Arrival Animation"
type: feat
status: completed
date: 2026-03-03
---

# Entry Arrival Animation

## Overview

Replace the `ResultsSurfaceView` confirmation overlay with inline entry arrival animations. When the agent creates/updates/completes/archives entries via SSE streaming, they animate into their actual positions on the home screen. Collapsed sections peek open briefly to show new arrivals. Text-only responses appear as a bottom toast.

**Brainstorm:** `docs/brainstorms/2026-03-03-entry-arrival-animation-brainstorm.md`

## Problem Statement

The current confirmation surface (`ResultsSurfaceView`) is a parallel card system — its own layout, colors, and interaction model that doesn't share DNA with the home screen. The agent is right most of the time, so confirmation adds friction without value. Users need to see *where* things landed, not approve them.

## Proposed Solution

Auto-commit with arrival animation. The SSE stream executes actions immediately (already wired in `ConversationState.submitDirect`). The UI animates entries into their home positions with a category-colored glow. No confirmation, no undo UI.

## Technical Approach

### How SSE Already Works (Current State)

The SSE streaming is already wired. Here's the exact data flow in `ConversationState.submitDirect()`:

```
User speaks → stopRecording() → submitDirect()
  └→ pipeline.processWithAgentStreaming() returns AsyncThrowingStream<AgentStreamEvent>
       └→ for try await event in stream:
            ├→ .textDelta(token)     → accumulates in agentStreamText
            ├→ .toolCallStarted      → (currently ignored)
            ├→ .toolCallCompleted    → ★ KEY: executes actions IMMEDIATELY
            │    └→ AgentActionExecutor.execute()
            │         └→ modelContext.insert() + save()    → SwiftData notifies @Query
            │              └→ RootView re-renders → HomeView → CategorySectionView
            ├→ .toolCallFailed       → (currently ignored)
            └→ .completed(response)  → conversation history + credit charge
```

**The critical insight:** Actions execute inside the stream loop (line 314-326 of ConversationState.swift). Each `toolCallCompleted` triggers `AgentActionExecutor.execute()`, which calls `modelContext.save()`. SwiftUI's `@Query` picks this up on the next run loop. **Entries are already appearing in real-time** — they just appear silently with no animation.

### What Needs to Change

The only gap: the view has no way to know *which* entries just arrived vs. pre-existing. `@Query` returns all entries. `onAppear` fires on scroll in `LazyVStack`, not just on insertion.

**Solution:** Add `arrivedEntryIDs: Set<UUID>` to `ConversationState`. Populate it in the same `toolCallCompleted` handler, right after `AgentActionExecutor.execute()`. Since `ConversationState` is `@Observable` and `@MainActor`, the set update and the SwiftData save happen in the same run loop — SwiftUI sees both "new entry in @Query" and "entry ID in arrivedEntryIDs" simultaneously.

```
.toolCallCompleted → AgentActionExecutor.execute()
  ├→ modelContext.save()                    // SwiftData: entry exists
  └→ arrivedEntryIDs.insert(entry.id)       // @Observable: entry is "new"
       └→ SwiftUI picks up BOTH changes in one update cycle
            └→ CategorySectionView sees new entry + knows it's new → glow
```

This is 3 lines of code in the existing stream handler. No new architecture, no environment keys — just a set that gets populated alongside the existing action execution.

---

## Implementation Phases

### Phase 1: Rip Out Old Confirmation UI + Wire Arrival Tracking

Two things in one phase because the tracking hooks go in the same code we're modifying.

**Delete files:**
- `Murmur/Components/ResultsSurfaceView.swift` (entire file — 444 lines)
- `Murmur/Services/DenialLogStore.swift` (entire file — 47 lines)

**Remove from `Murmur/Models/ThreadItem.swift`:**
- `ConfirmationData` struct
- `ResultsSurfaceData` struct (keep `AppliedActionInfo` and `ActionResultData` — thread items still reference them)

**Modify `Murmur/Services/ConversationState.swift`:**

Remove:
- Properties: `pendingResults` (line 28), `pendingConfirmation` (line 30)
- Computed: `showResultsSurface` (lines 481-483)
- Methods: `dismissResults()` (485-489), `confirmPendingActions()` (493-539), `denyPendingActions()` (541-551)
- The `handleActionResult()` private method (442-476) — no longer used
- `denialLogStore` property and import

Add (same file):
```swift
/// Entry IDs created or updated in the current agent response.
/// Views use this to apply arrival glow animation.
var arrivedEntryIDs: Set<UUID> = []
```

**Simplify `submitDirect()` SSE stream loop** — this is the core change:

```swift
case .toolCallCompleted(let result):
    // Remove: confirmation branching (lines 301-312)
    // Keep: action execution (lines 314-326)
    let execResult = AgentActionExecutor.execute(actions: result.actions, context: ctx)

    // NEW: Track arrived entries for UI animation (same run loop as save)
    for applied in execResult.applied {
        arrivedEntryIDs.insert(applied.entry.id)
    }

    // Keep: accumulate results for tool result building
    accumulatedApplied.append(contentsOf: appliedInfos)
    accumulatedOutcomes.append(contentsOf: execResult.outcomes)
```

After the stream completes, remove the code that sets `pendingResults` (lines 386-403). Replace with:
```swift
// Haptic on completion
if !accumulatedApplied.isEmpty {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}
```

Add cleanup at the start of `submitDirect()`:
```swift
arrivedEntryIDs.removeAll()
```

Also clear in `startRecording()` and `reset()`.

**Remove from `Murmur/Views/RootView.swift`:**
- The `ResultsSurfaceView` mounting block (lines 108-147)
- All `onUndo`, `onConfirm`, `onDeny` callbacks
- Remove `import` of ResultsSurfaceView if it was explicit

**Wire `arrivedEntryIDs` to HomeView:**
RootView already passes `conversation` to child views. HomeView can access `conversation.arrivedEntryIDs` directly since `ConversationState` is `@Observable`.

**Verification:** App builds. Voice input creates entries that silently appear in their sections. `arrivedEntryIDs` populates (debug print). No overlay.

### Phase 2: Entry Arrival Glow (Expanded Sections)

Add the visual glow to entries that just arrived. Arrival tracking is already wired from Phase 1.

**Problem:** `SmartListRow` already applies `.cardStyle()` at line 684 with no accent. We can't layer a second `.cardStyle()` on top — it would double the background/border. The accent must flow *through* to `SmartListRow`'s `.cardStyle()` call.

**Modify `SmartListRow`** — add accent parameters:

```swift
private struct SmartListRow: View {
    let entry: Entry
    let onAction: (Entry, EntryAction) -> Void
    var glowAccent: Color? = nil        // NEW
    var glowIntensity: Double = 0       // NEW

    var body: some View {
        VStack(...) { ... }
        .cardStyle(accent: glowAccent, intensity: glowIntensity)  // was .cardStyle()
        ...
    }
}
```

**Add glow state wrapper** — a small view that owns the animation state per entry:

```swift
// In CategorySectionView, wrapping each entry:
struct GlowingEntryRow: View {
    let entry: Entry
    let isArrived: Bool
    let onAction: (Entry, EntryAction) -> Void
    let onGlowComplete: () -> Void

    @State private var glowIntensity: Double = 0

    var body: some View {
        SmartListRow(
            entry: entry,
            onAction: onAction,
            glowAccent: glowIntensity > 0 ? Theme.categoryColor(entry.category) : nil,
            glowIntensity: glowIntensity
        )
        .onChange(of: isArrived) { _, newValue in
            if newValue {
                glowIntensity = 1.0
                withAnimation(.easeOut(duration: 2.0)) {
                    glowIntensity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    onGlowComplete()
                }
            }
        }
    }
}
```

**In `CategorySectionView` ForEach (line 588-597):**

```swift
ForEach(entries) { entry in
    SwipeableCard(
        actions: swipeActionsProvider(entry),
        activeSwipeID: $activeSwipeEntryID,
        entryID: entry.id,
        onTap: { onEntryTap(entry) }
    ) {
        GlowingEntryRow(
            entry: entry,
            isArrived: arrivedEntryIDs.contains(entry.id),
            onAction: onAction,
            onGlowComplete: { arrivedEntryIDs.remove(entry.id) }
        )
    }
    .transition(.asymmetric(
        insertion: .opacity.combined(with: .scale(0.97)).combined(with: .offset(y: 8)),
        removal: .opacity.combined(with: .scale(0.95))
    ))
}
.animation(Animations.cardAppear, value: entries.map(\.id))
```

The `.transition` gives new entries a spring entrance. The glow fades independently over 2s.

**Verification:** Create entries via voice. Entries in expanded sections spring in with a category-colored glow border that fades over 2 seconds. Glow does NOT re-trigger on scroll.

### Phase 3: Collapsed Section Peek

The most complex piece. When an entry arrives in a collapsed section, a peek slot opens below the header.

**Add peek state to `CategorySectionView`:**

```swift
@State private var peekEntry: Entry? = nil
@State private var peekCount: Int = 0
@State private var peekVisible: Bool = false
@State private var peekTask: Task<Void, Never>? = nil
```

**Detection logic:** When `arrivedEntryIDs` changes and this section `isCollapsed`, find entries in this section that are in the arrived set:

```swift
.onChange(of: arrivedEntryIDs) { _, newIDs in
    guard isCollapsed else { return }
    let newInSection = entries.filter { newIDs.contains($0.id) }
    guard let latest = newInSection.first else { return } // sorted by createdAt desc

    peekEntry = latest
    peekCount += newInSection.count
    showPeek()
}

private func showPeek() {
    withAnimation(Animations.cardAppear) {
        peekVisible = true
    }
    // Reset retract timer
    peekTask?.cancel()
    peekTask = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        await MainActor.run {
            withAnimation(Animations.smoothSlide) {
                peekVisible = false
            }
            // Reset after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                peekEntry = nil
                peekCount = 0
            }
        }
    }
}
```

**Peek slot layout** — between header and next section, pushes content down:

```swift
VStack(spacing: 0) {
    // Header button (existing)
    sectionHeader

    // Peek slot (new)
    if isCollapsed && peekVisible, let peekEntry {
        SmartListRow(entry: peekEntry, ...)
            .arrivalGlow(isNew: true, category: category, onGlowComplete: {})
            .transition(.opacity.combined(with: .move(edge: .top)))
            .onTapGesture {
                // Expand section, cancel retract
                peekTask?.cancel()
                withAnimation(Animations.smoothSlide) {
                    isCollapsed = false
                    peekVisible = false
                    peekEntry = nil
                    peekCount = 0
                }
            }
    }

    // Expanded content (existing)
    if !isCollapsed { ... }
}
```

**Header badge** — show "+N" during peek:

```swift
// In section header, next to the existing count badge
if peekCount > 0 {
    Text("+\(peekCount)")
        .font(Theme.Typography.badge)
        .foregroundStyle(Theme.categoryColor(category))
        .transition(.scale.combined(with: .opacity))
}
```

**Header pulse** — brief glow on the header when peek opens:

```swift
@State private var headerGlowIntensity: Double = 0

// On peek open:
headerGlowIntensity = 1.0
withAnimation(.easeOut(duration: 1.0)) {
    headerGlowIntensity = 0
}

// Apply to header:
.shadow(color: categoryColor.opacity(0.3 * headerGlowIntensity), radius: 8)
```

**Verification:** Collapse a section. Create entries via voice for that category. Peek slot opens below header with glow, retracts after 3s. Tap peek card → section expands.

### Phase 4: Removal Animation (Complete/Archive)

When the agent completes or archives entries, they should animate out.

**In `CategorySectionView` `ForEach`:**

```swift
.transition(
    .asymmetric(
        insertion: .opacity.combined(with: .scale(0.97)).combined(with: .offset(y: 8)),
        removal: .opacity.combined(with: .scale(0.95))
    )
)
```

Completed/archived entries get filtered out of `activeEntries` in RootView. SwiftUI's `ForEach` diffing handles the removal with the above transition.

**Optional: brief completion flash** — before the entry is removed from `activeEntries`, flash the card green (complete) or yellow (archive) for 300ms. This requires a small delay between the state change and the SwiftData filter.

For v1: rely on SwiftUI's default removal animation with the transition above. Polish in a follow-up.

### Phase 5: Bottom Toast for Text-Only Responses

Move toast from top to bottom. Wire text-only agent responses to it.

**Modify `Murmur/Components/ToastView.swift`:**

```swift
// ToastContainer modifier:
// Change line 107:
ZStack(alignment: .bottom) {  // was .top

// Change line 118:
.padding(.bottom, Theme.Spacing.micButtonSize + 32)  // was .padding(.top, 60)
// Clear the mic button (72pt) + spacing

// Change transitions (lines 76-81):
.asymmetric(
    insertion: .move(edge: .bottom).combined(with: .opacity),
    removal: .move(edge: .bottom).combined(with: .opacity)
)
```

**Wire text-only responses in `ConversationState.submitDirect()`:**

After the stream completes, if the response has text but no actions:
```swift
if let textResponse = streamedResponse?.textResponse, !textResponse.isEmpty {
    // Set a published property that RootView binds to the toast
    self.agentToastMessage = textResponse
}
```

In `RootView`, bind `agentToastMessage` to the `.toast()` modifier:
```swift
.toast($toastConfig)
// Where toastConfig is derived from conversation.agentToastMessage
```

**Verification:** Trigger a text-only agent response (e.g., ask a question). Toast slides up from bottom above mic button, auto-dismisses.

### Phase 6: Cleanup & Polish

- Remove unused imports and references to deleted types
- Update `MurmurTests` if they reference removed types
- Add `Animations.entryArrival` constant if `cardAppear` doesn't feel right (may want slightly different spring)
- Test: entries in all 7 categories, mixed collapsed/expanded, rapid SSE delivery, app background during peek
- Accessibility: add `UIAccessibility.post(notification: .announcement)` when entries arrive ("Created 2 items"). Skip glow animation if `UIAccessibility.isReduceMotionEnabled`.

## Acceptance Criteria

- [x] `ResultsSurfaceView` and all confirmation UI code is removed
- [x] New entries appear in their actual category section with a category-colored glow that fades over ~2s
- [x] Collapsed sections peek open for ~3s showing the latest new entry, then retract
- [x] Multiple entries in the same collapsed section: peek shows latest, "+N" badge on header, timer resets
- [x] Cross-section entries animate independently (cascade effect)
- [x] Text-only agent responses show as bottom toast above mic button
- [x] User can tap peeked card to expand section
- [x] App builds with no warnings from removed code
- [x] Glow does not re-trigger on scroll (LazyVStack onAppear)

## Edge Cases to Address

| Case | Handling |
|------|----------|
| **First-ever entries (empty → populated)** | View transitions from `emptyState` to `populatedState`. Glow fires after populated view appears. |
| **New category appears** | `CategorySectionView` appears for the first time with the arrival-glowing entry inside it. |
| **SSE batch (non-streaming fallback)** | All entries arrive in one `toolCallCompleted`. Apply synthetic stagger: delay 200ms between each entry's glow start. |
| **User scrolling during delivery** | Glow is ID-tracked, not `onAppear`-based. Entry gets glow whenever it renders, even if scrolled to later. Clear tracking after 5s max to prevent stale glows. |
| **New recording during active glow** | `clearArrivalTracking()` cancels all glow/peek state. |
| **Peek during app background** | `Task.sleep` suspends. Peek retracts when app returns and timer completes. Acceptable. |
| **Entry sort reorder during glow** | SwiftUI handles reorder via identity. Glow persists on the entry regardless of position. |

## Files Changed Summary

| File | Change |
|------|--------|
| `Murmur/Components/ResultsSurfaceView.swift` | **DELETE** |
| `Murmur/Services/DenialLogStore.swift` | **DELETE** |
| `Murmur/Services/ConversationState.swift` | Remove `pendingResults`, `pendingConfirmation`, `showResultsSurface`, `dismissResults()`, `confirmPendingActions()`, `denyPendingActions()`, `handleActionResult()`. Add `arrivedEntryIDs: Set<UUID>`. Simplify `submitDirect()` stream loop — remove confirmation branch, add arrival tracking after `execute()`. |
| `Murmur/Models/ThreadItem.swift` | Remove `ConfirmationData`, `ResultsSurfaceData`. Keep `AppliedActionInfo`, `ActionResultData` (thread items use them). |
| `Murmur/Views/RootView.swift` | Remove `ResultsSurfaceView` overlay block (lines 108-147). Wire bottom toast for text-only responses. |
| `Murmur/Views/Home/HomeView.swift` | Add `GlowingEntryRow` wrapper. Add peek state + peek slot to `CategorySectionView`. Add header badge + pulse. Add insertion/removal transitions to `ForEach`. Modify `SmartListRow` to accept `glowAccent`/`glowIntensity`. |
| `Murmur/Components/ToastView.swift` | Move from top to bottom anchor. Update transitions and padding. |

## References

- Brainstorm: `docs/brainstorms/2026-03-03-entry-arrival-animation-brainstorm.md`
- FocusCardView glow pattern: `Murmur/Views/Home/HomeView.swift:431-505`
- CardStyleModifier: `Murmur/Theme/ViewModifiers.swift:5-35`
- CategorySectionView: `Murmur/Views/Home/HomeView.swift:509-603`
- SSE streaming: `Packages/MurmurCore/Sources/MurmurCore/StreamingResponseAccumulator.swift`
- Agent pipeline review: `docs/reviews/agent-pipeline-review.md`
