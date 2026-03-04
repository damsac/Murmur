---
id: "000"
title: "Joining Murmur: Frontend Setup and First PRs"
status: completed
author: IsaacMenge
project: Murmur
tags: [onboarding, frontend, swiftui, ui-design, onboarding-flow, focus-strip]
sessions:
  - id: 3ac264ad
    slug: frontend-planning
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: a869a340
    slug: onboarding-redesign
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: cbcd8441
    slug: briefing-message-and-height-fix
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
  - id: a7d32b77
    slug: process-and-meta-workflow
    dir: -Users-isaacwallace-menge-CascadeProjects-Murmur
prompts: []
created: "2026-03-03T00:00:00Z"
updated: "2026-03-03T00:00:00Z"
---

# 000: Joining Murmur — Frontend Setup and First PRs

## Context

sac joined the Murmur project mid-development, inheriting an existing SwiftUI codebase from dam. The app had a working backend pipeline (voice → transcription → LLM → entries) but needed frontend polish. This entry covers the onboarding to the project, the first major UI contributions, and the process of establishing working habits.

---

## Timeline

### Phase 1: Getting Oriented (`3ac264ad`)

**What**: Explored the existing codebase and made the first frontend planning decisions.

**Decisions**:
- Reuse existing Slate infrastructure rather than rebuild from scratch
- Build new UI components from mockups, iterating visually in the simulator
- sac's lane: SwiftUI frontend and visual design; dam's lane: backend, MurmurCore, LLM systems

**Developer thinking**: First session was about understanding what already existed before touching anything. Spent time mapping what was there vs. what was needed. Visual-first instinct — wanted to see the app running before deciding what to change.

---

### Phase 2: Onboarding Redesign (`a869a340`, PR #56 → #67)

**What**: Rebuilt the onboarding flow from scratch into a 4-step sequence that demonstrates the app's core loop.

**The 4 steps**:
1. **Welcome** — intro screen, app value prop
2. **Transcript** — simulated voice recording with live transcript demo
3. **Processing** — shows the LLM working (animated state)
4. **Result** — displays extracted entries, previews the home screen

**Key files created/changed**:
- `OnboardingWelcomeView.swift`
- `OnboardingResultView.swift`
- `OnboardingFlowView.swift`

**Decisions**:
- Onboarding should demo the actual product loop, not just explain it
- The demo overlay (`LiveFeedRecordingView`) is richer than the real recording overlay — this gap was noted as a future problem (P2 in launch brainstorm)
- Hardcoded demo content for onboarding; real pipeline wired for production

**Problems**: Coordinating with dam's backend changes while building the frontend. Onboarding had to be isolated enough that it wouldn't break on pipeline changes.

---

### Phase 3: Focus Strip Polish (`cbcd8441`, PRs #79 and #80)

**What**: Two PRs polishing the focus strip — the LLM-curated section dam built.

**PR #79 — Briefing message above focus strip**:
- Bug: briefing message was hidden when daily focus had zero items
- Fix: restructured `FocusStripView` so greeting + message always render when `dailyFocus != nil`, cards are conditional
- Also fixed: deterministic fallback was double-prefixing the greeting

**PR #80 — Natural focus strip height + smooth transitions**:
- Removed the `shimmerHeight`/`ZStack`/`GeometryReader` fixed-height hack from `FocusContainerView`
- Replaced with simple `if/else if` — shimmer when loading, strip when loaded
- `LazyVStack` → `VStack` for category sections
- Added `.animation(Animations.smoothSlide, ...)` keyed on focus state

**Status**: Both PRs open and mergeable as of this writing.

---

### Phase 4: Process + Meta (`a7d32b77`, this session)

**What**: Established working habits and process documentation.

**Done**:
- Filled out `meta/sac/PROCESS.md` via interview — working style, session habits, preferences
- Investigated recording bug (cards not appearing after stop) — traced to `_currentTranscript` being empty, applied a fix, then **reverted** when real cause identified as depleted PPQ credits
- Created GitHub issue #81: onboarding flow should match real app UI (to address post UI-polish)
- Wrote this meta-workflow entry (000)

**Key realization on the recording bug**: The transcript check in `stopRecording()` was not the problem. The LLM downstream was failing silently due to no credits. The empty transcript was a symptom (recording too short), not a bug. The fix was valid but not needed — reverted cleanly.

---

## Developer Patterns Observed

- **Visual-first**: Decisions come after seeing the thing in the simulator, not before. Don't spec too much upfront.
- **Design-led**: When UI looks off, sac notices immediately. Backend behavior is trusted until it visibly breaks something.
- **Good instinct on brainstorm docs**: Wrote the launch UI readiness brainstorm before diving into work — helped prioritize and sequence the PRs.
- **Tendency to go deep on bugs**: Investigated the recording bug thoroughly before it turned out to be an external cause. Worth timeboxing debug sessions.
- **Collaboration pattern with dam**: dam builds the system, sac polishes the surface. Works well when STATE.md is kept current so neither steps on the other.

---

## Open Questions

- Onboarding vs. real recording UI gap: the demo is better than the real thing. Simplify demo or improve production overlay? (P2 in launch brainstorm)
- Conversation reset UX: timer, button, or silence? (dam's open question, sac will have UI opinion once the flow is wired)
- Issue #81 (onboarding ↔ real UI sync): needs to be added to the project board once `gh auth refresh -s project` is run

---

## What's Next

From the launch UI readiness brainstorm, in priority order:
1. **Launch screen** — quick win, removes black flash on cold start
2. **Category simplification** (8 → 5) — cleaner home screen, less cognitive load
3. **Search** — pull-down full-text search, table stakes for 30+ entries
4. **Habit streak counter** — card + detail view, retention hook
5. **Real recording overlay polish** — close the gap with onboarding demo
