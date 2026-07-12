# Sac's State

What sac is working on right now. Updated with every PR.

---

## Headline for dam (what needs you)

Notes-first landed (your Plan 13, #197/#198) and I built the Notes screen on top
(#199). The name is settled — **Jefe** — and the branding is up (#200). Three
things need you, ordered by unblock:

1. **Comprehensive-notes CORE change — the big one.** Isaac's direction sharpened:
   the notes aren't terse extracted items, they're a **client↔team coordination
   artifact** — a Copilot-style structured writeup capturing what the client
   wants + the restrictions (budget/permits/deadline/access) + conditions, so the
   crew can execute and the paperwork has real meat to draw from. The live board
   stays terse; only **`finish()`'s notes payload** gets rich. What I need from
   the core (payload shape, then I wire the rendering — the UI shell already
   groups + shows per-item detail):
   - a **narrative summary** (not just a one-liner),
   - a **`detail` string per item** (the "why/context" behind each captured line),
   - **client-preference + logistics + budget capture** as first-class fields,
   - a richer extraction prompt behind it.
   v1 can stay ESSENTIAL — 4 buckets: **Summary · Scope of Work** (w/ client
   prefs) **· Constraints** (budget/permits/deadline/access) **· Conditions &
   Issues**. Expand later. I specced this on #199; waiting on the payload shape
   before I build the richer rendering.
2. **Review + merge #199 (notes screen) and #200 (Jefe branding).** Merging #200
   auto-fires the internal TestFlight lane (release.yml on push→main).
3. **CANON co-sign the name: Jefe.** #200 ships the icon + theme under it; this
   retires the #188 rename hunt. Want your sign-off in CANON so it's official.

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
