# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **TestFlight polish** — UI cleanup, scroll fixes, LLM tool improvements, speech-to-text in entry detail
- **Error handling design** — spec written at `docs/superpowers/specs/2026-03-14-error-handling-hardening-design.md`, not yet implemented

## What happened last session

- Fixed scroll bug in All tab — replaced offset-based tab switching with conditional rendering in SacHomeView, ZonedFocusHomeView, DamHomeView
- Fixed habit completion via LLM — added `check_off_habit` to update_entries tool so LLM marks habit done for period instead of archiving
- Added notes support to LLM — agent can now read and write entry notes via create_entries and update_entries
- Added speech-to-text mic button in entry detail notes — records speech, sends through LLM pipeline with entry context so agent writes notes
- System prompt updated with habit-specific guidance

## Recent decisions

- Scroll fix: conditional rendering over offset-based tab switching (GeometryReader + HStack + offset caused gesture conflicts between simultaneous ScrollViews)
- Habit tools: `check_off_habit` field on update_entries, not a new tool — keeps tool surface small
- Notes via LLM pipeline: speech-to-text in entry detail goes through the full LLM pipeline (not raw transcript append) so the agent can structure/summarize
- Notes in context: truncated to 100 chars in LLM context line to avoid blowing up token usage

## Open questions

- Credit value redefinition: $0.001 → $0.0005 per credit to make packs profitable
- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Home view default for testers: which variant ships?
- Note dictation UX: should the recording overlay show when dictating notes, or should there be a more subtle inline indicator?

## What I need from sac

- Help wiring error views (MicDenied, OutOfCredits, APIError) — on roadmap as shared task
- Empty state fix for SacHomeView FocusTabView
- Sign off on onboarding demo transcript
- Test the scroll fix in SacHomeView All tab
