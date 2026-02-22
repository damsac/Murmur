---
title: "Fix empty transcript handling and toast auto-dismiss"
type: fix
status: active
date: 2026-02-21
issues: [11, 12]
---

# Fix empty transcript handling and toast auto-dismiss

## Overview

Two related UX issues: (1) empty transcripts show a confusing error toast instead of gracefully returning to idle, and (2) toasts never auto-dismiss, requiring manual tap.

## Commit 1: Better handle empty transcripts (closes #11)

### Problem

When the user records but says nothing, `Pipeline.stopRecording()` throws `PipelineError.emptyTranscript`. This gets caught by `handleStopRecording()` and displayed as a generic error toast: "Processing failed: Transcript is empty". The toast feels like something went wrong when really the user just didn't speak.

### Solution

In `handleStopRecording()` (`RootView.swift:396`), detect `PipelineError.emptyTranscript` specifically and silently return to idle state instead of showing an error toast. No toast at all — just gracefully close the recording overlay and go back to the home screen.

### Changes

**`Murmur/Views/RootView.swift`** — `handleStopRecording()` (line ~396):

```swift
} catch {
    print("Stop recording failed: \(error.localizedDescription)")
    withAnimation {
        appState.recordingState = .idle
    }
    // Empty transcript = user said nothing — just return to idle silently
    if case PipelineError.emptyTranscript = error {
        transcript = ""
        return
    }
    handlePipelineError(error, fallbackPrefix: "Processing failed")
}
```

## Commit 2: Add toast auto-dismiss timeout (closes #12)

### Problem

RootView displays toasts manually via `showSuccessToast` state but never auto-dismisses them. The existing `ToastContainer` modifier has auto-dismiss logic (3s default), but RootView doesn't use it. All 17 toast trigger points are affected.

### Solution

Replace the manual toast implementation in RootView with the existing `ToastContainer` view modifier that already supports auto-dismiss with configurable duration.

### Changes

**`Murmur/Views/RootView.swift`**:

1. Replace state vars (lines 17-18):
   ```swift
   // Remove:
   @State private var showSuccessToast = false
   @State private var toastMessage = ""

   // Add:
   @State private var toastConfig: ToastContainer.ToastConfig?
   ```

2. Remove the manual toast overlay block (lines 107-126) entirely — the `.toast()` modifier handles display.

3. Add `.toast($toastConfig)` modifier to the ZStack.

4. Replace `showToast(_:)` helper (lines 521-526):
   ```swift
   private func showToast(_ message: String, type: ToastView.ToastType = .success, duration: TimeInterval = 3.0) {
       toastConfig = ToastContainer.ToastConfig(message: message, type: type, duration: duration)
   }
   ```

5. Update toast callers to use appropriate types:
   - Error toasts (pipeline errors, permission errors, save failures) → `.error` type
   - Warning toasts (pending purchase) → `.warning` type
   - Success toasts (saved, top-up) → `.success` type (default)

**`Murmur/Components/ToastView.swift`** — `ToastContainer`:

6. Add tap-to-dismiss to `ToastContainer` (to preserve existing UX from manual implementation):
   ```swift
   .onTapGesture {
       dismissTask?.cancel()
       withAnimation(Animations.toastSpring) {
           toast = nil
       }
   }
   ```

## References

- Toast implementation: `Murmur/Components/ToastView.swift`
- Toast display + all triggers: `Murmur/Views/RootView.swift`
- Pipeline error: `Packages/MurmurCore/Sources/MurmurCore/Pipeline.swift:53-55`
- Related issues: #11, #12
