---
id: "000"
title: "Voice to Vision: Defining Murmur"
status: active
author: gudnuf
project: Murmur
tags: [brainstorm, architecture, data-model, encryption, voice-first, ai-agent]
sessions:
  - id: 697af049
    slug: murmur-brainstorm-and-scaffold
    dir: -Users-claude
prompts: []
created: "2026-02-10T06:00:00Z"
updated: "2026-02-10T07:10:00Z"
---

# 000: Voice to Vision — Defining Murmur

## What Murmur Is

A voice-powered scratchpad where everything you say gets immediately interpreted, categorized, encrypted, and stored. The AI doesn't just transcribe — it understands what you meant and structures it accordingly. Say "pick up dry cleaning" and it becomes a todo. Say "what if there was an app that turns receipts into meal plans" and it becomes an idea. Say "DMV Thursday" and it becomes a time-bound reminder.

The home screen is not designed by the developer. It's **composed by an LLM at runtime** — a grid of widget cards the AI picks based on what it thinks you need to see right now. Two todos that are due soon, an idea you had a while back that's worth revisiting, a reminder about the DMV. You open the app and the AI has already curated it for you.

But the AI won't always know best. So there are also **pinned views** — user-configured screens (Todo, Ideas, Don't Forget, Habits, All) accessible via a bottom sheet. The AI composes the home, the user controls the views.

**Beauty through simplicity.** Minimal UI. One mic button. The power is in the intelligence behind the interface, not the interface itself.

## The Core Insight

Most note/todo apps force you to categorize before you capture. You have to decide: is this a task? A note? A reminder? Which project does it belong to?

Murmur inverts this. **Capture first, categorize automatically.** The LLM does the categorization in the same pipeline as transcription — there is no "unprocessed" state. By the time an entry hits the database, it already has a category, a summary, tags, and possibly an extracted due date and priority.

This means the friction of capture approaches zero: tap, speak, done. The AI handles the rest.

## Architecture Decisions

### The Entry Model

The atomic unit is called **Entry**, not "Thought" — because not everything is a thought. Some entries are purely actionable (todos), some are structured data (lists), some are time-bound (reminders), and some really are thoughts. The **category** is what gives each entry its meaning:

- `todo` — actionable task
- `idea` — creative/conceptual
- `reminder` — time-bound
- `note` — informational
- `list` — collection of items
- `habit` — recurring behavior
- `question` — something to look up
- `thought` — true free-form thinking

This naming decision came from feedback: "the distinction should not be thoughts because some things are purely actionable while others have specific meaning." The category, not the container, carries the semantic weight.

### Immediate Processing Pipeline

No entry ever exists in a limbo state. The pipeline is synchronous:

```
[Speak] → TranscriberService → raw text
  → LLMService.processEntry() → category, summary, priority, tags, dueDate
  → EncryptionService.encrypt() → EncryptedString
  → SwiftData persist
  → Recompose home widget layout
```

Steps 2-5 happen as a single async chain triggered the moment transcription completes. The user sees their entry appear on screen already categorized and placed.

### Encryption at Rest

Users speak sensitive things — passwords, personal thoughts, financial details. Nothing should be stored in plaintext.

| Layer | Scope | Mechanism |
|-------|-------|-----------|
| iOS Data Protection | Entire SQLite DB | `NSFileProtectionComplete` — OS encrypts when locked |
| Field Encryption | rawTranscript, processedContent | CryptoKit AES-GCM via `EncryptedString` type |
| Keychain | API keys, encryption keys | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Memory | Runtime | Decrypted content cleared when views disappear |

The `EncryptedString` type wraps a CryptoKit sealed box and conforms to `Codable` for transparent SwiftData storage. The `EncryptionService` protocol manages the key lifecycle.

### Protocol-First AI Integration

No concrete AI backend yet. Two protocols define the contract:

**TranscriberService** — voice to text. Reference impl: Apple Speech (free, on-device). Designed to swap to Whisper, Deepgram, etc.

**LLMService** — text to structure. Designed around OpenAI-compatible chat completion shape for maximum backend compatibility (ollama, llama.cpp, vLLM, Claude API, OpenAI API all work). Mock implementation for UI development.

This means we can build the entire UI and interaction model without committing to a backend. The mock LLM returns deterministic results — enough to develop and test every screen.

### Widget Composition System

The home screen is a `ScrollView` of `WidgetCard` components. Three sizes:
- **Small** (1x1) — single stat or quick reminder
- **Medium** (2x1) — 2-3 items or a highlight card
- **Large** (2x2) — full list or detailed view

All widgets share `Theme.swift` design tokens. The LLM picks which widgets appear and in what order via `LLMService.composeHomeLayout()`. Users can **pin** widgets they always want to see.

For WidgetKit (iOS home screen), the same data model drives small/medium/large widget families with interactive actions (complete a todo without opening the app).

### Tech Stack

| Layer | Choice | Why |
|-------|--------|-----|
| UI | SwiftUI | Declarative composition, native widget support |
| Persistence | SwiftData | Type-safe, SwiftUI integration, handles Entry↔Tag relationships |
| Encryption | CryptoKit | Native, no third-party dependency, AES-GCM |
| Voice | Apple Speech (ref impl) | Free, on-device, protocol-abstracted |
| LLM | Protocol-abstracted | OpenAI-compatible shape, mock for dev |
| Build | Nix + direnv + XcodeGen | Reproducible environment, no xcodeproj in git |
| Min iOS | 17.0 | SwiftData + interactive widgets requirement |

## Milestones

8 milestones defined in the spec (`~/Murmur/.claude/project-spec.yml`):

- **M0**: Project scaffold — Nix, XcodeGen, CI, models, encryption, theme
- **M1**: Voice capture + immediate processing — full pipeline working
- **M2**: Widget system — reusable WidgetCard components, static layout
- **M3**: AI-composed home — LLM selects and arranges widgets dynamically
- **M4**: Views & navigation — pinned views, search, filtering, entry detail
- **M5**: Home screen widgets — WidgetKit extension with App Groups
- **M6**: Agent intelligence — pattern analysis, time-aware, habits, streaks
- **M7**: Open backends & polish — real LLM connections, settings, onboarding

M0-M3 are the core product. M4-M7 are expansion.

## Design Direction

8 HTML mockups in `~/Murmur/mockups/` establish the visual language:
- Deep dark background (`#0A0A0F`)
- Subtle purple accent (`#7C6FF7`)
- Lots of breathing room
- Widget cards with rounded corners and gradient borders
- Floating mic button with glow effect
- CSS-animated waveform during recording

**Open exploration:** The user wants to consider making the default design more like an empty slate focused on todos — simpler than the full AI-composed widget grid. This might mean the home screen starts minimal and the AI adds variety over time as you capture more entries. Not decided yet.

## Ideas to Explore (Not Yet Spec'd)

1. **Knowledge graph / second brain** — Using graph techniques to connect entries to each other beyond simple tags. The user referenced "building a second brain in Notion" and wants Murmur to be that but better, cleaner, more actionable. This could mean Entry relationships become a proper graph (not just parent-child), with the AI discovering and surfacing connections.

2. **Todo-focused empty slate** — Start minimal. Show todos first. Let the AI earn the right to add more widget types as it learns what the user cares about.

3. **Spec → GitHub Issues pipeline** — The milestones need to become actionable GitHub Issues so multiple Claude Code sessions can build in parallel. Each issue needs enough context to be self-contained.

## What Exists Right Now

```
~/Murmur/
├── .git/                           # Initialized, 1 commit (b27bd8d)
├── .claude/
│   ├── project-spec.yml            # 430+ line spec — the source of truth
│   └── meta/
│       └── 000-voice-to-vision.md  # This file
└── mockups/
    ├── 01-home-ai.html             # AI-composed widget home
    ├── 02-home-empty.html          # First launch empty state
    ├── 03-voice-capture.html       # Recording overlay with waveform
    ├── 04-pinned-views.html        # Views bottom sheet
    ├── 05-todo-view.html           # Todo list view
    ├── 06-thought-detail.html      # Entry detail (filename pre-dates rename)
    ├── 07-ios-widget.html          # WidgetKit home screen widget
    └── 08-settings.html            # Backend configuration
```

No Swift code yet. No Nix flake. No XcodeGen project. We're still in Phase 1 of `/init-ios-app` — the spec exists and has been reviewed once, but the user wants to iterate further before moving to Phase 2 (project setup and template instantiation).

## What's Next

1. **Iterate on the spec** — Review the project-spec.yml with fresh eyes. Explore the todo-focused design and knowledge graph ideas. The spec determines everything downstream.
2. **Approve Gate 1** — When the spec is solid, approve it and move to Phase 2.
3. **Phase 2: Template instantiation** — Nix flake, XcodeGen project.yml, Makefile, theme, models, CI. The init-ios-app skill handles this.
4. **Create GitHub repo + Issues** — Convert milestones to actionable issues for parallel development.

---

*Entry 000 because this is where it starts. Murmur doesn't exist as code yet — just a spec, some mockups, and a clear idea of what it should become. The next entry will be about building it.*
