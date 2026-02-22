---
title: "refactor: Use live transcript to instantly detect empty recordings"
type: refactor
status: active
date: 2026-02-21
---

# refactor: Use live transcript to instantly detect empty recordings

## Overview

Use the transcriber's live `currentTranscript` to instantly detect empty recordings at stop time — no 500ms wait, no processing overlay flash. If the user said nothing, cancel recording and return to idle immediately.

## Problem Statement

Current flow when user stops recording:

```
Tap stop → recordingState = .processing (overlay appears)
  → transcriber.stopRecording() (~500ms finalization wait)
  → empty check → throw → recordingState = .idle
```

The user sees the processing spinner flash for ~500ms before it vanishes. The 500ms comes from `AppleSpeechTranscriber.stopRecording()` waiting for final recognition results.

But `AppleSpeechTranscriber` already maintains `currentTranscript` in real-time via the recognition callback (line 109). If the user said nothing, this stays `""` — we can check it instantly without waiting.

## Proposed Solution

```
Tap stop → yield + check pipeline.currentTranscript
  → empty? → cancelRecording() → recordingState = .idle (instant, no flash)
  → non-empty? → recordingState = .processing → pipeline.stopRecording() (500ms + LLM)
```

The 500ms wait only happens in the non-empty case, where it's hidden behind the processing overlay that the user expects to see.

## Timing Analysis: Is `currentTranscript` Reliable?

The recognition callback fires on Apple's internal queue, then dispatches to MainActor:

```swift
recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
    Task { @MainActor in
        self.currentTranscript = result.bestTranscription.formattedString  // line 109
    }
}
```

When the user taps stop (also on MainActor), there's a theoretical race: a recognition result could be dispatched to MainActor but not yet executed.

**For the empty case, this is a non-issue:** if the user said nothing, no recognition callbacks ever fired, so `currentTranscript == ""` with certainty.

**For the edge case** where the user spoke right before tapping stop: we add `await Task.yield()` before reading `currentTranscript`. This yields the main actor executor, letting any pending dispatched tasks (including transcript updates from the recognition callback) execute first. This ensures we read the latest value.

Apple's Speech framework delivers partial results "in near real time" with `shouldReportPartialResults = true` (which we set at line 74). The recognition callback fires continuously as audio is processed, so `currentTranscript` tracks speech closely.

## Changes

### 1. `Packages/MurmurCore/Sources/MurmurCore/Transcriber.swift`

Add two new protocol requirements:

```swift
public protocol Transcriber: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> Transcript
    func cancelRecording() async                    // NEW: instant cleanup, no finalization
    var currentTranscript: String { get async }     // NEW: live partial transcript
    var isRecording: Bool { get async }
    var isAvailable: Bool { get async }
}
```

### 2. `Packages/MurmurCore/Sources/MurmurCore/AppleSpeechTranscriber.swift`

Rename private var to avoid collision, implement protocol:

```swift
// Rename: private var currentTranscript → _currentTranscript
// Update all internal references (lines 16, 103, 109, 136)

// NEW: expose live transcript
public var currentTranscript: String {
    get async { _currentTranscript }
}

// NEW: instant cleanup without 500ms finalization wait
public func cancelRecording() async {
    guard _isRecording else { return }
    cleanupRecordingState(endAudio: false)
    _isRecording = false
    _currentTranscript = ""
}
```

Key difference from `stopRecording()`:
- `cancelRecording()` passes `endAudio: false` — does NOT call `recognitionRequest?.endAudio()`, just cancels the task and stops the engine
- `cancelRecording()` skips the 500ms `Task.sleep` — no waiting for finalization
- `cancelRecording()` clears the transcript — clean state for next session

### 3. `Packages/MurmurCore/Sources/MurmurCore/Pipeline.swift`

Expose both through Pipeline:

```swift
/// The live partial transcript from the current recording session.
public var currentTranscript: String {
    get async { await transcriber.currentTranscript }
}

/// Cancel recording immediately without finalization or extraction.
public func cancelRecording() async {
    await transcriber.cancelRecording()
}
```

### 4. `Murmur/Views/RootView.swift`

Refactor `handleStopRecording()` to check live transcript first:

```swift
private func handleStopRecording() {
    guard let pipeline = appState.pipeline else {
        showToast("Pipeline not configured — check API key", type: .error)
        return
    }
    guard appState.recordingState == .recording else { return }

    Task { @MainActor in
        // Yield to let any pending recognition callbacks update currentTranscript
        await Task.yield()

        // Instant check: if nothing was said, bail immediately
        let liveText = await pipeline.currentTranscript
        if liveText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await pipeline.cancelRecording()
            withAnimation {
                appState.recordingState = .idle
            }
            transcript = ""
            return
        }

        // Content detected — show processing and run full pipeline
        withAnimation {
            appState.recordingState = .processing
        }

        do {
            let result = try await pipeline.stopRecording()
            transcript = result.transcript.text
            appState.processedEntries = result.entries
            appState.processedTranscript = result.transcript.text
            appState.processedAudioDuration = result.transcript.duration
            appState.processedSource = .voice
            await appState.refreshCreditBalance()
            withAnimation {
                appState.recordingState = .confirming
            }
        } catch {
            print("Stop recording failed: \(error.localizedDescription)")
            withAnimation {
                appState.recordingState = .idle
            }
            // Safety net: empty transcript that slipped through live check
            if case PipelineError.emptyTranscript = error {
                transcript = ""
                return
            }
            handlePipelineError(error, fallbackPrefix: "Processing failed")
        }
    }
}
```

### 5. `Murmur/MurmurApp.swift`

Update background cleanup to use `cancelRecording()` — no need for finalization or extraction:

```swift
// Change from:
try? await appState.pipeline?.stopRecording()
// To:
await appState.pipeline?.cancelRecording()
```

### 6. `Packages/MurmurCore/Tests/MurmurCoreTests/Mocks.swift`

Update `MockTranscriber` with new protocol requirements:

```swift
final class MockTranscriber: Transcriber, @unchecked Sendable {
    var _isRecording = false
    var _isAvailable = true
    var _currentTranscript = ""           // NEW
    var transcriptToReturn = "Buy milk and finish the report"
    var errorToThrow: Error?

    var currentTranscript: String {       // NEW
        get async { _currentTranscript }
    }

    func cancelRecording() async {        // NEW
        _isRecording = false
        _currentTranscript = ""
    }
    // ... rest unchanged
}
```

### 7. `Packages/MurmurCore/Tests/MurmurCoreTests/PipelineTests.swift`

Add tests:

- `cancelRecording()` stops transcriber without extraction (LLM not called)
- `currentTranscript` returns live text from transcriber
- Existing tests pass unchanged

## Edge Cases

- **Double-tap stop**: Guard `appState.recordingState == .recording` prevents re-entry
- **App backgrounds during recording**: `cancelRecording()` is instant — no wasted API call, no 500ms wait
- **Recognition callback timing**: `await Task.yield()` drains pending MainActor tasks before reading `currentTranscript`, ensuring latest value
- **Speech just before stop**: If a recognition result is truly in-flight (not yet dispatched to MainActor), the empty check might miss it. Safety net: `stopRecording()` in the non-empty path rechecks via its own empty guard, so worst case is a false-empty that silently returns to idle — acceptable for borderline-silence recordings
- **Non-empty but transcript changes during 500ms**: The finalization in `stopRecording()` may produce a slightly different final transcript. The LLM handles the final text, not the live text — this is correct

## Acceptance Criteria

- [ ] No processing overlay when recording silence (instant return to idle)
- [ ] Non-empty recordings still flow through processing → confirmation
- [ ] Background app transition uses instant `cancelRecording()` (no wasted API credits)
- [ ] `await Task.yield()` ensures latest transcript before empty check
- [ ] Safety net: `emptyTranscript` catch still handles edge cases
- [ ] Existing Pipeline tests pass
- [ ] New tests for `cancelRecording()` and `currentTranscript`

## References

- Live transcript: `AppleSpeechTranscriber.swift:16` (var), `:109` (callback update)
- Partial results enabled: `AppleSpeechTranscriber.swift:74` (`shouldReportPartialResults = true`)
- Transcriber cleanup: `AppleSpeechTranscriber.swift:177-195` (`cleanupRecordingState`)
- 500ms wait: `AppleSpeechTranscriber.swift:133`
- RootView handler: `RootView.swift:374-404`
- MurmurApp background: `MurmurApp.swift:45`
- Pipeline tests: `PipelineTests.swift`
- Prior fix: commit `2758777` (issue #11)
- Apple docs: [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer), [shouldReportPartialResults](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/shouldreportpartialresults)
