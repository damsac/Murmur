# Sac's State

What sac is working on right now. Updated with every PR.

---

## Headline for dam (what needs you)

*(freshened 2026-07-16 — the whole paperwork + editable-notes arc is merged.)*

1. **Tap-to-fix edit UI is SHIPPED (#232, on main).** The roadmap "next up" is
   done: notes-screen board rows are tappable → edit sheet (text/quantity/remove)
   + `＋ ADD LINE`, all through your Plan 16 CRUD so corrections reach the
   document. This **unblocks Plan 17** (corrections → vocab suggestion +
   `record_correction`) — real field corrections can now inform the suggest-card
   UX, as you sequenced. One catch I hit + handled, flag in case it bites
   elsewhere: core ids are **lowercase** UUIDv7 with a case-sensitive lookup, but
   Swift's `uuidString` is **uppercase** — I lowercase on the way out.

2. **#232 needs a TestFlight build — it can only come from you.** Confirmed the
   sacmeng account Actions gate is still live: my merge of #232 fired *no* run.
   So editable notes reaches TestFlight on **your** next push to `main` (it's
   already there — your next release carries it) or a `workflow_dispatch` if we
   want it sooner. No action needed unless Isaac wants it before your next merge.

3. **Two-week runway before you're away a month — let's front-load core.** Isaac
   wants Jefe *testable by real people* and *close to App Store*. Since I can't
   touch the core while you're gone, the launch-critical **core** items to land
   before you go (my read, your call): **real-mic device tuning** (the
   voice→transcript reliability is the whole experience), **walk-reopen seam
   (#223)** (reopening past walks is table-stakes for a shippable app), **whisper
   warm-up (#228)** (fresh WhisperContext per walk is a bad first impression).
   App Store submission prep (metadata/screenshots/privacy) is app-side — I'll
   own it, no dependency on you. Plan 17 is great but lower launch-priority than
   those three if time is tight.

**My next (app-side, parallel):** beta-feedback fixes (#220 dark-mode text /
#221 row labels / #224 gallery), vocab-pack curation (the placeholders), and
App Store readiness.

## In-flight PRs (pushed, thinking-first)

- **#199 notes screen UI** (`pr/sac/notes-screen`) — post-walk Notes destination:
  summary card, trade-aware kind-grouped sections, collapsed transcript, EXPORT,
  and the full per-trade action-button row wired to `buildDocument(kind:)` via
  DocKinds (Estimate/Invoice/Work Order | Inspection/Summary). Also folds the
  onboarding mic-granted fix (green banner → inline ON stamps + START WALKING).
  UI shell already handles grouping + per-item detail — it's ready for the richer
  payload from decision #1.
- **#200 Jefe branding — hard-hat icon + amber theme** (`pr/sac/brand-icon-theme`,
  off `main`). New app icon (foreman/hard-hat mark, black field, marigold hat) +
  palette moved off safety-orange (two App-Store competitors use it) to
  black+amber. `Theme.C.orange*` token **names kept** (call-site stability),
  **values** swapped to the hard-hat gold; ink-on-gold for contrast; thin marks →
  darker amber so they don't vanish on paper. Pure Swift tokens + one asset, no
  FFI surface. **Build-verified in isolation off main** (BUILD SUCCEEDED,
  real-core, codesigned for device) + MERGEABLE. NOTE: two NotesView thin-mark
  retints were intentionally left off #200 (they style #199's new UI, which
  isn't on main) — one-line follow-up when #199 lands.

## Recently landed (yours + mine)

- **Your Plan 13 notes-first** (#197 on-demand `build_document`, #198 the atomic
  `finish()`→`NotesPayload` flip), decisions doc #192 (you took all my recs),
  TestFlight→real-engine (#193), **STT→base.en (#196 — fixes my device lag)**,
  app icon plumbing (#194).
- **Mine:** #187 voice-first mode, #189 notes-first design, #190 onboarding +
  business profile + DONE fix, #191 STATE freshen — all merged with your
  reactions in.

## Device-test findings

- **Real-core builds, signs, and runs on device.** Full walk → whisper →
  extraction → document verified on hardware earlier; the base.en switch (#196)
  addressed the speech→transcript lag I hit on small.en.
- **Phone install currently pending a USB retry.** A direct-to-device install
  dropped mid-transfer (`IXRemoteErrorDomain code 6`, wireless) — a transfer
  flake, not code. Cable install is the fix; nothing blocking on your side.

## What I'm doing next (no blockers)

- Wire the richer notes rendering the moment the payload shape from decision #1
  lands (UI shell is ready).
- Per-trade action-button taxonomy is drafted and wired in #199.
- Photo-grouping styling on the review document (Plan 12 seam ready).

## Notes for dam

- **FFI gotcha that bit me today (your domain, worth knowing):**
  `build-ffi.sh --device-only` leaves the **simulator** slice stale, and bindgen
  regenerates `ffi.swift` **and the C header** from that sim lib — so it silently
  drops types/checksums (I lost `NotesPayload` and the `build_document` checksum
  → "cannot find in scope" / "No type named NotesPayload"). A full
  `./build-ffi.sh` (both slices) fixes it; restoring the committed `ffi.swift`
  alone does **not** (the gitignored xcframework header stays stale). Your #180
  bindings-staleness CI is the right instinct — this is a sibling failure mode
  (stale **binary/header** vs stale **bindings**); might be worth a guard.
- **Device signing:** automatic → my personal Apple Development team
  (`9UQKJHZ8J3`, isaacwm23@gmail.com), bundle `com.isaacwm.sitewalk`. Separate
  from the ASC distribution identity `release.yml` uses for TestFlight.
- **CI auto-fire on my PRs** — still gated at the **sacmeng account level**
  ("Actions is disabled for your account"; ticket filed) unless it's cleared
  since. Until then your push to one of my branches triggers the run (you're the
  actor).
