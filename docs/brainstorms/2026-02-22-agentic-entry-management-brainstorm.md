---
date: 2026-02-22
topic: agentic-entry-management
---

# Agentic Entry Management

## What We're Building

Transform Murmur from a voice capture tool into a personal agent. The mic becomes your interface to an assistant that knows everything you've captured and can act on it. The UI collapses from a complex multi-screen app into three elements: a smart list, gestures, and a mic.

Today: "Pick up groceries" creates a new todo every time. You manually swipe, edit, organize.
After: "I got the groceries, and move the dentist to Friday" — the agent completes one entry, updates another. You glance at the smart list, swipe to check things off, speak for anything complex.

## Why This Approach

The current system is stateless — the LLM sees only the transcript and extracts new entries. The UI compensates with progressive disclosure, swipe actions, detail editors, category filters. That's backwards. If the agent is smart enough, the UI can be dumb.

By giving the agent awareness of all entries and the ability to take multiple action types, we can radically simplify the interface. The intelligence moves from the UI layer into the agent layer.

## Design

### The Three-Layer Interface

The entire app collapses to three interaction layers:

#### 1. The Smart List (Glance)

A single scrollable list of active entries, curated by the agent. No tabs, no categories, no manual sorting.

**Daily Brief** — a 1-line agent-generated summary pinned at the top:
> "3 due today, 1 overdue, 2 new ideas this week"

Below it, entries ordered by relevance: overdue first, then due today, then by priority, then by recency. The agent decides the ordering — the user never sorts or filters manually.

**v1: Locally computed.** Count due/overdue/categories, format a string. No LLM needed.
**Future: LLM-generated.** "You've been putting off 'call dentist' for 3 days" — actual intelligence in the brief. Cached, regenerated periodically.

#### 2. Gestures (Act Fast)

Two gestures for the two most common single-entry actions:

| Gesture | Action | Feel |
|---------|--------|------|
| **Swipe right** | Complete | Satisfying vanish — shrink + fade, list reflows, gone |
| **Swipe left** | Snooze (1hr default) | Slides away, comes back later |

**Tap** expands an entry inline to show full content (read-only, no editor).

That's it. No menus, no buttons, no long-press options. Two swipes and a tap.

**Completion animation:** Item shrinks + fades, list reflows smoothly. Brief updates. The app always looks clean because the agent manages the mess.

#### 3. The Mic (Do Anything)

Everything beyond glance and swipe goes through voice:

- Create new entries ("remind me to call mom tomorrow")
- Update existing ("move the dentist to Friday")
- Complete by reference ("I finished the grocery run")
- Multi-entry operations ("reschedule everything from today to Monday")
- Complex commands ("archive all my old ideas")

The mic is the escape hatch for any operation. If you can say it, the agent can do it.

### Agent Response: The Toast, Not the Confirmation Screen

The current card-by-card confirmation flow is replaced with a **response toast**:

```
"Got it — completed 'grocery run', moved dentist to Friday, added 'book flights'"
```

- Appears at top after agent processes voice input
- Auto-dismisses after 3 seconds
- Tap to expand into a detailed action list (if you want to undo something)
- Undo button on the toast for quick reversal

**Why no confirmation screen:** The "trust the agent" philosophy. The agent acts, tells you what it did, and you can undo. Same pattern as Gmail's "Conversation archived — Undo." Fast, non-blocking, reversible.

**Undo mechanics:**
- Each agent response is a single undoable transaction
- Tap "Undo" on toast → all actions in that response are reversed
- Creates/updates/completes all roll back atomically
- Undo window: 10 seconds (toast visible) + accessible in a recent activity log

### Agent Architecture

#### Core Concept: Agent Loop with Tools

The mic is the user's interface to an agent. The agent:
1. Receives the user's voice input (transcript)
2. Sees all active entries as context
3. Decides what actions to take
4. Returns a list of typed actions via tool call
5. App executes immediately, shows toast summary

#### Context Injection

Every LLM call includes a snapshot of the user's active entries.

**What's included:**
- All entries where `status == .active` or `status == .snoozed`
- Compact format: short id, summary, category, priority, due date, cadence, status
- Sorted by: priority (highest first), then created date (newest first)

**Format (token-efficient structured text):**
```
## Your Current Entries

- [abc123] TODO P1 "Call the dentist" due:2026-02-24
- [def456] REMINDER P2 "Book flights to NYC" due:2026-03-01
- [ghi789] HABIT "Morning run" cadence:weekdays
- [jkl012] IDEA "App for dog walkers"
- [mno345] NOTE "Meeting notes from Thursday"
```

**Scaling strategy:**
- v1: All active entries, short IDs (first 6 chars of UUID), resolve client-side
- v2: Relevance-scored subset (embed transcript, rank entries by similarity)
- v3: Summary of older entries + full detail for recent/relevant

#### Tool Design: Four Focused Tools

Multiple tools, each a clear verb. The LLM calls whichever ones it needs (Claude supports parallel tool calls). Each tool is batch-capable.

**`create_entries`** — new things to track
```json
{
  "name": "create_entries",
  "parameters": {
    "entries": [
      {
        "content": "Book flights to NYC",
        "category": "todo",
        "summary": "Book NYC flights",
        "priority": 2,
        "due_date": "next Friday",
        "source_text": "remind me to book flights to new york next friday"
      }
    ]
  }
}
```

**`update_entries`** — modify existing entries (including snooze via status + snooze_until fields)
```json
{
  "name": "update_entries",
  "parameters": {
    "updates": [
      {
        "id": "abc123",
        "fields": {
          "due_date": "Friday",
          "priority": 1
        },
        "reason": "User asked to move dentist appointment to Friday"
      },
      {
        "id": "def456",
        "fields": {
          "status": "snoozed",
          "snooze_until": "Thursday 9am"
        },
        "reason": "User wants to defer this until Thursday"
      }
    ]
  }
}
```

**`complete_entries`** — mark things done
```json
{
  "name": "complete_entries",
  "parameters": {
    "entries": [
      { "id": "abc123", "reason": "User said they finished grocery shopping" },
      { "id": "def456", "reason": "User said laundry is done" }
    ]
  }
}
```

**`archive_entries`** — no longer relevant
```json
{
  "name": "archive_entries",
  "parameters": {
    "entries": [
      { "id": "ghi789", "reason": "User said this is no longer relevant" }
    ]
  }
}
```

**Why four tools, not one:**
- Each tool is a clear verb with a tight schema — less ambiguity for the LLM
- Claude can call multiple tools in parallel: "finished groceries, add milk, move dentist" = `complete_entries` + `create_entries` + `update_entries` in one response
- Adding new capabilities = adding new tools, not bloating one schema
- Snooze is just an `update_entries` call (status + snooze_until fields), no 5th tool needed

**Future tools (when needed):**
| Tool | What it does |
|------|-------------|
| `merge_entries` | Combine duplicate entries |
| `split_entries` | Break a list entry into individual items |
| `respond` | Answer a user question (text/TTS) |
| `get_entries` | Query/filter entries (when context window isn't enough) |

**`reason` field:** Every non-create tool includes a `reason` string per entry. Powers the toast summary and future audit log.

**Notifications are automatic:** The existing `Entry.perform()` layer already handles notification sync/cancel as a side effect of status changes. The agent tools don't need any notification awareness — they mutate entry state, notifications follow.

#### System Prompt: Personal Entry Manager

The system prompt shifts from "extraction assistant" to "personal entry manager":

**Key behavioral rules:**
- When the user mentions something matching an existing entry, prefer updating/completing over creating a duplicate
- Fuzzy matching: "get groceries" matches "pick up groceries"
- If the user says something is done/finished/completed, complete the matching entry
- If the user gives new details about an existing entry, update it
- Only create when there's genuinely new intent
- When in doubt, lean toward creating (user can merge later)
- Always include `reason` for update/complete/archive actions
- Understand time-relative language ("move it to tomorrow", "push that back a week")
- Understand pronoun references ("finish that", "update the first one")

#### Extensible Agent Protocol

```swift
// The agent's available actions — extend for new capabilities
enum AgentAction: Codable {
    case create(CreateAction)
    case update(UpdateAction)
    case complete(CompleteAction)
    case archive(ArchiveAction)
    // Future:
    // case respond(RespondAction)
    // case query(QueryAction)
    // case snooze(SnoozeAction)
}

// The agent's response to any user input
struct AgentResponse {
    let actions: [AgentAction]
    let summary: String              // human-readable toast text
    let conversation: LLMConversation // for multi-turn
}

// Protocol for the agent — swappable implementations
protocol MurmurAgent {
    func process(
        transcript: String,
        existingEntries: [Entry],
        conversation: LLMConversation?
    ) async throws -> AgentResponse
}
```

Adding new capabilities = new action type + UI treatment. No rewrites.

#### Data Flow

```
1. User taps mic, speaks
2. AppleSpeechTranscriber → transcript
3. Fetch all active entries from SwiftData
4. Build context: system prompt + entry snapshot + transcript
5. Call LLM with manage_entries tool
6. Parse AgentResponse (typed actions + summary)
7. Execute all actions immediately:
   - create → insert new Entry
   - update → modify existing Entry fields
   - complete → entry.perform(.complete) → vanish animation
   - archive → entry.perform(.archive) → vanish animation
8. Show response toast with summary
9. Sync notifications
10. Update daily brief
```

#### Multi-Turn Refinement

After the agent acts and shows the toast, the user can tap the mic again:

- "Actually don't complete the groceries one"
- "Make that dentist appointment P1"

The agent sees the full conversation context + current entry state → returns corrective actions. Undo the previous complete, apply the new update.

### What Gets Removed

The radical simplification means removing significant UI:

| Current Feature | Replacement |
|-----------------|-------------|
| Progressive disclosure (L0-L4) | Single smart list, always |
| Category tabs/filters | Agent-curated ordering |
| Swipe action menus (5+ options) | Two gestures: right=complete, left=snooze |
| Detail editor view | Tap to expand (read-only) + mic to edit |
| Card-by-card confirmation | Response toast |
| Text input mode | Mic only (for now) |
| Archive view | Archived items just gone (future: "show me my archive" via mic) |
| Settings for disclosure level | Removed — no disclosure levels |

### What Gets Kept

- SwiftData persistence (unchanged)
- NotificationService (unchanged, still syncs on actions)
- Credit system (unchanged, still charges per LLM call)
- AppleSpeechTranscriber (unchanged)
- Multi-turn LLMConversation (enhanced with entry context)

## Key Decisions

- **Three-layer interface (list + gestures + mic):** Radically simpler than current multi-screen UI. Intelligence in the agent, simplicity in the UI.
- **Daily brief at top:** Makes the app feel managed. Locally computed v1, LLM-generated future.
- **Response toast over confirmation screen:** Trust the agent, show what happened, undo if wrong. Non-blocking.
- **Satisfying vanish on complete:** No lingering checked-off items. The list is always clean.
- **Four focused tools over one mega-tool:** `create_entries`, `update_entries`, `complete_entries`, `archive_entries`. Clear verbs, tight schemas, parallel-callable. Snooze handled via `update_entries` (status + snooze_until).
- **Trust the agent (no mandatory confirmation):** Act first, undo if wrong. Gmail pattern.
- **Notifications are automatic:** Agent mutates entry state, existing `Entry.perform()` handles notification sync/cancel as side effect. No notification logic in agent layer.
- **All active entries in context (v1):** Simple, sufficient for <200 entries.
- **`reason` field on mutations:** Powers toast summaries and trust.
- **Protocol-based architecture:** New capabilities are additive.

## Open Questions

- **Token budget:** How many active entries before we truncate? Measure typical sizes, set threshold.
- **Short IDs:** Use first 6 chars of UUID in LLM context, resolve client-side. Saves tokens.
- **Offline mode:** Could a local model handle simple actions (complete, snooze) while cloud handles complex ones?
- **Text input:** Removed for now. Add back as a keyboard icon on the mic button for quiet environments?
- **Empty state:** What does the app look like with zero entries? Just the mic + a prompt?
- **Undo log:** How long to keep action history? Just last action, or a scrollable recent activity?

## Next Steps

-> `/workflows:plan` for implementation — likely phases:
1. Agent protocol + manage_entries tool (replace extract_entries)
2. Context injection (feed active entries to LLM)
3. System prompt rewrite (extraction assistant → entry manager)
4. Action execution layer (update/complete/archive in pipeline)
5. UI simplification (smart list + gestures + toast, remove old screens)
6. Daily brief (locally computed v1)
