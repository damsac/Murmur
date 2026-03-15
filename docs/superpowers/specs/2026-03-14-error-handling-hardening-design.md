# Error Handling Hardening — Design Spec

**Date:** 2026-03-14
**Author:** dam + Claude
**Status:** Approved
**Target:** TestFlight users (human-readable errors, not marketing polish)

## Problem

The app has well-defined error types and dedicated error views, but the wiring is incomplete. Key gaps:

1. **Silent failures at point of use** — mic denied and missing pipeline silently do nothing when the user taps the mic button or submits text
2. **Generic error messages** — most errors collapse to "Couldn't process — network error" despite carrying specific HTTP status codes
3. **Crash-risk patterns** — force-unwraps on calendar math (5 instances)
4. **Silent logging** — SwiftData save failures use `print()` instead of `os.log`, invisible during TestFlight

## Decisions

- **Lazy error surfacing** — errors shown at point of use (when user taps mic, submits text), not preemptively
- **Toast-based UX** — all errors use the existing toast system; no new views or overlays
- **Toasts stay as-is for transient errors** — no retry affordance in this PR (future work)
- **Keep orphaned error views** — `APIErrorView`, `OutOfCreditsView`, `MicDeniedView` stay for future retry/credit flows
- **Error copy: slightly specific** — distinguish "no connection" vs "service unavailable" vs "auth failed" so users know whether to retry

## Changes

### 1. Point-of-Use Error Blocking

**File:** `Murmur/Services/ConversationState.swift`

Three entry points need error blocking:

**a) `startRecording()`** — guards `appState?.pipeline` at line 107, silently bails.
- Note: by the time `ensureMicPermission()` runs, `inputState` has already been set to `.recording` (line 113) and a status indicator added (line 117). When mic is denied, these are cleaned up — but the user sees a brief recording-state flash before the toast. This is acceptable for now; the flash is <100ms.

**b) `submitText()`** — does NOT guard on pipeline. It calls `submit()` → `submitDirect()`, which guards at line 281. But by that point, a `.userInput` thread item has already been appended (line 93) and input state set to `.processing` (line 249). When pipeline is nil, the user sees a ghost user-input item and a processing flash.
- Fix: add pipeline guard at the top of `submitText()`, before any state mutations.

**c) `submitDirect()`** — guards on pipeline at line 281, resets to idle. Already the cleanest path, but should show a toast instead of silent bail.

**Mic permission denied:**
- `ensureMicPermission()` currently returns `false` silently when denied
- Add: show error toast "Microphone access needed" when denied
- For the "Settings" action button: use an enum-based approach (see Implementation below) so RootView maps `.micDenied` to opening Settings

**Pipeline unavailable (no API key):**
- Add: when pipeline is nil, show error toast "Voice processing unavailable"
- This covers the case where `PPQ_API_KEY` is missing from `project.local.yml`

**Implementation — bridging ConversationState errors to RootView toasts:**

Use a published enum property matching the existing `completionText` pattern:

```swift
enum ErrorPresentation: Equatable {
    case micDenied          // RootView maps to "Microphone access needed" + Settings button
    case pipelineUnavailable // RootView maps to "Voice processing unavailable"
    case processingFailed(String) // sanitized message from sanitizeError()
}

// On ConversationState:
var errorPresentation: ErrorPresentation?
```

RootView observes via `.onChange(of: appState.conversation.errorPresentation)` and calls `showToast()` with the appropriate message, type, and action. This avoids passing closures through `@Observable` (closures aren't `Equatable`). RootView owns the `UIApplication.open(settings)` call for `.micDenied`.

### 2. Improved Error Messages

**File:** `Murmur/Services/ConversationState.swift` — `sanitizeError()` function

Rewrite to inspect the `underlying` error on `PipelineError.extractionFailed`. The underlying error is `any Error` and must be cast with `as?` to reach the specific type.

**Pattern matching structure:**

```swift
private func sanitizeError(_ error: Error) -> String {
    switch error {
    case PipelineError.insufficientCredits:
        return "Out of credits."
    case PipelineError.emptyTranscript:
        return "Nothing to process."
    case PipelineError.noEntriesExtracted:
        return "No entries found in your input."
    case PipelineError.extractionFailed(let underlying):
        // Cast underlying to inspect specific error types
        if let ppqError = underlying as? PPQError {
            switch ppqError {
            case .httpError(statusCode: let code, body: _):
                if code == 401 || code == 403 {
                    return "Service authentication failed — check API key."
                } else if code == 429 {
                    return "Too many requests — try again in a moment."
                } else if code >= 500 {
                    return "Service is temporarily unavailable."
                }
            default: break
            }
        }
        if underlying is URLError {
            return "No internet connection."
        }
        return "Couldn't process — try again."
    default:
        return "Couldn't process — try again."
    }
}
```

**Toast types per message:**

| Error | Message | Toast Type |
|-------|---------|------------|
| `insufficientCredits` | "Out of credits." | `.warning` |
| `emptyTranscript` | "Nothing to process." | `.warning` |
| `noEntriesExtracted` | "No entries found in your input." | `.warning` |
| `extractionFailed` → 401/403 | "Service authentication failed — check API key." | `.error` |
| `extractionFailed` → 429 | "Too many requests — try again in a moment." | `.warning` |
| `extractionFailed` → 500+ | "Service is temporarily unavailable." | `.error` |
| `extractionFailed` → `URLError` | "No internet connection." | `.error` |
| `extractionFailed` → other | "Couldn't process — try again." | `.error` |
| Everything else | "Couldn't process — try again." | `.error` |

**Note:** `sanitizeError()` currently returns only a `String`. To carry the toast type, change return type to `(String, ToastView.ToastType)` or have the caller determine type from the `ErrorPresentation` enum.

**Omitted `PipelineError` cases** — the following cases fall through to "Couldn't process — try again." and this is intentional:
- `transcriberUnavailable` — rare device issue, no specific user action
- `notRecording` — defensive guard, shouldn't surface
- `transcriptionFailed` — speech recognition failure, retry is the right advice
- `creditAuthorizationFailed` / `creditChargeFailed` — credit gate internal failures, same as generic
- `noActiveSession` — defensive, shouldn't reach user

### 3. Crash Hardening

**Calendar force-unwraps** (5 instances):
- `Murmur/Models/Entry.swift` lines 363, 368, 370, 372 — `calendar.date(byAdding:)!` in `prevPeriodStart()`
  - Replace with `?? period` — fallback to the input date
- `Murmur/Services/SessionSummaryService.swift` line 35 — `calendar.date(byAdding: .day, value: 1, to: startOfToday)!`
  - Replace with `?? startOfToday.addingTimeInterval(86400)` — fallback to manual day offset

A slightly wrong streak count or session boundary is better than a crash.

**FileManager array access — consistency normalization** (4 instances):
- `Murmur/Services/AppState.swift` line 114 — `[0]` → `.first!`
- `Murmur/Services/AgentMemoryStore.swift` line 8 — `[0]` → `.first!`
- `Murmur/Services/HomeCompositionStore.swift` line 9 — `[0]` → `.first!`
- `Murmur/Shared/PersistenceConfig.swift` line 45 — already `.first!`

This is a consistency pass, not a crash fix — documents directory always exists on iOS. Both `[0]` and `.first!` crash identically if the impossible happens; `.first!` is just more idiomatic.

**PersistenceConfig `fatalError()`** (lines 11, 31) — keep as-is. No meaningful recovery from missing app group or broken SwiftData schema.

### 4. Silent Failures → os.log

Replace `print()` with structured `Logger` calls for error paths that matter during TestFlight:

| File | Line | Current | Category |
|------|------|---------|----------|
| `AgentActionExecutor.swift` | 82 | `print("Failed to save after agent actions: ...")` | "Actions" |
| `AgentActionExecutor.swift` | 272 | `print("Failed to save undo: ...")` | "Actions" |
| `RootView.swift` | 558 | `print("Failed to save woken entries: ...")` | "Entries" |
| `AppState.swift` | 90 | `print("⚠️ Pipeline not configured...")` | "Pipeline" |
| `Entry.swift` | ~442 | `print("Failed to save entry: ...")` | "Entries" |
| `NotificationService.swift` | ~23 | `print("Notification permission error: ...")` | "Notifications" |
| `EntryDetailView.swift` | ~363 | `print("Failed to save entry: ...")` | "Entries" |

`Entry.swift` is particularly important — it's a SwiftData save failure in `perform(_:)`, called on every user gesture (complete, archive, snooze, etc.).

Excluded: `PersistenceConfig.swift` line 44 (app group fallback warning) — this fires once at startup and is already visible alongside the `fatalError` path. `OnboardingFlowView.swift` — only fires during onboarding, low priority.

No user-facing changes. Visible in Console.app during TestFlight sessions.

### 5. Future Work (Not This PR)

Track in roadmap/STATE.md:
- **Retry affordance** — render `ThreadItem.error` items in the conversation thread with a retry button
- **Transcript preservation** — save transcript on processing failure for later re-processing
- **Credit exhaustion flow** — wire `OutOfCreditsView` into the real credit depletion path
- **Error history** — consider keeping recent errors accessible beyond the 3-second toast

## Non-Goals

- No new error view components
- No centralized error routing layer (YAGNI for ~5 error paths)
- No changes to error types/enums in MurmurCore
- No changes to toast duration or animation
