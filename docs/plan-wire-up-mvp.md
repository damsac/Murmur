# Plan: Wire Up MVP & Clean Dead Code

## Context

The Murmur app has a solid data pipeline (voice/text → LLM extraction → SwiftData persistence) but the UI layer has significant gaps: entry detail navigation is unconnected, completion/archive actions don't persist, the home view at L2+ hides most entry types, and there are 4 dead prototype views cluttering the codebase. The goal is to make every entry type fully functional end-to-end and remove abandoned code.

---

## Phase 1: Remove Dead Code

Delete unused prototype/variant views that are never referenced in production flows. These only appear in DevComponentGallery previews.

| File | Reason |
|------|--------|
| `Murmur/Views/Capture/ConfirmCardsView.swift` | Superseded by ConfirmView |
| `Murmur/Views/Capture/ConfirmSingleView.swift` | Superseded by ConfirmView |
| `Murmur/Views/Capture/LiveFeedRecordingView.swift` | Prototype; RecordingView is production |
| `Murmur/Views/Capture/VoiceCorrectionView.swift` | Incomplete, button disabled, no LLM integration |

Also update `DevMode/DevComponentGallery.swift` and `DevMode/DevScreen.swift` to remove references to deleted views.

**Files to modify:**
- `Murmur/DevMode/DevScreen.swift` — remove enum cases for deleted views
- `Murmur/DevMode/DevComponentGallery.swift` — remove gallery entries for deleted views

---

## Phase 2: Add Recent Entries to Home (L2+)

**Problem:** `HomeAIComposedView` only shows cards for reminder, todo, habit, and idea. Notes, thoughts, questions, and lists are invisible at L2+.

**Fix:** Add a "Recent" section below the composed cards that shows the latest entries regardless of category. This ensures all 8 entry types are visible.

**File:** `Murmur/Views/Home/HomeAIComposedView.swift`

- After the composed cards `ForEach`, add a "RECENT" header + list of the most recent entries (up to ~10) using `EntryCard` (which already handles all categories via `CategoryBadge`)
- Use `ReminderEntryCard` for `.reminder` entries (it shows due dates)
- Wire `onTapGesture` to a new `onEntryTap: (Entry) -> Void` callback parameter

---

## Phase 3: Wire Entry Detail Navigation

**Problem:** Tapping entries everywhere just `print()`s to console. `EntryDetailView` exists but is never navigated to.

**Approach:** Add `@State private var selectedEntry: Entry?` to `RootView` and present `EntryDetailView` as a full-screen cover or navigation push when an entry is tapped.

**Files to modify:**
- `Murmur/Views/RootView.swift` — add `selectedEntry` state, present `EntryDetailView`, wire callbacks
- `Murmur/Views/Home/HomeSparseView.swift` — pass through `onEntryTap` (already has it)
- `Murmur/Views/Home/HomeAIComposedView.swift` — add `onEntryTap` callback
- `Murmur/Views/MainTabView.swift` — add `selectedEntry` state, present `EntryDetailView`, pass `onEntryTap` through

---

## Phase 4: Wire Persistence for Actions

### 4a: Entry completion (todo checkbox)

**Problem:** `CategoryListView.swift:53` uses `.constant(entry.status == .completed)` — read-only.

**Fix:** Replace with a real binding that updates `entry.status` and `entry.completedAt` on the SwiftData model, then saves.

**File:** `Murmur/Views/ViewsSheet/CategoryListView.swift`
- Add `@Environment(\.modelContext)`
- Replace `.constant()` with a closure that toggles status and saves

### 4b: Entry detail actions (archive, snooze, delete)

**Problem:** `EntryDetailView` action callbacks are `print()`-only in callers.

**Fix:** Wire real model mutations in the presenters (`RootView`, `MainTabView`):
- Archive: set `entry.status = .archived`, save, dismiss
- Snooze: set `entry.status = .snoozed`, set `entry.snoozeUntil`, save, dismiss
- Delete: `modelContext.delete(entry)`, save, dismiss

### 4c: Focus card actions

**Problem:** Mark done / snooze just dismiss the overlay, no model update.

**Fix in `RootView.swift`:**
- `onMarkDone`: set `entry.status = .completed`, `entry.completedAt = Date()`, save
- `onSnooze`: set `entry.status = .snoozed`, `entry.snoozeUntil = Date().addingTimeInterval(3600)`, save

---

## Phase 5: Wire Views Tab Navigation (L3+)

**Problem:** ViewsGridView exists but navigation from it to CategoryListView is not connected. The Views tab at L2 shows an empty state.

**Fix:** In `MainTabView.viewsContent`, wire `ViewsGridView.onViewSelected` to push a `CategoryListView` filtered by the selected category. Use `@State` navigation state.

**Files to modify:**
- `Murmur/Views/MainTabView.swift` — add navigation state, show CategoryListView when a view type is selected
- Pass real `onToggleComplete`, `onMarkDone`, `onSnooze`, `onDelete` callbacks with model mutations

---

## Phase 6: Remove Hardcoded Data

### 6a: HabitCard "7 day streak"

**File:** `Murmur/Views/Home/HomeAIComposedView.swift` (line 245)

Remove the hardcoded "7 day streak" text. Replace with just the entry summary or remove the streak line entirely since there's no streak tracking system.

---

## Verification

1. `make build` — confirm clean compile with no errors
2. Build and run on simulator via `build_run_sim`
3. Test the full flow:
   - Type a thought (e.g. "I've been more productive lately") → confirm it categorizes as thought → verify it appears on home
   - Type a todo → verify completion toggle works
   - Tap an entry → verify detail view opens
   - Archive/delete from detail view → verify it disappears
   - Navigate to Views tab (at L3+) → verify category list works
4. Verify no dead code references remain (clean build)
