# Sac's State

What sac is working on right now. Updated with every PR.

---

## Current focus

Out-of-credits UX: wired OutOfCreditsView into the live error path, simplified it to a minimal screen, and added DevMode tooling to test the flow.

## Recent decisions

- **OutOfCreditsView wired end-to-end** — Was excluded from compilation (`Views/Errors/**` blanket exclude in project.yml). Changed to enumerate only the three still-unwired views, leaving OutOfCreditsView included.
- **OutOfCreditsView simplified** — Stripped transcript card, balance row, token count row, "Save as raw" button, and the "Review / Here's what I heard" header. Now just: icon + "Out of tokens" + subtitle + "Top up tokens" button. The recording context was noise at the moment of running out of credits.
- **outOfCreditsInfo simplified to Bool** — Was a `(transcript: String, duration: TimeInterval)` tuple. Now just `Bool`. No longer need the payload since the view doesn't show it.
- **Focus tab empty state** — Added "You're all caught up." with checkmark icon when composition is loaded but has no focus clusters and is not processing.
- **DevMode drain credits button** — Added `setBalance(_ newBalance: Int64)` (DEBUG-only) to `LocalCreditGate`, exposed as "Drain Credits to Zero" button in DevModeView for easy out-of-credits testing.
- **project.yml exclusion fix** — Changed `Views/Errors/**` to enumerate only the three orphaned views. OutOfCreditsView now compiles.

## Open questions

- Should swipe-to-switch-tabs ever come back? Only viable path is UIViewRepresentable. High complexity, low priority.
- API key distribution for testers unresolved — dam needs to confirm which PPQ key to bake into the archive build.
- Is the three-zone layout (ZonedFocusHomeView) still on the roadmap, or do we consolidate on SacHomeView?

## What I need from dam

- Confirm API key plan for TestFlight archive build — document or add a Makefile target.
- PPQ error signal for wiring error views (#9) — need a clear error type from PPQ auth/quota failures.
- Review the TestFlight checklist and adjust any dam-owned items or priorities.
