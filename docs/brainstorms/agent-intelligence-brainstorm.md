---
date: 2026-02-28
topic: agent-intelligence
---

# Agent Intelligence

How to make Murmur's agent more powerful while requiring minimal user input. The core question: what would it take for the agent to feel like it *knows you* after a week of use?

## Where We Are Today

The agent is a **stateless extraction engine**. Each voice input gets:
- Transcribed (on-device, Apple Speech)
- Sent to Claude Sonnet via PPQ.ai with the current entry list as context
- Returned as typed actions: create, update, complete, archive

**What the agent knows per call:** current date/time, the transcript, and a compact snapshot of active/snoozed entries. That's it. No memory of past sessions, no user profile, no learned patterns. The `AgentContext` model exists in the spec (`userPatternsJSON`, `widgetLayoutJSON`) but isn't implemented.

Multi-turn conversation is wired in MurmurCore but not exposed in the app UI. Every recording starts a fresh `LLMConversation`.

---

## 1. Memory

*How should the agent remember user patterns across sessions?*

### The Problem

Today the agent sees current entries but has no memory of *how* you use the app. It doesn't know:
- You always capture groceries on Sunday
- You tend to create high-priority todos in the morning
- You've mentioned "the dentist" five times this month
- You completed 12 todos last week but archived 8 ideas without acting on them

### Simplest Version: Entry History Summary

**Mechanism:** On each agent call, include a compact "memory block" in the system prompt — a pre-computed summary of the user's recent history.

```
## Your Memory
- User has created 47 entries over 3 weeks
- Most common categories: todo (18), reminder (12), idea (9)
- Completion rate: 72% of todos completed, 30% of ideas acted on
- Recurring topics: "gym", "grocery", "project falcon"
- Recent pattern: 3 entries/day average, mostly mornings
- Last session: 2 todos created, 1 reminder completed
```

**Implementation:** A background job (or computed on app launch) queries SwiftData for aggregate stats and writes them to the `AgentContext` model's `userPatternsJSON`. The pipeline injects this block into the system prompt before the first user message.

**Why this works:** It's read-only context — no new model, no embeddings, no vector store. The LLM is already good at using structured context. The agent immediately becomes better at categorization ("the user creates a lot of reminders, this ambiguous input is probably a reminder") and priority ("the user's todos are usually P2-P3, not P1").

**Cost:** ~50-100 extra input tokens per call. Trivial.

### Stretch Goal: Episodic Memory with Decay

Each session produces a brief "episode" — a 1-2 sentence summary of what happened. Episodes are stored chronologically and decay (oldest drop off after N sessions or M days). The agent sees the last ~10 episodes plus the aggregate summary.

```
## Recent Sessions
- Feb 28 AM: Created 3 todos for project falcon, completed gym reminder
- Feb 27 PM: Grocery list (12 items), archived old dentist reminder
- Feb 27 AM: 2 ideas about app redesign, snoozed tax todo to March 1
```

This gives the agent temporal narrative — not just what exists, but the *trajectory* of the user's thinking.

---

## 2. Preferences

*How does the agent learn what the user cares about without asking?*

### The Problem

The agent makes the same assumptions for every user:
- Default priority assignment is generic
- Category selection is purely content-based
- Summary style is uniform
- No awareness of what the user considers important vs noise

### Simplest Version: Implicit Preference Signals

**Mechanism:** Track user behavior as implicit feedback and surface patterns to the agent.

Signals already available in the data:
- **Completion speed** — Todos completed within hours = high-urgency user. Completed after days = relaxed.
- **Category distribution** — If 80% of entries are todos, the user is task-oriented. If 60% are ideas/thoughts, they're a thinker.
- **Edit patterns** — When users edit entries on the confirm screen, they're correcting the agent. Track what gets corrected.
- **Snooze patterns** — Frequent snoozing = the agent is surfacing things at the wrong time.
- **Archive without action** — Ideas that get archived without completion = the user captures broadly but acts narrowly.

**Implementation:** Add a `preferences` section to the memory block:

```
## Learned Preferences
- Priority tendency: conservative (user rarely creates P1, averages P3)
- Summary style: user edits summaries to be shorter (avg edit removes 3 words)
- Category corrections: user changed 3 "note" → "todo" entries (bias toward action)
- Completion pattern: fast on reminders (avg 2h), slow on ideas (avg 5d)
```

**Why this works:** No explicit preference UI. The agent adapts by observing behavior. A user who always edits summaries shorter gets shorter summaries. A user who recategorizes notes as todos gets more aggressive todo classification.

**Cost:** Background computation only — no extra LLM calls. The memory block grows by ~50 tokens.

### Stretch Goal: Active Preference Learning

The agent occasionally asks micro-questions via its text response: "I noticed you tend to create P3 todos. Should I default to P3 for tasks unless urgency is explicit?" The user's answer gets stored in preferences. But this must be rare and high-signal — one question per week max, never during a rapid-fire capture session.

---

## 3. Proactive Behavior

*What can the agent do without being asked?*

### The Problem

Today the agent is purely reactive — it waits for voice input and processes it. Between sessions, it does nothing. The existing spec describes focus cards (Level 1+) and home recomposition (Level 2+), but neither is implemented.

### Simplest Version: Session Summary on App Open

**Mechanism:** When the user opens the app, show a brief AI-generated summary card at the top of the entry list. Not a focus card that blocks the UI — just a contextual header.

```
"3 todos due today. You completed 5 items yesterday.
'Project Falcon deadline' is in 2 days."
```

**Implementation:** On `scenePhase == .active`, query entries for:
- Due today / overdue
- Completed since last open
- Approaching deadlines (next 48h)
- Snoozed entries whose snooze expired

Format locally (no LLM call needed for simple summaries). Show as a dismissible card.

**Why this works:** It transforms the app from "a place I put things" to "a place that tells me what matters." Zero user effort. The information is already in SwiftData — we're just surfacing it.

**Cost:** Zero tokens. Pure local computation.

### Stretch: Agent-Initiated Observations

The agent notices patterns and surfaces them as focus cards:
- "You've mentioned 'gym' in 4 entries this month but haven't completed any gym todos. Want me to consolidate these?"
- "You created 3 similar grocery lists this month. Want a recurring one?"
- "Your 'Project Falcon' entries span todos, ideas, and reminders. Want a project view?"

This requires an occasional background LLM call (the "home recomposition" budget from the spec: 100-300 tokens). The agent analyzes recent entries, looks for clusters and patterns, and generates observation cards.

**Key constraint:** Proactive behavior must feel helpful, not noisy. Max 1 observation per day. Dismissing an observation suppresses similar ones.

---

## 4. Context Enrichment

*What additional context makes extractions better?*

### The Problem

The agent receives: transcript + current entries + current date/time. It doesn't know:
- What time zone the user is in
- Whether "tomorrow" means a workday or weekend
- That the user just created 3 entries in a row (batch capture session)
- That it's Monday morning (weekly planning time?) or Friday evening (weekend prep?)

### Simplest Version: Temporal Context Block

**Mechanism:** Expand the date/time header in the system prompt with richer temporal context:

```
Current: Friday, February 28, 2026 at 3:42 PM PST
Day context: end of work week, afternoon
This session: 2nd recording in 5 minutes (batch capture)
Recent activity: 3 entries created today, last session 2 hours ago
```

**Implementation:** Computed locally from system clock + SwiftData queries. No new APIs needed.

**Why this matters:** "Pick up groceries" on a Saturday gets tagged as a weekend errand. On a Tuesday morning it might be more urgent (lunch prep?). "Call mom" on a Sunday afternoon is different from "Call mom" on a Wednesday. The agent can use temporal context for better priority and due-date inference.

**Cost:** ~20 extra input tokens. Zero API calls.

### Stretch: Location + Calendar

With user permission:
- **Location:** "User is at home" vs "User is at work" vs "User is at grocery store" — captured entries get location-aware categorization. Speaking "need milk" at a grocery store → immediate list item. At home → add to grocery list for next trip.
- **Calendar:** "User has a meeting in 30 minutes" — the agent can infer that "prepare the deck" is urgent. Or "dentist at 3pm tomorrow" cross-references with an existing reminder.

These require permission prompts and API integration (CoreLocation, EventKit). High value but high implementation cost. Could be Level 4+ features.

---

## 5. Conversation Quality

*How should multi-turn interactions work?*

### The Problem

Multi-turn is wired in MurmurCore but not in the UI. Every recording is a fresh context. The user can't say "actually make that one high priority" or "add eggs to the list I just made" without the agent treating it as a brand new input.

The agent already handles some of this via the existing entries context — if you say "mark the dentist thing as done," it can match against active entries. But true conversation requires maintaining the thread.

### Simplest Version: Session Continuity

**Mechanism:** Keep the `LLMConversation` alive for a time window (e.g., 5 minutes of inactivity). Within the window, each new recording is a follow-up turn in the same conversation.

User flow:
1. "Add milk, eggs, and bread to my grocery list" → creates list entry
2. (30 seconds later) "Oh and butter" → appends to the list just created
3. (2 minutes later) "Actually make the eggs a dozen" → updates the specific item

**Implementation:** `Pipeline.currentConversation` already exists and accumulates history. The change is in the app layer: don't pass `conversation: nil` — pass the existing one if within the time window. Reset on:
- 5 minutes of inactivity
- App backgrounding
- User explicitly starting "a new thought" (long press mic?)

**Why this works:** The LLM already handles multi-turn well via the conversation history. The scenario tests prove it works. We just need to wire the UI.

**Cost:** Subsequent turns in a conversation are cheaper — the system prompt and entry context are already in the conversation. Only the new transcript is added as input tokens. But the full history grows the context window over time, so sessions should be time-bounded.

### Stretch: Agent-Initiated Clarification

When the transcript is ambiguous, the agent responds with text instead of actions:

```
Transcript: "Schedule the thing for next week"
Agent: "I see 3 entries that could be 'the thing':
'Review design system', 'Dentist appointment', 'Team standup'.
Which one should I schedule?"
```

The agent already has this capability — tool choice is `.auto`, so it can return text content without tool calls. The UI would need to display the agent's text response and accept a voice/text follow-up.

**When to clarify vs just act:** The agent should act when confidence is high and clarify when:
- Multiple entries match a vague reference ("that one", "the thing")
- The requested action seems destructive (archiving/completing multiple items)
- A date/time reference is genuinely ambiguous ("next Friday" when today is Thursday — tomorrow or next week?)

Clarification should be the exception. The default is to act on best guess — users chose a voice app because they want low friction. Asking too many questions defeats the purpose.

---

## Cross-Cutting: What Ties These Together

All five dimensions feed into the same mechanism: **the system prompt gets richer with zero user effort.**

```
[System prompt structure with intelligence layers]

Current date/time + temporal context        ← Context Enrichment
User memory block (stats + episodes)        ← Memory
Learned preferences                         ← Preferences
Proactive observations queue                ← Proactive Behavior

[Entry manager instructions]

[Current entries compact list]

[User transcript]
```

The agent doesn't need new capabilities — it needs better *context*. Claude is already good at using structured context to make decisions. The intelligence comes from what we put in the prompt, not from changing how the prompt works.

### Token Budget

Today a typical call is 300-700 tokens total. Adding all "simplest version" context:
- Memory block: ~100 tokens
- Preferences: ~50 tokens
- Temporal context: ~20 tokens
- Proactive observations: ~30 tokens

Total overhead: ~200 tokens. A typical call goes from ~500 to ~700 tokens. Well within budget.

---

## Implementation Priority

Ordered by value-per-effort:

1. **Session continuity** (Conversation Quality, simplest) — wire existing multi-turn infrastructure to the UI. Highest impact, lowest effort. The code exists.

2. **Temporal context block** (Context Enrichment, simplest) — expand the date/time header. 20 minutes of work, immediate improvement in date/priority inference.

3. **Session summary card** (Proactive Behavior, simplest) — local computation, no LLM calls. Makes the app feel alive on open.

4. **Entry history summary** (Memory, simplest) — background computation + inject into prompt. The agent starts "knowing" you.

5. **Implicit preference signals** (Preferences, simplest) — track corrections and behavior patterns. Feeds into memory block.

6. **Agent-initiated clarification** (Conversation Quality, stretch) — display agent text responses in the UI. Enables disambiguation.

7. **Episodic memory** (Memory, stretch) — session summaries with decay. Richer temporal narrative.

8. **Agent-initiated observations** (Proactive, stretch) — background LLM analysis. The "your agent noticed something" cards.

9. **Location + Calendar** (Context Enrichment, stretch) — high value but high integration cost. Level 4+ feature.

10. **Active preference learning** (Preferences, stretch) — micro-questions. Nice but risks annoying users.

---

## Open Questions

- **Memory persistence format:** JSON blob in `AgentContext` (spec model) vs structured SwiftData fields? JSON is flexible but harder to query. Structured fields are queryable but rigid.
- **Token budget ceiling:** At what point does the enriched prompt become too expensive? Need to establish a max context size (e.g., 2000 input tokens) and prioritize what gets included.
- **Privacy implications of memory:** The memory block contains behavioral patterns. Should it be encrypted like entry content? Probably yes — it's metadata about user behavior.
- **Conversation lifecycle edge cases:** What if the user records something unrelated mid-session? ("Buy groceries" then 2 minutes later "I had a dream about flying.") Should the conversation reset on topic shift?
- **Proactive behavior opt-out:** Some users want a dumb tool, not a smart assistant. Should proactive features be a toggle, or does the progressive unlock system handle this naturally (Level 3+ only)?

## Next Steps

This brainstorm covers WHAT intelligence to add. The next step is to pick a subset and plan HOW to implement it.

Recommended first batch: items 1-5 from the priority list. They form a coherent "agent context layer" that can ship together — session continuity, temporal context, session summary card, entry history, and implicit preferences. All are local-computation-heavy with minimal new LLM cost.
