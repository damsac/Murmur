# Dam & Sac: Design Psychology Research

**Date:** 2026-03-04
**Purpose:** Build mental models of why dam and sac prefer different home view approaches, to inform a non-judgmental settings toggle between two variants.

---

## 1. Psychological Profiles

### Dam (gudnuf)

**What he optimizes for: throughput of awareness.**

Dam wants to open the app, absorb the state of his world in one fixation, and close it. The phone screen is a viewport onto a prioritized reality — not a workspace to operate in. The fewer taps between "open app" and "know everything," the better. He does not want to explore. He wants to be told.

**Evidence from commits and PRs:**

dam's commit language is dominated by systems thinking and removal. His most characteristic commits:
- `feat: remove thought category, daily focus system, recording UI` — addition and subtraction in the same breath
- `refactor: remove confirmation UI, wire arrival tracking` — rip things out, replace with less
- PR #50 "Remove progressive disclosure, simplify home screen": **-879 lines, +167 lines (net -712)**. His PR description: "The progressive disclosure was annoying — we were making changes on the same stuff across multiple views." Annoyance at indirection drives architectural decisions.
- PR #54 "Agentic entry management": "If the agent is smart enough, the UI can be dumb." This is a thesis statement for dam's entire design philosophy.

dam builds infrastructure and removes surface area simultaneously. His PRs consistently add capability to the backend while deleting UI: removing the confirmation screen, removing progressive disclosure levels, removing the thought category, removing the results surface. Each removal is framed as liberation — the system got smarter, so the interface can get simpler.

**How he relates to information: scanner, not browser.**

dam consumes information in a single sweep. From his composable home view brainstorm: "Most entries are NOT shown — only what matters right now." And: "5-15 items max. The AI hides most entries." He explicitly wants the AI to be the filter, not himself.

His `DamHomeView` code has zero collapsible sections, zero `@AppStorage` for collapse state, zero chevrons. The view is a single `ScrollView` with composed sections flowing top to bottom — flat, AI-ordered, done. Compact entries render as flow chips (capsule-shaped pills that wrap like text) rather than full-height cards. His hero emphasis has stripped chrome compared to sac's cards: 6pt category dots instead of category badges, 12px padding instead of the card's default, no separate glow overlay.

From the composable home view brainstorm: "Group by context/urgency, not category." dam does not think in categories. He thinks in relevance gradients. An overdue reminder and a high-priority todo belong together not because they share a type, but because they share a demand on his attention.

**His mental model of the app: a dashboard that reads your mind.**

dam describes Murmur as "an autonomous second brain" (CANON.md). The word "autonomous" is doing heavy lifting. The agent should act without permission, organize without instruction, and surface without being asked. His composable home view brainstorm envisions the agent composing the entire screen layout — sections, grouping, density, emphasis — all decided by the AI, not the user.

His agentic entry management brainstorm lays this out starkly: "The Three-Layer Interface: 1. The Smart List (Glance). A single scrollable list of active entries, curated by the agent. No tabs, no categories, no manual sorting." The user's job is to glance, not to organize.

His entry-placement-hints brainstorm extends this further: when the agent creates an entry, it also decides WHERE on the home screen it lands. The user never sees a generic "new entry" row — the entry materializes in its composed position with the right emphasis level and badge. The UI literally arranges itself.

**Interaction style: minimal input, maximal awareness.**

dam's process doc says "Architecture-first. Designs the system before implementing." And: "Thinks in terms of data flow and state machines (TEA architecture)." His interaction ideal is The Elm Architecture applied to a phone: the model changes, the view is a pure function of the model, and the user's only job is to perceive the output.

His removal of the confirmation UI (PR #86) is telling. From the PR description: "The agent is right most of the time, so confirmation adds friction without value. The real need is feedback: the user speaks, and they see things happen. The animation itself is the feedback." Feedback is visual, not interactive. You see the result, you do not approve it.

**Summary: dam trusts computation over cognition.** He would rather the AI be wrong sometimes and correct itself than ask the user to think about organizing anything. The cost of AI error is cheaper than the cost of user attention.

---

### Sac (IsaacMenge)

**What he optimizes for: navigational confidence.**

sac wants to feel oriented. When he opens the app, he wants to know where things are, what has changed, and where to direct his attention next. He builds spatial mental models — "the todos are here, the reminders are here, I already looked at those" — and uses collapse/expand as a way of marking territory as reviewed.

**Evidence from commits and PRs:**

sac's commit language is dominated by visual specificity and user-facing interaction. His most characteristic commits:
- `feat: focus strip + collapsible category sections on home screen` — adding navigational structure
- `feat: home screen visual polish — focus strip redesign, reduced noise` — refining signal-to-noise
- `feat: add status-change feedback with haptics, toasts, and undo delete` — closing feedback loops
- `feat: unified visual design system with attention states` — systematizing visual hierarchy

His PRs are rich with perceptual reasoning. From PR #65 (home visual polish): "The home screen had too much signalling competing for attention — colored card borders, text labels on every badge, a red dot on section headers, an always-visible greeting header. None of it was wrong individually, but together it read as noisy." Sac is constantly calibrating the information density of the screen, looking for the point where signal becomes noise.

From PR #64 (focus strip + collapsible sections): "Two problems with that: (1) nothing jumps out when something is urgent or overdue, and (2) when you have lots of entries they all blur together." sac diagnoses both under-emphasis (nothing jumps out) and over-density (they blur together) as failures. His solution is structural: create visual hierarchy through a focus strip that draws the eye, and collapsible sections that let the user control density.

**How he relates to information: browser who builds spatial models.**

sac groups, categorizes, and navigates. His `SacHomeView` is organized by category in a fixed order (`todo, reminder, habit, idea, list, note, question`), with each section independently collapsible via `@AppStorage` (persisted between launches). The collapse state IS information — "I have looked at this section and I am done with it for now." Collapsing is not hiding; it is marking as reviewed.

His quote from the design discussion captures this perfectly: "If I looked through my todos, then moved on to looking at reminders I might want to collapse my todos to make the screen less cluttered." This is sequential processing — he works through categories one at a time, and collapsing is the gestural equivalent of turning a page.

His focus strip is always visible (unlike dam's composed sections, which might be entirely AI-chosen). From PR #64: "Focus strip is always visible (not hidden when empty) — shows 'All clear' instead. The user needs to trust it's there as a permanent landmark." The word "landmark" reveals spatial thinking: the focus strip is a place on the screen, not just a component. It is there because it is there, not because it has content.

**His mental model of the app: a well-organized workspace you return to.**

sac's launch readiness brainstorm opens with: "Full audit of current UI state vs. what's needed to launch. Goal: cool + appealing without sacrificing usability and simplicity." The word "cool" is notable — sac cares about the emotional response to the interface, not just its efficiency. He later writes: "The risk isn't shipping too little — it's shipping a cluttered app that buries the magic." Clutter is the enemy, but the solution is organization, not omission.

His onboarding redesign (PR #67) reveals his philosophy of user guidance: "The core problem: the demo is the magic, but without a before and after, it reads as noise. Users need to feel the problem first (losing thoughts), then see the solution (Murmur capturing and organizing), then feel the payoff (here's what it captured from that one sentence)." sac designs experiences as narrative arcs — setup, demonstration, resolution. This is progressive disclosure thinking applied to the first-time experience.

His process doc says: "Design-first. Iterates visually in the simulator before committing to anything." And: "Writes brainstorm docs before big features." He builds by seeing, adjusting, seeing again. The simulator is his canvas. dam builds by modeling data flow; sac builds by looking at pixels.

**Interaction style: progressive engagement with explicit control.**

sac wants to be in the driver's seat of his attention. Collapsible sections are not about hiding information — they are about the user choosing their focus. The focus strip surfaces what is urgent; the user then explores at their own pace. This is a pull model: the app presents, the user navigates.

His attention to haptics, toasts, and undo (PR #57: "status-change feedback with haptics, toasts, and undo delete") shows he cares about interaction closure. Every action should have a perceivable response. Where dam wants the animation itself to be the feedback, sac wants explicit confirmation — a toast, a haptic, an undo button. These are handshakes: "I did this." / "Yes, it happened."

His focus card reason coloring (PR #88) is another example: "String-matching LLM output (like `reason == 'Overdue'`) is fragile. Used actual `entry.dueDate` math instead." sac distrusts LLM-generated display data — he wants the UI to derive its visual state from ground truth, not from what the AI decided to label something. This is a telling contrast with dam, who wants the AI to control even the emphasis level and badge text.

**Summary: sac trusts his own eyes over computation.** He wants the app to present organized information and let him navigate it. The AI can help surface priorities, but the user — not the AI — decides what to look at and when to look away.

---

## 2. The Core Tension

The fundamental split is not about collapsible sections versus flat layout. It is about **who governs attention**.

### Locus of attention control

**Dam: the AI governs attention.** The app should show you what matters and hide everything else. If you need to scroll, something went wrong. If you need to tap a disclosure triangle, the AI failed to curate. The user's cognitive budget is spent only on perceiving — never on navigating, filtering, or organizing. The cost of this model: you must trust the AI. If it surfaces the wrong things or hides something important, you have no recourse except scrolling to an "all entries" escape hatch.

**Sac: the user governs attention.** The app should organize information into navigable regions and let the user direct their own focus. Collapsing a section is an act of agency: "I am done with this area." Expanding is curiosity: "Let me see what is here." The AI can suggest priorities (the focus strip), but it does not control visibility. The cost of this model: the user bears the cognitive load of navigation. With 50 entries across 7 categories, that is a lot of section headers and scroll distance.

### Named: the Scanner and the Navigator

- **dam is a Scanner.** He wants a single screen that he can sweep with his eyes, absorb, and dismiss. His ideal app experience is 3 seconds: open, scan, close. Anything that requires a second look or a tap is friction. The AI is the curator; the user is the audience.

- **sac is a Navigator.** He wants a structured space that he can move through, marking progress as he goes. His ideal app experience is 30 seconds: open, check focus strip, expand the category that matters, review entries, collapse it, maybe check another section, close. The AI is the compass; the user is the explorer.

### Supporting evidence for this framing

**dam's words:** "I want to see everything clear and concise and all in one view so that I don't have to click through toggles. I want everything on a single page. If it doesn't fit on the page then I don't want to see it."

This is pure Scanner. "Everything" means "everything that matters." The AI decides what matters. If it does not fit, it is not important enough. No scrolling, no expanding, no navigating.

**sac's words:** "I'm with you on making the cards smaller but I guess for me I'd like it to be collapsible to make it feel less cluttered. Like for instance, if I looked through my todos, then moved on to looking at reminders I might want to collapse my todos to make the screen less cluttered."

This is pure Navigator. "Looked through" implies sequential review. "Moved on to" implies spatial traversal. "Collapse to make it less cluttered" implies active curation of the viewport.

### The trust asymmetry

dam trusts the AI to decide what is visible. His composable home brainstorm explicitly delegates layout, grouping, density, and emphasis to the LLM. The user's only recourse if the AI gets it wrong is to speak a correction ("show me my ideas") — which is itself an AI interaction.

sac trusts the AI to suggest priorities but not to control visibility. His focus strip is a curated suggestion ("look at these first"), but the category sections below are always there, always navigable, always under user control. The AI whispers; the user decides.

This is not a disagreement about whether AI is useful. Both agree the focus strip / daily focus is valuable. The disagreement is about scope: should the AI curate a highlight reel (sac's model) or compose the entire experience (dam's model)?

### Secondary tensions

| Dimension | Dam | Sac |
|-----------|-----|-----|
| **Card density** | Minimal chrome, borderless rows, flow chips for low-priority items | Cards with padding, category badges, visual breathing room |
| **Grouping logic** | By urgency/context (AI-chosen) | By category (fixed, user-known) |
| **Empty space** | Waste — if it is empty, the AI should not have left it | Signal — collapsed sections create intentional whitespace |
| **Animation purpose** | Feedback ("something happened") | Delight + orientation ("this appeared here") |
| **Information architecture** | Flat with emphasis gradients (hero > standard > compact) | Hierarchical with disclosure levels (focus > expanded > collapsed) |

---

## 3. Settings Toggle Framing

The toggle must let each user select the mode that matches their cognitive style without making either choice feel inferior. The labels need to describe an experience preference, not a technical implementation.

### Proposal A: "Home style"

**Setting name:** Home Style
**Options:**
- **Curated** — "AI composes your home screen. Shows only what matters right now."
- **Organized** — "Entries grouped by category. Collapse sections as you review them."

**Why this works:** "Curated" implies intelligence and selection; "Organized" implies structure and user control. Neither is pejorative. A user who likes curation is not lazy; a user who likes organization is not a control freak. Both are positive self-descriptions.

**Description text (under the picker):**
> Curated: The AI decides what to show and how to arrange it. Fewer items, no toggles. Glance and go.
> Organized: Categories you can expand and collapse. Everything is accessible. The AI highlights priorities at the top.

### Proposal B: "View"

**Setting name:** View
**Options:**
- **Focus** — "AI picks what matters. One screen, no scrolling."
- **Browse** — "All entries by category. Collapse what you've seen."

**Why this works:** "Focus" and "Browse" are verbs that describe the user's behavior, not the app's architecture. "I'm a Focus person" and "I'm a Browse person" both feel like natural self-identifications. This maps directly to the Scanner/Navigator split.

**Description text:**
> Focus: The AI composes a briefing. You see what's urgent, recent, or interesting — nothing else.
> Browse: Entries organized by type. Expand and collapse sections at your own pace. Focus strip highlights priorities.

### Proposal C: "Layout"

**Setting name:** Layout
**Options:**
- **Glanceable** — "See everything important at a glance."
- **Explorable** — "Navigate your entries by category."

**Why this works:** "Glanceable" emphasizes speed; "Explorable" emphasizes depth. Both are positive qualities. This framing maps to the 3-second vs 30-second interaction models.

**Description text:**
> Glanceable: AI-composed view. Urgent items up top, everything else condensed. No tapping to expand.
> Explorable: Category sections with expand/collapse. Focus strip surfaces priorities. Swipe through at your own speed.

### Recommendation

**Proposal B ("Focus" / "Browse")** is the strongest. It:
- Uses verbs, which feel like behaviors rather than judgments
- Is only one word per option (minimal cognitive load in the picker)
- Maps cleanly to the actual UX difference: one view you focus on, one view you browse through
- Scales if a third option emerges later (e.g., "Timeline" for a chronological view)
- Does not mention AI, which avoids making "Browse" feel like the non-AI option

The setting could live in Settings under an "Appearance" or "Home" subsection, or even surface during onboarding: "How do you like to check your entries?" with two illustrated options.

---

## 4. Design Implications

### For the Scanner (dam's "Focus" view)

| Dimension | Implication |
|-----------|-------------|
| **Card density** | Minimal. Borderless rows for standard emphasis. Flow chips (capsule pills) for compact entries. Hero cards only for 1-2 truly urgent items. No card chrome unless emphasis demands it. |
| **Section headers** | AI-generated titles ("Handle today", "Keep in mind", "Back burner"). Uppercase badge style. No collapse controls — sections are not interactive. |
| **Grouping** | By urgency/context, not category. "Things due today" mixes todos and reminders. "Ideas to revisit" might live next to "Stale habits." |
| **Scroll behavior** | Ideally no scrolling. 5-15 items total. If you scroll, you have left the "glance" zone and entered diminishing returns. An "All entries" escape hatch at the very bottom for the rare case. |
| **Number of items** | Strict cap. The AI shows 5-15. Everything else is hidden. The user trusts the AI to surface what matters. |
| **Animation** | Functional, not decorative. Entry arrivals use opacity + offset spring. Glow indicates "new." Stagger indicates "the agent is working." No staggered card reveals on app open (composition loads as a unit). |
| **Agent personality** | The layout IS the agent's voice. A section titled "Quiet morning" communicates calm. A hero card with an "Overdue" badge communicates urgency. Embedded messages ("All caught up. Nice work.") let the agent speak through the layout. |
| **Shimmer/loading** | "Composing your view..." — the app is thinking. Placeholder cards in section shapes hint at the structure to come. |

### For the Navigator (sac's "Browse" view)

| Dimension | Implication |
|-----------|-------------|
| **Card density** | Medium. Cards with `.cardStyle()` padding. Category badges with colored dots. Enough breathing room to distinguish entries without overwhelming. |
| **Section headers** | Category name (uppercase), item count badge, collapse/expand chevron. These are navigational elements — they must be tappable, persistent, and spatially stable. |
| **Grouping** | By category, fixed order. The user learns where things are: "Todos are always second, ideas are always fourth." Spatial memory reduces cognitive load over time. |
| **Scroll behavior** | Expected. Users scroll through categories they care about. Collapsing reviewed sections shortens the scroll distance. Bottom padding ensures the last section clears the floating mic. |
| **Number of items** | All active entries shown, grouped by category. The focus strip curates 3 highlights, but nothing is hidden. The user can always find any entry by scrolling to its category. |
| **Animation** | Orientation-supporting. Section expand/collapse uses `.smoothSlide`. Focus card stagger (250ms intervals) creates a "things appearing" rhythm. Arrival glow says "this is new to this section." Peek animation on collapsed sections says "something landed here." |
| **Agent personality** | Contained to the focus strip. The greeting + briefing message ("Good morning. Two things overdue, one due today.") is the agent's voice. Below the strip, the UI is purely structural — the agent whispers, then steps back. |
| **Shimmer/loading** | "Thinking about your day..." with skeleton cards. The focus strip loads; the category sections are always there (no loading state for the structural layout). |

### Shared across both views

Both views share:
- Colored category dots (user explicitly wants these — CANON candidate)
- SwipeableCard gesture system (right = complete/archive, left = snooze)
- Entry detail view on tap
- Bottom nav bar (mic + keyboard)
- Recording UI (wave line, transcript, edge glow)
- Agent pipeline (SSE streaming, tool execution, memory)
- Credit system and settings

The toggle only affects the home screen layout. Everything below the home view (detail views, recording, settings) is identical.

---

## 5. What This Means for the Toggle Implementation

The toggle is not "dam's code vs sac's code" — both implementations already exist as `DamHomeView` and `SacHomeView`. The toggle is a preference stored in `@AppStorage` (or UserDefaults) that controls which view `RootView` renders.

The deeper question is whether the toggle should be:
1. **A settings preference** (buried in settings, set once, rarely changed)
2. **An onboarding question** (asked during first launch, changeable in settings)
3. **A home screen gesture** (swipe between views, like iOS weather app's list/detail toggle)

Given the psychological profiles, option 2 is likely best. Both dam and sac have strong preferences they would set once and leave. Neither wants to toggle frequently. But a new user does not know their preference until they have used the app — so the onboarding question should come after a few days of use, not on first launch.

A lightweight approach: default to "Browse" (sac's view, which is more conventional and legible to new users), and surface a "Try Focus view" prompt after 7 days of use or 20+ entries, when the user has enough data to make the AI composition meaningful and enough experience to know their preference.
