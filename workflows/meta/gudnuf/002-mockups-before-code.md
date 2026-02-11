---
id: "002"
title: "Mockups Before Code: The UI-First Pivot"
status: active
author: gudnuf
project: Murmur
tags: [ux, mockups, progressive-disclosure, tokens, design, pivot]
previous: "001"
sessions:
  - id: 96fee715
    slug: conversation-archaeology
    dir: -Users-claude-Murmur
prompts: []
created: "2026-02-11T09:00:00Z"
updated: "2026-02-11T09:00:00Z"
---

# 002: Mockups Before Code — The UI-First Pivot

## Context

After entry 000 (spec + 8 initial mockups) and entry 001 (repo + Pages deploy), the natural next step was Phase 2: scaffold the Xcode project, write models, start building. Instead, a drastic change: **stop everything and build out the entire UI/UX in HTML mockups first**. No Swift until every screen is designed, every interaction is mapped, and the progressive disclosure system is fully visualized.

This decision came from testing the `init-ios-skill` workflow on Murmur itself. The skill's own entry 001 flagged a gap: "jumps from Phase 1 (spec) to Phase 2 (template instantiation) with nothing in between." For a UI-heavy, interaction-design-critical app like Murmur, going from YAML spec to code skips the most important validation step — *seeing and feeling the interface*.

## What Changed

### The V1 UX Revision (Feb 9-10)

Over ~12 hours, 13 new mockups (09-21) were handcrafted, and several original mockups (01, 11, 13) were updated. This wasn't incremental polish — it was a wholesale rethinking of how the app works, organized around three new pillars:

**1. Progressive Disclosure (5 Levels)**

The app no longer boots into a feature-rich home screen. It starts as **"The Void"** — just a mic button floating in darkness. Features unlock as the user builds history:

| Level | Name | Trigger | What Unlocks |
|-------|------|---------|--------------|
| 0 | The Void | 0 entries | Mic + darkness, nothing else |
| 1 | First Light | 1+ entries | Sparse home, recent entries appear |
| 2 | Grid Awakens | 5+ entries | Widget cards, AI-composed layout |
| 3 | Views Emerge | 20+ entries | Bottom nav, pinned views, categories |
| 4 | Full Power | 50+ entries | Live Feed, advanced settings, insights |

Hidden "Show all features" escape hatch for power users who don't want to wait.

**2. Token System**

Generic "tokens" as the credit unit, mapped to real LLM input/output tokens. The UI makes AI costs *visible*:
- Directional flow counters: ↑ input (transcript sent) and ↓ output (entries streaming back)
- Starter balance of 5,000 tokens
- Three top-up methods: Apple Pay, Cashu ecash (cypherpunk bearer tokens), monthly subscription
- Zero balance degrades gracefully — recording works, AI processing disabled

**3. Cypherpunk Privacy Aesthetic**

Lock icon always visible. Encryption ambient in the design language. Cashu ecash as a payment option signals: *we take privacy seriously, even in how you pay*.

### New Mockups Created

| # | Screen | Purpose |
|---|--------|---------|
| 09 | Focus: Todo | Focus card for a single todo item |
| 10 | Focus: Insight | AI-generated insight card |
| 11 | Focus: Dismissed | What happens after dismissing a focus card |
| 12 | Confirm: Single | Card-by-card entry confirmation |
| 13 | Confirm: List | All items with session cost breakdown |
| 14 | Confirm: Edit | Voice correction flow |
| 15 | The Void | Level 0 — just the mic |
| 16 | Recording + Credits | Recording with live token flow counter |
| 17 | Confirm + Credits | Confirmation showing session token cost |
| 18 | Settings (Minimal) | Stripped-down settings for Level 0-2 |
| 19 | Top-Up | Credit purchase: Card / Cashu / Subscribe |
| 20 | Recording: Live Feed | Level 4+ — items materialize during recording |
| 21 | Home: Sparse | Level 1 — first entries appearing |

### Updated Mockups

- **01** (Home AI) — added lock icon + token balance indicators
- **11** (Focus Dismissed) — redesigned to show token flow
- **13** (Confirm List) — added session cost breakdown

### 12 V1 Screens Defined

S1 Void, S2 Recording, S3 Processing, S4 Confirm, S5 Settings (minimal), S6 Focus Card, S7 Home Sparse, S8 Home AI-Composed, S9 Entry Detail, S10 Views, S11 Category View, S12 Credits/Top-Up.

## Why This Matters

The 860-line YAML spec described Murmur's architecture precisely. But reading "progressive disclosure with 5 levels" is not the same as *seeing* the Void screen next to the Full Power home screen. The mockups became the conversation artifact — they aligned vision more effectively than the spec alone could.

This is a meta-insight about the `init-ios-skill` workflow itself: for UI-heavy apps, **Phase 1.5 (visual design) belongs between spec and scaffold**. The skill's original flow (spec → template → code) assumes the spec is sufficient to start building. For Murmur, it wasn't.

## Developer Patterns Observed

- **Manual mockup creation was deliberate** — the V1 UX revision (mockups 09-21) was done by hand, not in a Claude Code session. This suggests the designer needed direct control over pixel-level decisions that conversational prompting would slow down.
- **Model rename cascaded everywhere** — changing "Thought" to "Entry" (because "some things are purely actionable") required touching the spec, mockups, and mental model. The category system (8 types) carries semantic weight the container name never could.
- **WidgetKit deferred to V1.1** — resisting scope creep. Nail the in-app experience before extending to the home screen.
- **Live Feed (Level 4) ships in V1 but locked** — the most expensive feature (2x token cost) is gated behind usage, not a paywall.
- **"Wait, we've done a lot" moment** — pausing mid-flow to reflect and document validated the idea that Gate 1 should explicitly encourage reflection time.

## Architecture Snapshot

```
Phase 1 (COMPLETE)                    Phase 2 (NEXT)
─────────────────                     ──────────────
project-spec.yml (860+ lines)    →   Nix flake
21 HTML mockups                   →   XcodeGen project.yml
Entry model defined               →   Swift models + encryption
Processing pipeline designed      →   Service protocols
Progressive disclosure mapped     →   Level state machine
Token system specified            →   Token balance service
12 screens identified             →   SwiftUI views
```

## Artifacts

- [Live mockup index](https://damsac.github.io/Murmur/) — all 21 mockups browsable
- [GitHub repo](https://github.com/damsac/Murmur)
- `mockups/15-void.html` — the defining screen: just a mic in the dark
- `.claude/project-spec.yml` — the full 860+ line spec

## Open Questions

1. **Brainstorm deserves its own skill?** — Phase 1 of init-ios-skill bundles open-ended ideation with structured spec generation. Should there be a separate `/brainstorm` skill for divergent thinking that produces a brief, then hands off to `/init-ios-app` for convergent work?
2. **Spec → GitHub Issues pipeline** — 24 issues across 4 milestones are planned but not yet created. How to make each issue self-contained enough for parallel Claude Code sessions?
3. **Knowledge graph / second brain** — the user referenced "building a second brain in Notion" and wants Murmur to be that but better. Entry relationships as a proper graph (not just parent-child) with AI-discovered connections. Not yet spec'd.

## What's Next

1. **Phase 2: Template instantiation** — Nix flake, XcodeGen `project.yml`, Makefile, theme, models, CI
2. **Create GitHub Issues** — 24 issues across 4 milestones (Core Pipeline, Home + Focus, Credits + Privacy, Views + Polish)
3. **Build M1: Core Pipeline** — Scaffold, models, Void state, recording, processing, confirm screen, service protocols
