---
date: 2026-02-17
topic: mvp-cleanup
---

# MVP Cleanup: Solid Foundation from First Principles

## What We're Doing

Clean up the Murmur codebase after wiring MurmurCore into the UI. Remove mock state, orphan unwired views, and simplify DevMode so the main app contains only real functionality. The goal is a clean, maintainable MVP foundation.

## Current State Assessment

**What's solid:**
- MurmurCore is well-separated (no SwiftUI, no persistence)
- ExtractedEntry -> Entry bridge pattern is clean
- Deleted models (CreditBalance, Tag, UserProgress) have no dangling references
- PersistenceConfig schema only includes Entry.self
- Onboarding consolidation is complete (old views deleted, OnboardingFlowView replaces them)

**What needs cleanup:**
- Mock state embedded in production code
- DevMode is overcomplicated (50-screen browser, 34k component gallery)
- Unwired UI shells compiled into the app
- project.yml has no file-level excludes

## Key Decisions

### 1. Remove All Mock State

- **Delete** `Murmur/Services/MockDataService.swift`
- **Remove** `creditBalance: Int = 1000` from AppState
- **Remove** hardcoded `TokenBalanceLabel(balance: 4953)` from VoidView
- **Remove** any credit/token UI that isn't wired to real data

### 2. Simplify DevMode (Keep Useful, Remove Complex)

**Keep these dev features:**
- Disclosure level override (force L0-L4 without real entries)
- Reset/clear data (wipe SwiftData + UserDefaults)
- Pipeline debug info (transcription text, LLM response, errors)

**Remove:**
- Screen browser (DevScreen.swift with ~50 screen definitions)
- Component gallery (DevComponentGallery.swift — 34k)
- DevComponent.swift enum
- creditBalance stepper (no more mock credits)
- State toggles for mock state (showFocusCard, etc.)

**Simplify DevModeView.swift** to just the three useful panels.

### 3. Orphan Unwired Views (Exclude from Target)

These files are UI shells only referenced by DevScreen.swift (which is being removed). Exclude from the Xcode target via project.yml `excludes`:

```
Murmur/Views/Credits/TopUpView.swift
Murmur/Views/Errors/APIErrorView.swift
Murmur/Views/Errors/LowTokensView.swift
Murmur/Views/Errors/MicDeniedView.swift
Murmur/Views/Errors/OutOfCreditsView.swift
Murmur/Views/Dialogs/DeleteConfirmDialog.swift
```

**Keep in target** (actually used in MainTabView):
- EmptyStateView.swift
- SettingsMinimalView.swift
- SettingsFullView.swift

### 4. Orphan DevMode Complex Files

Move these out of the compile target but preserve in repo:

```
Murmur/DevMode/DevScreen.swift
Murmur/DevMode/DevComponentGallery.swift
Murmur/DevMode/DevComponent.swift
```

**Keep in target:**
- DevModeView.swift (simplified)
- DevModeActivator.swift

## Implementation Approach

Use `project.yml` excludes to orphan files rather than deleting them. This keeps git history clean and lets us bring views back when they're wired to real functionality.

```yaml
sources:
  - path: Murmur
    excludes:
      - "**/.DS_Store"
      - "Views/Credits/**"
      - "Views/Errors/APIErrorView.swift"
      - "Views/Errors/LowTokensView.swift"
      - "Views/Errors/MicDeniedView.swift"
      - "Views/Errors/OutOfCreditsView.swift"
      - "Views/Dialogs/**"
      - "DevMode/DevScreen.swift"
      - "DevMode/DevComponentGallery.swift"
      - "DevMode/DevComponent.swift"
      - "Services/MockDataService.swift"
```

## Follow-Up: Credit System Design

**Not in scope for this cleanup**, but captured here:

- Users buy credits
- Each Transcriber and LLMService has a cost
- Cost is proportional to tokens in/out
- Pipeline consumes user credits per run
- Needs: cost reporting on service protocols, credit balance persistence, purchase flow

## Open Questions

- Should we keep the TokenBalanceLabel component itself (orphan it) or remove it entirely?
- Is there any mock state in the components (CaptureBar, EntryCard, etc.) that needs cleaning?

## Next Steps

1. Update project.yml with excludes
2. Simplify DevModeView.swift
3. Clean AppState (remove mock creditBalance, unnecessary toggles)
4. Clean VoidView (remove hardcoded token display)
5. Delete MockDataService.swift (or just exclude — it's pure mock)
6. Regenerate Xcode project (`xcodegen generate`)
7. Build and verify no compilation errors
8. Run tests

-> `/workflows:plan` for implementation details
