# Discrepancies: UI vs Mocks/Spec vs MurmurKit

## 1. Entry Categories — Major Mismatch

| MurmurKit | UI (current) | Mocks/Spec |
|-----------|-------------|------------|
| `todo` | `todo` | `todo` |
| `note` | `note` | `note` |
| `reminder` | `reminder` | `reminder` |
| `idea` | `idea` | `idea` |
| `list` | -- | `list` |
| `habit` | -- | `habit` |
| `question` | `question` | `question` |
| `thought` | -- | `thought` |
| -- | `insight` | -- |
| -- | `decision` | -- |
| -- | `learning` | -- |

UI invented 3 categories (`insight`, `decision`, `learning`) not in MurmurKit or spec. Missing 3 that exist in both MurmurKit and spec (`list`, `habit`, `thought`).

## 2. Entry Status — Mismatch

| MurmurKit | UI (current) |
|-----------|-------------|
| `active` | `active` |
| `completed` | `completed` |
| `archived` | -- |
| `snoozed` | -- |
| -- | `dismissed` |

MurmurKit supports `archived` and `snoozed` (with `snoozeUntil` date). UI has `dismissed` which doesn't exist in MurmurKit. FocusCardView has a "Snooze" button but no `snoozed` status to back it.

## 3. Entry Model Fields — Structural Gap

| Field | MurmurKit | UI |
|-------|-----------|-----|
| `transcript` (full recording) | `transcript: String` (required) | `fullTranscript: String?` (optional) |
| `content` (AI-cleaned) | `content: String` (required) | -- missing |
| `sourceText` (extraction source) | `sourceText: String` (required) | -- missing |
| `source` (voice/text) | `EntrySource` enum | `aiGenerated: Bool` (different concept) |
| `priority` scale | `Int?` (1-5, 1=highest) | `Int` (0-2, non-optional) |
| `dueDateDescription` | `String?` (raw phrase) | -- missing |
| `snoozeUntil` | `Date?` | -- missing |
| `audioDuration` | `TimeInterval?` | -- missing |
| `tokenCost` | -- not in Kit | `Int` (on Entry) |
| `tags` | -- not in Kit | `[String]` |
| Enum storage | Raw strings for SwiftData predicates | Enum directly |

Priority inversion: MurmurKit `1 = highest` vs UI `0 = low, 2 = high`.

## 4. Tab Navigation Appears Too Early

Spec/mocks say:
- L2 (Grid Awakens): AI-composed home grid, **no bottom nav**
- L3 (Views Emerge): Bottom nav appears (Home/Views/Settings)

UI has `MainTabView` with full bottom nav for **all of L2-L4** (`RootView.swift:155`).

## 5. No Pipeline Integration Point

- UI manages recording state directly via `appState.recordingState`
- `createMockEntry()` creates hardcoded mock entries
- No injection point for `Pipeline.startRecording()` / `stopRecording()` / `save()`
- No place for `RecordingResult` or `TextResult` to flow through
- UI `Entry` model is a different type than MurmurKit `Entry`

## 6. Multi-turn Refinement Not Represented

MurmurKit supports `refineFromRecording()` / `refineFromText()` for multi-turn corrections. UI ConfirmView has "Voice Correct" button but it just prints to console. No conversation state tracking, no architecture for feeding corrections back through the pipeline.

## 7. Text Input Processing Path Incomplete

MurmurKit has `extractFromText(String)` -> `TextResult`. UI's `handleTextSubmit()` in `MainTabView` doesn't create entries — just prints and simulates delay. No path to `Pipeline.extractFromText()`.

## 8. Token Display Missing Directional Flow

Mocks show `up-arrow input / down-arrow output` token counters during recording and confirm. UI has `TokenBalanceLabel` showing just a balance number. Missing directional flow visualization ("Credits as fuel" spec pillar).

## 9. SwiftData Predicate Compatibility

MurmurKit stores enums as raw strings (`categoryRawValue`, `statusRawValue`, `sourceRawValue`) for predicate support. UI stores enums directly on the model. Queries will break without alignment.

## Resolution Priority

### Must fix (crashes / wrong behavior)
1. Align `EntryCategory` to MurmurKit (drop `insight`/`decision`/`learning`, add `list`/`habit`/`thought`)
2. Align `EntryStatus` (add `archived`/`snoozed`, decide on `dismissed`)
3. Align `priority` scale or add mapping layer
4. Adopt MurmurKit `Entry` model or build mapping layer

### Should fix (design intent mismatch)
5. Move tab navigation from L2 to L3
6. Add `Pipeline` as dependency in `AppState` or `@Environment`
7. Wire confirm flow to `Pipeline.save()` / discard
8. Add multi-turn refinement to confirm view

### Nice to have for MVP
9. Directional token counters during recording/confirm
10. Wire text input through `Pipeline.extractFromText()`
