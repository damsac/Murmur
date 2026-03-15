# Error Handling Hardening — Design Spec

**Date:** 2026-03-14
**Author:** dam + Claude
**Status:** Approved
**Target:** TestFlight users (human-readable errors, not marketing polish)

## Problem

The app has well-defined error types and dedicated error views, but the wiring is incomplete. Key gaps:

1. **Silent failures at point of use** — mic denied and missing pipeline silently do nothing when the user taps the mic button
2. **Generic error messages** — most errors collapse to "Couldn't process — network error" despite carrying specific HTTP status codes
3. **Crash-risk patterns** — force-unwraps on calendar math (5 instances) and non-idiomatic array access (4 instances)
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

**Mic permission denied:**
- `ensureMicPermission()` currently returns `false` silently when `AVAudioApplication.shared.recordPermission == .denied`
- Add: show toast "Microphone access needed" with "Settings" action button that opens `UIApplication.openSettingsURLString`
- When permission is `.undetermined`, the existing `requestRecordPermission()` flow stays — if user denies the prompt, show the same toast

**Pipeline unavailable (no API key):**
- `startRecording()` and `submitDirect()` guard on `appState?.pipeline` and silently bail
- Add: when pipeline is nil, show toast "Voice processing unavailable — check API configuration" (`.error` type)
- This covers the case where `PPQ_API_KEY` is missing from `project.local.yml`

**Implementation:** Both changes use the existing `showToast` pattern. ConversationState doesn't currently have toast access, so we need a lightweight callback or delegate to RootView's toast. Options:
- **A) Closure on ConversationState** — `var onError: ((String, ToastView.ToastType) -> Void)?` set by RootView
- **B) Published property** — `var errorToast: (message: String, type: ToastType)?` observed by RootView like `completionText`

Recommend **B** — matches the existing `completionText` pattern. RootView already observes ConversationState and converts `completionText` into a toast (RootView.swift line 319-323). Same pattern for errors.

### 2. Improved Error Messages

**File:** `Murmur/Services/ConversationState.swift` — `sanitizeError()` function

Rewrite to inspect the `underlying` error on `PipelineError.extractionFailed`:

| Error | Message |
|-------|---------|
| `insufficientCredits` | "Out of credits." |
| `emptyTranscript` | "Nothing to process." |
| `noEntriesExtracted` | "No entries found in your input." |
| `extractionFailed` wrapping `PPQError.httpError(401\|403)` | "Service authentication failed — check API key." |
| `extractionFailed` wrapping `PPQError.httpError(429)` | "Too many requests — try again in a moment." |
| `extractionFailed` wrapping `PPQError.httpError(500+)` | "Service is temporarily unavailable." |
| `extractionFailed` wrapping `URLError` | "No internet connection." |
| `extractionFailed` (other) | "Couldn't process — try again." |
| Everything else | "Couldn't process — try again." |

### 3. Crash Hardening

**Calendar force-unwraps** (5 instances):
- `Murmur/Models/Entry.swift` lines 363, 368, 370, 372 — `calendar.date(byAdding:)!` in `prevPeriodStart()`
- `Murmur/Services/SessionSummaryService.swift` line 35 — same pattern

Replace `!` with `?? period` (or `?? startOfToday`). A slightly wrong streak/summary is better than a crash.

**FileManager array access** (4 instances):
- `Murmur/Services/AppState.swift` line 114 — `[0]`
- `Murmur/Services/AgentMemoryStore.swift` line 8 — `[0]`
- `Murmur/Services/HomeCompositionStore.swift` line 9 — `[0]`
- `Murmur/Shared/PersistenceConfig.swift` line 45 — `.first!`

Normalize all to `.first!` for idiomatic consistency. These are safe on iOS (documents directory always exists).

**PersistenceConfig `fatalError()`** (lines 11, 31) — keep as-is. No meaningful recovery from missing app group or broken SwiftData schema.

### 4. Silent Failures → os.log

Replace `print()` with structured `Logger` calls:

| File | Line | Current | Category |
|------|------|---------|----------|
| `AgentActionExecutor.swift` | 82 | `print("Failed to save after agent actions: ...")` | "Actions" |
| `AgentActionExecutor.swift` | 272 | `print("Failed to save undo: ...")` | "Actions" |
| `RootView.swift` | 558 | `print("Failed to save woken entries: ...")` | "Entries" |
| `AppState.swift` | 90 | `print("⚠️ Pipeline not configured...")` | "Pipeline" |

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
