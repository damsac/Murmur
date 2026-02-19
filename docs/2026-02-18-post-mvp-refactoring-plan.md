---
date: 2026-02-18
topic: post-mvp-refactoring
status: planned
---

# Post-MVP Refactoring Plan

Architectural improvements to make after the MVP commit. Ordered by impact — do these roughly in sequence, as later items build on earlier ones.

---

## 1. Extract CaptureCoordinator from RootView

**Problem:** `RootView.swift` (448 lines of logic + 75 lines of previews) is a god view. It owns the recording state machine, mic permissions, LLM processing, entry persistence, toast display, and navigation — all in one file.

**What to extract:**

Create `Murmur/Services/CaptureCoordinator.swift` — an `@Observable @MainActor` class that owns the full capture lifecycle:

| Currently in RootView | Move to CaptureCoordinator |
|---|---|
| `handleMicTap()` (lines 289-319) — mic permission + start recording | `startCapture()` |
| `handleStopRecording()` (lines 321-349) — stop + LLM extraction | `stopCapture()` |
| `handleTextSubmit()` (lines 352-386) — text + LLM extraction | `submitText(_:)` |
| `handleAccept()` (lines 388-416) — persist entries to SwiftData | `confirmEntries(context:)` |
| `transcript` state (line 12) | Internal to coordinator |
| `appState.processedEntries/Transcript/AudioDuration/Source` | Move into coordinator as `captureResult` |

**After extraction, RootView becomes:**
- Tab selection + navigation (already clean)
- Composing `mainContent` / `settingsContent` / `recordingOverlays` (already clean)
- Delegating all actions to `CaptureCoordinator`

**RootView shrinks to ~200 lines.** The coordinator is independently testable without any SwiftUI.

**Implementation notes:**
- CaptureCoordinator takes `Pipeline` and `ModelContext` as dependencies
- Inject via `@Environment` or pass from `MurmurApp`
- The `RecordingState` enum and `processedEntries` etc. currently on `AppState` move to the coordinator
- `AppState` stays lean: disclosure level, dev mode, onboarding — pure app-level state

---

## 2. Delete MainTabView

**Problem:** `MainTabView.swift` is dead code. The file header says "Legacy wrapper — retained for DevScreen previews" but `DevScreen.swift` is already excluded from the build target in `project.yml`.

**Action:** Delete the file and remove from source control.

**Verify first:** `grep -r "MainTabView" Murmur/` — confirm nothing references it except its own previews.

---

## 3. Remove Hardcoded Placeholder Data

### 3a. "7 day streak" in HabitCard

**File:** `Murmur/Views/Home/HomeAIComposedView.swift:244`

```swift
Text("7 day streak")  // hardcoded
```

**Fix:** Either:
- Remove the streak line entirely until habit tracking exists
- Or compute from real data: count consecutive days with entries in the `habit` category

Removing is simpler and more honest for MVP.

### 3b. MockDataService is excluded but still in repo

`Murmur/Services/MockDataService.swift` is excluded from the build target (via `project.yml`) but still tracked in git. This is intentional — it's useful reference data for testing disclosure levels. No action needed now, but consider moving it to a `DevSupport/` directory or test target when the codebase matures.

### 3c. TokenBalanceLabel / credit references in orphaned views

Files like `MicDeniedView.swift:13` reference `TokenBalanceLabel(balance: 4953)`. These are already excluded from the build. When the credit system is designed, these views will be rewritten. No action needed.

### 3d. Print statements as action placeholders

Several callback closures in `RootView` just print:
- `onEntryTap` (line 178): `print("Entry tapped: ...")`
- `onCardTap` (line 188): `print("Card tapped: ...")`
- `onTopUp` (line 212): `print("Top up tapped")`
- `onManageViews`, `onExportData`, `onClearData`, `onOpenSourceLicenses` (lines 220-231)

**Fix:** Replace with real navigation or remove the callbacks entirely if the feature doesn't exist yet. Stub callbacks that do nothing are better than ones that print — a print suggests something should be happening.

---

## 4. Make LLM Types Thread-Safe

### 4a. LLMConversation — mutable class marked @unchecked Sendable

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:5-9`

```swift
public final class LLMConversation: @unchecked Sendable {
    var messages: [[String: Any]] = []  // mutable, unprotected
}
```

This is safe today because `Pipeline` is `@MainActor` and all access flows through it. But `PPQLLMService` also conforms to `Sendable`, so the compiler won't stop someone from calling it off the main actor.

**Options (pick one):**
1. **Make it an actor** — `public actor LLMConversation`. Safest, but requires `await` at every access site.
2. **Add a lock** — wrap `messages` with `OSAllocatedUnfairLock` or `NSLock`. Keeps the synchronous API.
3. **Document the contract** — add `/// - Important: Must only be accessed from @MainActor context.` and keep `@unchecked Sendable`. Cheapest, least safe.

Recommendation: Option 2 (lock). It's the right balance of safety and ergonomics for a type that's mutated in a tight loop (message accumulation).

### 4b. LLMPrompt — [String: Any] dictionaries

**File:** `Packages/MurmurCore/Sources/MurmurCore/LLMService.swift:13-151`

The tool schema is expressed as nested `[String: Any]` literals. This is:
- Not type-checked at compile time
- Marked `@unchecked Sendable` because `[String: Any]` isn't `Sendable`
- Hard to read and modify

**Fix:** Define `Codable` structs for the OpenAI tool-call schema:

```swift
struct ToolDefinition: Codable, Sendable {
    let type: String
    let function: FunctionDefinition
}

struct FunctionDefinition: Codable, Sendable {
    let name: String
    let description: String
    let parameters: JSONSchema
}

struct JSONSchema: Codable, Sendable {
    let type: String
    let properties: [String: PropertySchema]?
    let required: [String]?
    let items: JSONSchema?
    // etc.
}
```

Then `LLMPrompt` becomes properly `Sendable` without the `@unchecked` escape hatch, and tool definitions are validated at compile time.

**Scope:** This is a medium refactor — the schema is defined once in `LLMPrompt.entryExtraction` and consumed once in `PPQLLMService`. But getting it right now prevents bugs when modifying the prompt later.

---

## 5. Harden PersistenceConfig

### 5a. Replace fatalError with graceful fallback

**File:** `Murmur/Shared/PersistenceConfig.swift:6-14`

```swift
static let appGroupIdentifier: String = {
    guard let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
          !identifier.isEmpty else {
        fatalError("AppGroupIdentifier not configured ...")  // kills the app
    }
    return identifier
}()
```

The `storeURL` getter (line 36-48) already handles a missing app group gracefully by falling back to the documents directory. But the `fatalError` in `appGroupIdentifier` fires first.

**Fix:** Make `appGroupIdentifier` optional:

```swift
static let appGroupIdentifier: String? = {
    guard let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
          !identifier.isEmpty else {
        print("Warning: AppGroupIdentifier not configured — using documents directory")
        return nil
    }
    return identifier
}()
```

Then update `storeURL` and `deleteStoreIfSchemaChanged` to handle `nil`.

### 5b. Replace destructive schema migration before any real release

**File:** `Murmur/Shared/PersistenceConfig.swift:50-58`

Currently deletes the SQLite store on schema version bump. Fine for development, not acceptable for production.

**Future approach:**
- Use SwiftData's `VersionedSchema` and `SchemaMigrationPlan`
- Define a `MurmurSchemaV1` capturing the current schema
- Each future schema change gets a new version + migration step
- Remove `deleteStoreIfSchemaChanged()` entirely

This is blocked until SwiftData's migration API stabilizes (still evolving as of iOS 18). Revisit when approaching App Store submission.

---

## 6. Preserve Recording on Background

**File:** `Murmur/MurmurApp.swift:34-43`

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background {
        if appState.recordingState == .recording {
            Task {
                try? await appState.pipeline?.stopRecording()  // result discarded
                appState.recordingState = .idle
            }
        }
    }
}
```

The recording result is thrown away — the user loses their transcript with no feedback.

**Fix (when CaptureCoordinator exists):**
- On background: stop recording, run extraction, store result in coordinator
- On foreground: if there's a pending result, transition to `.confirming` state
- Show a local notification: "Your recording was processed — tap to review"

This depends on item 1 (CaptureCoordinator) being done first.

---

## 7. Localize the Transcriber

**File:** `Packages/MurmurCore/Sources/MurmurCore/AppleSpeechTranscriber.swift:18`

```swift
self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    ?? SFSpeechRecognizer(locale: Locale.current)!
```

Two issues:
1. Hardcoded to `en-US` — won't transcribe well for non-English speakers
2. Force-unwrap on the fallback (extremely unlikely to crash, but still a code smell)

**Fix:**
- Accept `locale: Locale = .current` as an init parameter
- Remove the force-unwrap: if neither locale is supported, throw an error instead of crashing
- The LLM prompt in `LLMService.swift` also assumes English — add a locale-aware prompt variant when supporting multiple languages

---

## Priority Order

| # | Item | Effort | Impact | Depends on |
|---|------|--------|--------|------------|
| 1 | Extract CaptureCoordinator | Medium | High — unblocks testability, cleans RootView | — |
| 2 | Delete MainTabView | Trivial | Low — removes confusion | — |
| 3 | Remove hardcoded data | Small | Medium — removes false signals in UI | — |
| 4 | Make LLM types thread-safe | Medium | Medium — prevents latent concurrency bugs | — |
| 5 | Harden PersistenceConfig | Small | Medium — prevents dev onboarding crashes | — |
| 6 | Preserve recording on background | Medium | Medium — prevents data loss | 1 |
| 7 | Localize transcriber | Small | Low for MVP — enables future i18n | — |

Items 1-5 can be done independently in any order. Item 6 depends on 1. Item 7 is low priority until i18n is on the roadmap.
