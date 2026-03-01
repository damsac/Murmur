---
id: "003"
title: "Spec + Mockup Alignment for Phase 2 Readiness"
status: completed
author: gudnuf
project: Murmur
tags: [spec, mockups, alignment, lock-icon, settings, terminology, progressive-disclosure]
previous: "002"
sessions:
  - id: aea1ffac
    slug: spec-mockup-alignment
    dir: -Users-claude-Murmur
  - id: 807b3c38
    slug: audit-and-plan
    dir: -Users-claude-Murmur
prompts: []
created: "2026-02-11T01:57:00Z"
updated: "2026-02-11T01:57:00Z"
---

# 003: Spec + Mockup Alignment for Phase 2 Readiness

## Context

After the V1 UX revision (entry 002: 21 mockups + 860-line spec), an audit revealed several mismatches between `project-spec.yml` and the HTML mockups. Two design decisions also crystallized: **remove the lock icon entirely** and **remove settings from Level 0**. This entry documents the cleanup pass that brings everything into alignment before Phase 2 (project scaffold + code).

## What Changed

### 1. Lock Icon Removed Everywhere

**Decision**: The lock icon was a carryover from the cypherpunk aesthetic brainstorm, but it was solving a problem users don't have at Level 0. Privacy in Murmur is *structural* (AES-256-GCM, Secure Enclave keys) not *decorative* (a green dot on a padlock). The lock icon added visual noise to an app whose entire identity is "start empty, earn complexity."

**Spec changes**:
- Deleted `privacy.lock_icon` field
- Updated pillar wording: "lock icon always visible" -> "privacy is structural not decorative"
- Cleaned Level 0 `what_appears`, S1/S7 descriptions, M1/M2 milestone issue descriptions

**Mockup changes** (4 files):
- `15-void.html` — removed lock icon + green dot, header is now token-balance-only (right-aligned)
- `21-home-sparse.html` — removed lock icon from header-left
- `01-home-ai.html` — removed lock icon from header-row
- `11-focus-dismissed.html` — removed lock icon from header-row
- `index.html` — updated nav subtitle "mic + lock + tokens" -> "mic + tokens"

### 2. Settings Moved from Level 0 to Level 3

**Decision**: At Level 0, the user has zero entries — there's nothing to configure. Settings becomes meaningful when bottom nav appears (Level 3+, 20+ entries). This simplifies the void state and removes the question "how do you even reach settings at Level 0 without a lock icon?"

**Changes**:
- Level 0 screens: `[S1, S2, S3, S4, S5]` -> `[S1, S2, S3, S4]`
- Level 3 screens: `[S10, S11]` -> `[S5, S10, S11]`
- S5 level: `0` -> `3`
- S5 description: removed "Entry via lock icon (Level 0-2)", now "Accessible via Settings tab in bottom nav (Level 3+)"
- M3 settings issue description updated to reflect Level 3+

### 3. Token Display Contradiction Fixed

**Problem**: Spec said tokens are "Hidden during recording" but the S2 recording mockup already showed `↑ 0 · ↓ 0` counters during recording.

**Fix**: Changed `tokens.display.recording` to "Counters visible at ↑ 0 · ↓ 0 during recording (on-device transcription = free). Animate when processing begins." This matches both the mockup and the intent — the counters *exist* during recording, they just don't move until processing starts.

### 4. "Thought" -> "Entry" Terminology

**Problem**: Several mockups still used "Thought" as a screen/model name, but the data model renamed it to "Entry" during the V1 revision. Not all entries are thoughts — some are todos, reminders, lists.

**Changes**:
- `06-thought-detail.html` — nav title "Thought" -> "Entry", page title updated
- `06b-thought-detail-expanded.html` — same nav title + page title fix
- `04-pinned-views.html` — "All Thoughts" -> "All Entries" (view name + comment)

**Left alone**: `08-settings.html` "Export Thoughts" — this is a legacy mockup (`level: null`, replaced by progressive settings) so no fix needed.

### 5. Bottom Nav Clarification Note

**Problem**: Some mockups show bottom nav on screens that unlock at Level 1 (focus cards, sparse home). This looks like a contradiction — spec says bottom nav appears at Level 3+.

**Resolution**: Not a bug. The mockups depict screens as seen by a Level 3+ user. The `level` field is the *minimum* unlock level, not the *only* level. Added a clarifying comment to `ui_mockups` section:

> "The `level` field indicates the minimum unlock level for each screen. Screens may appear with additional chrome (e.g., bottom nav) at higher levels."

## Files Modified

| File | Changes |
|------|---------|
| `.claude/project-spec.yml` | Lock icon removal, settings level change, token display fix, nav note, milestone updates |
| `mockups/15-void.html` | Removed lock icon element + CSS |
| `mockups/21-home-sparse.html` | Removed lock icon element + CSS |
| `mockups/01-home-ai.html` | Removed lock icon element + CSS |
| `mockups/11-focus-dismissed.html` | Removed lock icon element + CSS |
| `mockups/06-thought-detail.html` | "Thought" -> "Entry" |
| `mockups/06b-thought-detail-expanded.html` | "Thought" -> "Entry" |
| `mockups/04-pinned-views.html` | "All Thoughts" -> "All Entries" |
| `mockups/index.html` | "lock" removed from S1 subtitle |

## Verification

All grep checks pass:
- `lock` in mockups: zero UI references (only CSS `display: block` hits)
- `lock` in spec: zero UI references (only "unlock", "locked behind Level 4", encryption context)
- `Thought` in mockups: zero as screen/model name (only legacy `08-settings.html` "Export Thoughts")
- Level 0 screens confirmed `[S1, S2, S3, S4]`
- S5 level confirmed `3`
- `tokens.display.recording` no longer says "Hidden"

## Developer Patterns Observed

- **Audit before scaffold** — catching these mismatches now saves significant rework in Phase 2. A lock icon baked into SwiftUI components would have been much harder to remove.
- **Decisions cascade** — removing the lock icon forced the question "how do you reach settings?" which forced settings to Level 3+, which simplified the void state. One decision cleaned up three issues.
- **Grep is the spec test suite** — systematic grep verification caught the `index.html` and `06b` references that the plan missed.

## What's Next

Phase 2: project scaffold, SwiftData models, and the first buildable screen (S1: The Void). The spec and mockups are now aligned and ready to drive implementation.
