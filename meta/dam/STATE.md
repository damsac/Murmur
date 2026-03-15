# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- **TestFlight polish** — export compliance, portrait lock, error handling hardening, credit system fixes, UI polish across the board
- **Error handling design** — spec written at `docs/superpowers/specs/2026-03-14-error-handling-hardening-design.md`, not yet implemented

## What happened last session

- Switched LLM from Sonnet to Haiku for cost sustainability, wired real token usage into credit deduction
- Deduplicated home composition refresh (was firing twice on foreground)
- TestFlight prep: added `ITSAppUsesNonExemptEncryption` = false, portrait-only orientation lock
- Error handling hardening design spec: user-facing toasts for mic denied / pipeline unavailable, improved error messages with HTTP status mapping, crash safety (force-unwrap calendar math), structured logging (os.log over print)
- Due date formatting, layout animations, UI polish
- Studio analytics design spec written
- Various docs: brainstorms, plans, reviews, screenshots from prior sessions

## Recent decisions

- Haiku over Sonnet for all agent calls (cost, quality validated)
- Export compliance flag in Info.plist (no encryption = exempt)
- Portrait lock (no landscape support planned)
- Error bridging via `ErrorPresentation` enum on ConversationState, observed by RootView (matches existing `completionText` pattern)
- Force-unwrap calendar math to be replaced with safe nil-coalescing

## Open questions

- Credit value redefinition: $0.001 → $0.0005 per credit to make packs profitable
- Conversation reset: timer, explicit button, or N seconds of silence?
- Token budget for context window
- Home view default for testers: which variant ships?

## What I need from sac

- Help wiring error views (MicDenied, OutOfCredits, APIError) — on roadmap as shared task
- Empty state fix for SacHomeView FocusTabView
- Sign off on onboarding demo transcript
