# Murmur User Stories

**Date:** 2026-03-14 (refreshed from 2026-03-03 original)
**Branch:** `dam` (includes merged work from `sac` through PR #97)
**Scope:** Complete user story analysis covering all implemented flows, gaps, and edge cases. Updated to reflect unified composition system, three home view variants, calendar, inline editing, and layout diff tools.

---

## 1. Onboarding Stories (First Launch to First Entry)

### 1.1 Welcome Screen

**As a** new user **I want to** understand what Murmur does in one glance **so that** I feel confident opening the app.

**Given** I launch Murmur for the first time
**When** the app opens
**Then** I see a launch screen (storyboard with mic icon and "murmur" label on dark background), followed by a welcome screen with headline "Stop losing your thoughts.", a pulsing mic icon, explanatory body text, a "See how it works" CTA button, and a "Skip" link in the top-right corner.

> **Note:** Launch screen was added (resolves prior gap #10). May need visual polish pass on real device to match current design language — flagged on TestFlight checklist item #1.

### 1.2 Guided Demo Walkthrough

**As a** new user **I want to** see a simulated voice capture demo **so that** I understand the core loop before using the mic.

**Given** I'm on the welcome screen
**When** I tap "See how it works"
**Then** I see a transcript animation playing the demo text ("Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"), followed by a brief processing screen (~1.5s), then a result view showing 3 pre-built entries (reminder, todo, idea) with a "Save & Continue" button.

> **Gap:** Onboarding demo entries may not match current card style after recent card redesign (borderless rows, flow chips). Flagged as TestFlight checklist item #10 — needs cold-launch verification.

### 1.3 Save Demo Entries

**As a** new user **I want to** keep the demo entries **so that** I start with a populated home screen and immediately understand the card structure.

**Given** I'm on the onboarding result screen
**When** I tap "Save & Continue"
**Then** 3 demo entries are saved to SwiftData, `hasCompletedOnboarding` is set to true, onboarding overlay dismisses, a brief "Swipe to act / Tap to edit" hint appears at the bottom for 4 seconds, and I see the home screen with my new entries.

### 1.4 Skip Onboarding

**As a** returning user or impatient user **I want to** skip onboarding entirely **so that** I go straight to using the app.

**Given** I'm on the onboarding welcome screen
**When** I tap "Skip"
**Then** `hasCompletedOnboarding` is set to true, no demo entries are saved, I see the empty home state.

### 1.5 Post-Onboarding Card Hints

**As a** new user who just completed onboarding **I want to** learn gesture interactions **so that** I know I can swipe and tap on cards.

**Given** I just completed onboarding and am on the home screen
**When** the onboarding overlay dismisses (~600ms delay)
**Then** a capsule hint appears at the bottom showing "Swipe to act" and "Tap to edit" icons, auto-dismisses after 4 seconds or on tap.

> **Gap:** No explicit microphone permission prompt during onboarding. Permission is requested on first recording attempt, which could feel abrupt.

> **Gap:** No explanation of the credit system during onboarding. User discovers credits only in Settings or when they run out.

---

## 2. Core Loop Stories (Daily Usage, Recording, Creating Entries)

### 2.1 Voice Capture — Start Recording

**As a** user **I want to** start recording by tapping the mic **so that** I can capture thoughts hands-free.

**Given** I'm on the home screen (empty or populated) and in idle state
**When** I tap the mic button in the bottom nav bar
**Then** the app transitions to recording state: the mic icon changes to a stop square, a reactive sine wave visualization appears at the bottom edge (dual-layer harmonics — primary 80% + secondary 20%, amplitude 6pt idle to 70pt peak, speed 0.8–3 cycles/sec scaling with loudness, line width 2–5pt breathing with audio), live transcript text appears above the stop button growing upward with a dark 6-stop fade gradient, and processing glow is not yet visible.

### 2.2 Voice Capture — Stop Recording and Process

**As a** user **I want to** stop recording and have my speech processed **so that** entries appear automatically.

**Given** I'm currently recording with visible transcript
**When** I tap the stop button (square icon)
**Then** recording stops, the final transcript is captured (preferring pipeline's version, falling back to the last streamed transcript), if the transcript is empty the app returns to idle with no processing, otherwise the state transitions to processing with a purple edge glow overlay (angular gradient with accentPurple + pink magenta, 1.6s rotation, 0.8–1.0 opacity pulse, 1.0–1.03 scale breathe), the transcript is sent to the agent pipeline for SSE streaming, and entries appear with staggered arrival animations.

### 2.3 Entry Arrival Animation

**As a** user **I want to** see entries appear one by one with a glow **so that** I have visual confirmation of what was captured.

**Given** the agent has processed my transcript and created entries
**When** tool call results arrive via SSE streaming
**Then** entries are inserted into SwiftData but initially hidden (`pendingRevealEntryIDs`), revealed one at a time with stagger delays (60ms in DamHomeView, 150ms elsewhere), each entry appears with a scale+opacity+offset transition, a category-colored glow fades out over 3.5 seconds (respects `accessibilityReduceMotion`), a success haptic fires, and a toast shows a summary ("Created 2 entries, Completed 1 entry").

### 2.4 Home Screen Organization (Three Variants)

**As a** user **I want to** see my entries organized meaningfully **so that** I can quickly find what matters.

The home screen has three variants, selectable in DevMode:

**Scanner (DamHomeView):**
- Urgency-grouped layout with hero/standard/compact emphasis levels
- Top bar: settings gear (right)
- Focus tab: AI-composed sections via `HomeComposition`, up to 7 items
- All tab: shared `AllEntriesView` with collapsible category sections

**Navigator (SacHomeView):**
- Category-grouped layout with briefing greeting
- Top bar: calendar (left) + settings gear (right)
- Focus tab: greeting + briefing text, category clusters with count badges and accent color dots
- All tab: shared `AllEntriesView`

**Zoned (ZonedFocusHomeView):**
- Three physical zones: Hero (bold card with colored accent stripe), Standard (compact list), Habits ("TODAY'S HABITS" strip filtered by cadence)
- Top bar: calendar (left) + settings gear (right)
- Focus tab: three-zone layout, up to 7 items, habits filtered by `appliesToday`
- All tab: shared `AllEntriesView`

All variants use `TabView(.page)` or equivalent for Focus/All tab switching.

### 2.5 Shared AllEntriesView (All Tab)

**As a** user **I want to** browse all my entries by category **so that** I can find anything regardless of AI curation.

**Given** I switch to the "All" tab on any home variant
**When** the tab renders
**Then** entries are grouped into collapsible sections in fixed order: todo, reminder, habit, idea, list, note, question. Each section shows a colored dot, uppercase category name, item count badge, and collapse/expand chevron. Empty categories are not shown. Within each category, entries sort by priority (ascending), then due date (ascending), then creation date (newest first). Inline processing dots show during LLM work.

### 2.6 Collapsed Section Peek on Arrival

**As a** user **I want to** see new entries even in collapsed sections **so that** I don't miss arrivals.

**Given** a category section is collapsed and a new entry arrives in that category
**When** the entry's arrival glow triggers
**Then** the section header pulses with the category color, a "+N" badge appears next to the count, the newest arrived entry peeks below the header for 3 seconds, tapping the peek expands the full section, the peek auto-retracts after 3 seconds if not interacted with.

### 2.7 Agent Status Toast

**As a** user **I want to** see a concise summary of what the agent did **so that** I have confirmation without reading every entry.

**Given** the agent has completed processing
**When** tool calls have been executed and the stream completes
**Then** if the agent returned text content with no actions, a bottom toast shows the agent's text response. If actions were applied, an action result thread item records the summary (e.g., "Created 2 entries, Updated 1 entry").

> **Gap:** The `agentStreamText` is cleared immediately after showing as a toast. If the user dismisses or misses it, there's no way to review what the agent said. The thread items are internal state — no UI exposes the full conversation thread to the user.

---

## 3. Management Stories (Editing, Completing, Archiving, Swiping, Undo)

### 3.1 Swipe Right to Complete (Todo/Reminder/Habit)

**As a** user **I want to** swipe right on a completable entry **so that** I can mark it done with one gesture.

**Given** I see a todo, reminder, or habit entry card
**When** I swipe right
**Then** a green "Done" action is revealed with a checkmark icon. On release, the entry is marked complete, a success haptic fires, and a "Completed" toast appears.

> **Note:** On the Focus tab (which uses `TabView(.page)`), swipe gestures on cards conflict with tab switching. Fix in progress: `SwipeableCard` uses `minimumDistance: .infinity` when no swipe actions exist so UIPageViewController handles horizontal swipes. Needs real-device verification (TestFlight checklist item #2).

### 3.2 Swipe Right to Archive (Non-completable)

**As a** user **I want to** swipe right on a note or idea **so that** I can archive it quickly.

**Given** I see a note, idea, list, or question entry card
**When** I swipe right
**Then** a blue "Archive" action is revealed with an archivebox icon. On release, the entry is archived and an "Archived" toast appears.

### 3.3 Swipe Left to Snooze

**As a** user **I want to** snooze an entry **so that** it disappears temporarily and reappears later.

**Given** I see any entry card
**When** I swipe left
**Then** a yellow "Snooze" action is revealed with a moon icon. On release, a confirmation dialog appears with options: "In 1 hour", "Tomorrow morning" (9:00 AM), "Next week", "Custom time...", or "Cancel".

### 3.4 Custom Snooze Time

**As a** user **I want to** pick a specific snooze date/time **so that** entries reappear exactly when I need them.

**Given** I've triggered a snooze and tapped "Custom time..."
**When** the custom snooze sheet appears
**Then** I see a graphical date picker for date and time (future dates only), a "Snooze" save button, and a "Cancel" button.

### 3.5 Snooze Wake-Up

**As a** user **I want** snoozed entries to automatically reappear **so that** I don't have to remember to check on them.

**Given** an entry is snoozed until a specific date/time
**When** the snooze time passes (checked on app foreground, on appear, and every 30 seconds via timer)
**Then** the entry's status changes from snoozed to active, `snoozeUntil` is cleared, the entry reappears in its category section, and notifications are re-synced.

### 3.6 Tap to View Entry Detail (Inline Editing)

**As a** user **I want to** tap an entry card **so that** I see the full content and can edit it in place.

**Given** I see an entry card on the home screen
**When** I tap the card
**Then** a detail sheet opens with inline editing — all fields are directly editable without a separate edit mode:
- Category pill selector (horizontal scroll, 7 categories)
- Summary TextEditor (min 72pt, grows vertically)
- Notes TextEditor (min 80pt, placeholder "Add a note...")
- Priority pills (None + 1–5, click to toggle)
- Due date row with calendar icon (todos/reminders only) — opens DueDateEditSheet
- Cadence picker pills: daily/weekdays/weekly/monthly (habits only)
- Habit streak display: current + best streak (when > 0)
- Metadata footer: created date, duration (MM:SS or "text")
- Bottom action bar: Archive/Unarchive, Snooze, Delete buttons

Changes auto-save on every keystroke via `onChange`. No separate save button needed.

> **Note:** This replaced the previous two-step flow (view detail → tap pencil → edit sheet). Stories 3.7 and 3.8 from the prior review are now collapsed into this single inline editing experience.

### 3.7 Set/Change Due Date

**As a** user **I want to** add or change a due date on a todo or reminder **so that** I get timely notifications.

**Given** I'm viewing a todo or reminder entry detail
**When** I tap the due date row ("Add due date" or the existing date)
**Then** a date edit sheet opens with a graphical calendar, optional time toggle, save/cancel buttons, and a "Remove Date" option if a date already exists.

### 3.8 Change Habit Cadence

**As a** user **I want to** set how often a habit repeats **so that** it shows up on the right days.

**Given** I'm viewing a habit entry detail
**When** I see the cadence picker (daily, weekdays, weekly, monthly pills)
**Then** I can tap a cadence pill to select it, tap again to deselect. The entry's cadence updates immediately (auto-saved).

### 3.9 Delete Entry with Undo

**As a** user **I want to** delete an entry with a grace period **so that** I can recover from accidental deletes.

**Given** I'm in entry detail view
**When** I tap the Delete button in the action bar
**Then** the detail sheet closes, a rigid haptic fires, a "Deleted" warning toast appears with an "Undo" button (visible for 4 seconds). If I tap Undo, the delete is cancelled. If I don't, the entry is permanently deleted after 4 seconds.

### 3.10 Archive and Unarchive

**As a** user **I want to** archive entries I no longer need **so that** my home screen stays clean.

**Given** I'm in entry detail view for an active entry
**When** I tap "Archive"
**Then** the entry moves to archived status, disappears from home, and can be found in Settings > Archive.

**Given** I'm in the archive view
**When** I tap the restore button on an archived entry
**Then** the entry returns to active status and reappears on the home screen.

> **Gap:** No bulk operations — user must archive/complete/delete entries one at a time. No "select multiple" mode.

> **Gap:** No search. With 30+ entries the All tab becomes unmanageable. Category sections help but don't replace search.

---

## 4. Agent Interaction Stories (Multi-turn, Memory, Layout Diffs, Text Input)

### 4.1 Text Input (Keyboard)

**As a** user **I want to** type instead of speak **so that** I can capture thoughts in quiet environments.

**Given** I'm on the home screen in idle state
**When** I tap the keyboard icon in the bottom nav bar (top-right of mic dome)
**Then** an inline text input capsule appears in the bottom nav bar (1–3 line multiline), auto-focused, with a send button that appears when non-empty, a clear (x) button inside the field, and `.send` submit label. The mic button hides during text input.

### 4.2 Agent Creates Entries from Text

**As a** user **I want to** type a message and have the agent process it **so that** text input works identically to voice.

**Given** I've typed "Buy groceries and call the dentist tomorrow"
**When** I tap the send button
**Then** the text input bar closes, the text is sent to the agent pipeline, processing indicators appear, and entries are created with the same stagger animation as voice input.

### 4.3 Agent Updates Existing Entries

**As a** user **I want to** say "change the priority on the dentist thing to urgent" **so that** the agent modifies existing entries rather than creating duplicates.

**Given** I have an entry "Call dentist about appointment"
**When** I record or type "make the dentist thing high priority"
**Then** the agent uses fuzzy semantic matching to identify the existing entry, calls `update_entries` with the matched ID and priority field, the entry updates in place with a glow animation, and a toast shows "Updated 1 entry".

### 4.4 Agent Completes Entries by Voice

**As a** user **I want to** say "I finished the grocery run" **so that** the agent marks the right entry done.

**Given** I have a todo "Pick up milk and eggs"
**When** I record "done with the groceries"
**Then** the agent uses `complete_entries` with the matched entry ID, the entry is marked complete, and a toast shows "Completed 1 entry".

### 4.5 Agent Archives Entries by Voice

**As a** user **I want to** say "the garden watering idea isn't worth pursuing" **so that** the agent archives it without me navigating to the detail view.

**Given** I have an idea entry about garden watering
**When** I record "forget about the garden watering idea"
**Then** the agent calls `archive_entries`, the entry is archived, and a toast confirms.

### 4.6 Agent Layout Diff (Surgical Home Updates)

**As a** user **I want** the agent to rearrange my home screen without regenerating everything **so that** changes are fast and targeted.

**Given** the agent needs to update the home view (e.g., after creating entries or on foreground refresh)
**When** the agent decides a partial update is sufficient
**Then** the agent calls `get_current_layout` to read the current `HomeComposition`, then calls `update_layout` with a batch of `LayoutOperation`s (7 types: addSection, removeSection, updateSection, insertEntry, removeEntry, moveEntry, updateEntry). The diff is applied via `HomeComposition.apply(operations:)`, returning a `LayoutDiff` that drives targeted animations. This is cheaper than full `compose_view` regeneration.

> **Note:** Layout diff (Phases 1–3) is complete. `compose_view` is preserved for cold start (no existing layout). Phase 4 (settings toggle for Focus/Browse preference) is deferred.

### 4.7 Agent Asks for Clarification (Confirm Actions)

**As a** user **I want** the agent to check with me when my intent is ambiguous **so that** it doesn't take the wrong action.

**Given** I have multiple entries that could match ("dentist" appears in two entries)
**When** I say "cancel the dentist thing"
**Then** the agent calls `confirm_actions` with a message explaining the ambiguity and proposed actions, the user sees a preview and can confirm or decline.

> **Gap:** The `confirm_actions` tool is defined in the schema but the UI flow for confirmation is not surfaced. No `pendingConfirmation` property on `ConversationState`. User cannot see or respond to proposed actions.

### 4.8 Multi-turn Conversation

**As a** user **I want to** have a back-and-forth conversation with the agent **so that** I can iteratively refine entries.

**Given** I just created an entry and want to modify it
**When** I immediately record another message without leaving the app
**Then** the conversation history is maintained in `LLMConversation` (truncated to last 20 messages), the agent has context of what it just did, tool results from previous turns are replaced with real execution outcomes via `replaceToolResults()`, and the agent can reference previous actions.

> **Gap:** Conversation resets on app termination — no disk persistence for multi-turn history. No UI indicator showing conversation context is active. No explicit "start fresh" mechanism. Variant switch does reset conversation (`AppState.resetConversation()` nils the lazy `_conversation`).

### 4.9 Agent Memory Persistence

**As a** user **I want** the agent to remember my preferences across sessions **so that** it gets better at understanding me over time.

**Given** I use Murmur regularly and the agent notices patterns
**When** the agent learns something new (e.g., "user always says 'gym' to mean 'workout habit'")
**Then** the agent calls `update_memory` with a structured summary (under 500 words), `AgentMemoryStore` writes to `Documents/agent-memory.json`, and the memory is loaded into the agent's context on next app launch.

> **Gap:** No UI for users to view, edit, or delete the agent's memory. The agent's knowledge about the user is invisible and uncontrollable.

### 4.10 Agent Text-Only Response

**As a** user **I want to** receive text feedback from the agent when no entries are created **so that** I know the agent understood me even when it doesn't take action.

**Given** I say something that doesn't warrant an entry (e.g., "how's my day looking?")
**When** the agent responds with text but no tool calls
**Then** the agent's `textResponse` is streamed via SSE `textDelta` events, and if no actions were applied, a bottom toast shows the text content.

### 4.11 Undo Agent Actions

**As a** user **I want to** undo the agent's last batch of changes **so that** I can recover from unwanted actions.

**Given** the agent just created/updated/completed/archived entries
**When** I review the action result
**Then** undo is available for the current generation only (not across multiple agent turns). The `UndoTransaction` reverses all applied actions. Once a new agent turn starts (generation counter increments), previous undo is invalidated.

> **Gap:** No UI surface for the undo action is visible on the home screen after agent processing. Undo from swipe-to-complete uses a toast with "Undo" action label, but agent pipeline undo lacks a corresponding UI trigger.

---

## 5. Home Composition Stories (AI-Curated Focus, Variants, Cache)

### 5.1 Home Composition Generation

**As a** user **I want to** see an AI-curated view when I open the app **so that** I know what to prioritize.

**Given** I open the app and have active entries
**When** the app appears
**Then** `requestHomeComposition(entries:variant:)` is called with the current variant (.scanner/.navigator), the LLM evaluates entries and returns a `HomeComposition` with composed sections, items (up to 7), and optional briefing text. Deterministic fallbacks exist if the LLM is unavailable: scanner groups by attention + recency, navigator groups by category with generated briefing.

### 5.2 Scanner Focus Tab (DamHomeView)

**Given** home composition has been generated for the scanner variant
**When** DamHomeView's Focus tab renders
**Then** composed sections display with urgency-based grouping. Entries show hero/standard/compact emphasis. Sections render as flow (compact density) or vertical (relaxed density) layouts. Staggered 60ms reveals on cold start with spring(response: 0.4, dampingFraction: 0.8) animations. `matchedGeometryEffect` used for entry moves during layout diffs.

### 5.3 Navigator Focus Tab (SacHomeView)

**Given** home composition has been generated for the navigator variant
**When** SacHomeView's Focus tab renders
**Then** a greeting + briefing text appears (from `HomeComposition.briefing`), followed by category clusters with count badges and accent color dots/glow shadows. Cards stagger in (0.2s delay, 0.25s per card). Up to 7 items shown.

### 5.4 Zoned Focus Tab (ZonedFocusHomeView)

**Given** home composition has been generated
**When** ZonedFocusHomeView's Focus tab renders
**Then** three physical zones appear:
- **Zone 1 (Hero):** Bold card with colored left accent stripe, category + urgency chip, 3-line summary, reason sentence
- **Zone 2 (Standard):** Compact list of entries with priority/due date details
- **Zone 3 (Habits):** "TODAY'S HABITS" strip showing only habits where `appliesToday` is true, grouped by cadence (daily/weekdays/weekly/monthly)

A fade mask over the top 110pt prevents content overlap during tab swipe.

### 5.5 Composition Cache and Refresh

**As a** user **I want** the composition to be cached **so that** it loads instantly on reopen.

**Given** I've already seen a composition this session
**When** I reopen the app
**Then** `HomeCompositionStore.load(expectedVariant:)` loads the cached composition, rejecting wrong-variant caches. On foreground, a background diff-only refresh is triggered via `requestLayoutRefresh(entries:variant:)` (cheaper than full recompose). Session-level staleness tracked via `AppState.currentSessionID` (UUID, not time-based). Variant switch = full reset (invalidate cache + nil conversation + cold start via `compose_view`).

> **Gap:** Empty state in SacHomeView's Focus tab is broken — `SacHomeView.body` always renders `populatedState` to keep `TabView` alive, disconnecting the standalone empty state (pulsing circles). Flagged as TestFlight checklist item #8.

---

## 6. Calendar Stories

### 6.1 Open Calendar

**As a** user **I want to** see my entries on a calendar **so that** I can plan around due dates.

**Given** I'm on the Navigator or Zoned home view
**When** I tap the calendar icon in the top-left of the top bar
**Then** a `CalendarView` sheet opens showing a monthly grid with day-of-week headers (S, M, T, W, T, F, S), month navigation via chevron buttons, and up to 3 category color dots per day cell indicating entries due that day.

### 6.2 Habits on Calendar

**As a** user **I want to** see recurring habits on the calendar **so that** I know which days they apply.

**Given** I have habits with cadence settings
**When** viewing any day on the calendar
**Then** habits appear based on their cadence: daily habits show every day, weekday habits show Mon–Fri, weekly habits show on their creation weekday, monthly habits show on their creation day-of-month. Each habit contributes a category color dot to the day cell.

### 6.3 Day Detail

**As a** user **I want to** see what's due on a specific day **so that** I can drill into details.

**Given** I'm viewing the calendar
**When** I tap a day cell
**Then** the selected day expands to show all entries due that day in a list. Tapping an entry dismisses the calendar and opens the entry detail sheet (with 0.35s delay for smooth transition).

> **Gap:** Calendar is only accessible from Navigator and Zoned views — DamHomeView (scanner) has no calendar button. Scanner users must switch variants to access the calendar.

---

## 7. Edge Case Stories

### 7.1 Empty Home State

**As a** new user with no entries **I want to** see an inviting empty state **so that** I know what to do.

**Given** I have zero active entries (skipped onboarding or archived everything)
**When** I view the home screen
**Then** I see a centered mic button with pulsing concentric circles (3 rings, staggered breathing animation), headline "Say or type anything.", subtext "Murmur remembers so you don't have to.", and the bottom nav bar with mic and keyboard buttons still available.

> **Gap:** Empty state is broken in SacHomeView — the body always renders populated state to keep TabView alive. Empty state needs to be moved inside `FocusTabView`. DamHomeView and ZonedFocusHomeView may have the same issue.

### 7.2 Microphone Permission Denied

**As a** user who denied mic permission **I want to** understand why recording doesn't work **so that** I can fix it.

**Given** I denied microphone permission or it's in the `.denied` state
**When** I tap the mic button
**Then** the recording attempt silently fails — `inputState` returns to `.idle` and the status item is removed.

> **Gap:** No user-facing error or guidance when mic permission is denied. User sees nothing happen. Should show an alert directing to Settings. Error views exist in `Murmur/Views/Errors/` but are not wired into the main flow.

### 7.3 Empty Transcript (Silence)

**As a** user **I want** the app to handle silence gracefully **so that** nothing bad happens if I accidentally hit record.

**Given** I start recording but don't say anything
**When** I stop recording
**Then** if the final transcript is empty after trimming, recording is cancelled, state returns to idle, `displayTranscript` is cleared, and no processing occurs.

### 7.4 Out of Credits

**As a** user who has exhausted credits **I want to** know why processing failed **so that** I can top up.

**Given** my credit balance is zero
**When** the pipeline detects insufficient credits during processing
**Then** the error is caught as `PipelineError.insufficientCredits`, sanitized to "Out of credits.", and shown as an error thread item.

> **Gap:** `OutOfCreditsView` exists but is not wired into the main flow. The actual experience is a generic error toast with no path to top up.

> **Gap:** Credit balance is based on hardcoded token estimates (`TokenUsage(inputTokens: 200, outputTokens: 100)`), not real usage from PPQ API responses. Balance display is misleading (TestFlight checklist item #4).

### 7.5 Network Failure

**As a** user **I want to** know when processing fails due to network issues **so that** I can retry.

**Given** the LLM API call fails (network timeout, server error, etc.)
**When** the error is caught during SSE streaming
**Then** an error thread item is added with the sanitized message ("Couldn't process — network error." for `extractionFailed`, or "Couldn't process — try again." as default), and the original text is stored in `retryText` for potential retry via `retryError()`.

> **Gap:** There is no visible retry button in the current home view UI. The `retryError` method exists on `ConversationState` and the `ThreadItem.error` case stores `retryText`, but no view renders a "Retry" button for error thread items.

### 7.6 Ambiguous Input

**As a** user **I want** the agent to handle garbled speech gracefully **so that** transcription errors don't produce garbage entries.

**Given** speech recognition produces a garbled transcript
**When** the agent processes the transcript
**Then** the agent's system prompt instructs it to "infer intended meaning and clean up wording", use "fuzzy semantic matching" for references, and only create entries for genuinely intentional items. If the input is truly unintelligible, the agent may respond with text-only (no tool calls).

### 7.7 Parse Failures

**As a** user **I want** the app to handle malformed LLM responses **so that** partial results are still saved.

**Given** the agent returns a tool call that fails to parse
**When** `ParseFailure` is recorded during SSE consumption
**Then** the failure is tracked separately, other valid tool calls in the same response are still executed (per-tool-call error isolation), and the parse failure is reported via `ToolResultBuilder` back to the conversation for self-correction in future turns.

### 7.8 App Backgrounding During Recording

**As a** user **I want** recording to stop cleanly when I leave the app **so that** no audio leaks or hangs.

**Given** I'm actively recording
**When** the app moves to background (scene phase changes)
**Then** `MurmurApp` calls `appState.conversation.cancelRecording()`, the recording task is cancelled, audio levels are cleared, the pipeline's `cancelRecording()` is called, and state returns to idle.

> **Gap:** The cancel path (background) discards the transcript entirely. If the user recorded 30 seconds of speech and accidentally switches apps, all content is lost.

---

## 8. Power User Stories

### 8.1 Keyboard Input for Rapid Capture

**As a** power user **I want to** quickly type entries without touching the mic **so that** I can capture thoughts in meetings or quiet settings.

**Given** I'm on the home screen
**When** I tap the keyboard icon in the bottom nav bar (top-right of mic dome)
**Then** an inline text input capsule appears (1–3 line multiline), the keyboard opens immediately (auto-focused), I can type and submit with the send button, clear text with the (x) button, the bar closes after submission, and the mic button reappears.

### 8.2 Settings and Credit Management

**As a** user **I want to** view my credit balance and top up **so that** I can continue using the app.

**Given** I tap the gear icon to open settings
**When** the settings sheet appears
**Then** I see: a large credit balance number with "credits remaining" label, a "Get More Credits" button that opens the Top Up view, notification toggle chips (Reminders, Due Soon, Snooze), and an Archive link under "DATA" section.

### 8.3 Top Up Credits via IAP

**As a** user **I want to** purchase more credits in-app **so that** I can continue using Murmur.

**Given** I'm in the Top Up view
**When** credit packs load from StoreKit
**Then** I see pack cards showing credit amounts, prices, "Popular" and "Best value" badges, and a "Buy" button on each. On purchase, StoreKit handles the transaction, credits are applied, and a success toast confirms.

> **Gap:** StoreKit products are configured locally (`.storekit` file) but real products must be set up in App Store Connect for TestFlight/production. No server-side receipt validation exists.

### 8.4 Archive Browser

**As a** user **I want to** browse and restore archived entries **so that** I can recover items I archived.

**Given** I navigate to Settings > Archive
**When** the archive view loads
**Then** I see all archived entries sorted by `updatedAt` (newest first), each with a category badge, summary text, and a purple restore button. If no entries are archived, I see an empty state with archivebox icon and "No archived entries" message. Tapping restore sets the entry back to active.

### 8.5 Dev Mode (Debug Only)

**As a** developer **I want** a hidden dev mode **so that** I can test features and reset state.

**Given** I'm running a DEBUG build
**When** I 5-tap the empty state subtitle text (via `DevModeActivator`)
**Then** `isDevMode` is toggled and a floating hammer button appears. Tapping it opens `DevModeView` with controls for: variant picker (Navigator/Scanner/Zoned), recompose home button, and other dev tools.

> **Gap (Partial Fix):** The DevMode button display in RootView is now gated by `#if DEBUG`, but `DevModeActivator` (the 5-tap gesture recognizer) is still **not** `#if DEBUG` gated. The tap handler executes in Release builds — it sets `isDevMode = true` which has no visible effect in release (since the button is gated), but the state mutation still occurs.

### 8.6 Notification Preferences

**As a** user **I want to** control which notifications I receive **so that** I'm not overwhelmed.

**Given** I'm in Settings
**When** I see the Notifications section
**Then** I can toggle three notification types independently: Reminders (bell), Due Soon (clock), and Snooze wake-ups (moon). Each is a tappable chip that toggles on/off with animation.

> **Gap:** Notifications need real-device end-to-end verification. Simulator doesn't fully fire local notifications. Flagged as TestFlight checklist item #6.

### 8.7 Notification Deep-Link to Entry

**As a** user **I want to** tap a notification and go directly to the relevant entry **so that** I can act on it immediately.

**Given** I receive a local notification for a reminder or due entry
**When** I tap the notification
**Then** `NotificationCenter.default.publisher(for: .murmurOpenEntry)` fires with the entry's UUID, `RootView` receives it and sets `selectedEntry` to the matching entry, opening the detail sheet.

---

## 9. Cross-Cutting Gaps Summary

### Blocking (Must Fix Before TestFlight)

1. **API key baked in plain text** — extractable from Info.plist. No distribution strategy for testers (checklist #3)
2. **Credits show hardcoded estimates** — `LocalCreditGate` uses fixed token counts, not real PPQ usage (checklist #4)
3. **Tab swipe vs card swipe conflict** — needs real-device verification (checklist #2)

### Missing UX Flows

4. **No mic permission denied feedback** — error views exist but are unwired
5. **No out-of-credits rich experience** — `OutOfCreditsView` exists but is unwired
6. **No retry button** for failed agent processing
7. **No search** — entries become unfindable at scale
8. **No agent undo UI** — undo data exists but no button renders
9. **No confirmation UI** for `confirm_actions` (agent clarification flow)
10. **Empty state broken in SacHomeView** — always renders populated state for TabView (checklist #8)

### Incomplete Features

11. **Conversation context invisible** — no indicator that multi-turn is active
12. **No conversation reset** — only app restart or variant switch clears history
13. **Background recording discards speech** — no auto-save
14. **Agent memory invisible** — no view/edit/delete for stored preferences
15. **No bulk operations** — no multi-select for complete/archive/delete
16. **Calendar only on Navigator/Zoned** — scanner has no calendar access
17. **Zone view unverified on device** — UIPageViewController behavior may differ from simulator

### Data/Privacy

18. **No encryption at rest** — Canon marks this as required for production
19. **No server-side API key management** — key is client-embedded
20. **Notification permission denied = silent** — no feedback when notifications won't work

### Resolved Since Last Review (2026-03-03)

- ~~No launch screen~~ — LaunchScreen.storyboard added
- ~~No habit streak display~~ — current + best streak shown in entry detail
- ~~Daily Focus system gaps~~ — entire DailyFocus deleted, replaced by unified HomeComposition
- ~~DevModeView not gated~~ — button display in RootView now `#if DEBUG` (activator still not)
- ~~Separate edit sheet~~ — replaced by inline editing in EntryDetailView
