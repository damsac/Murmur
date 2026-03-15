# Murmur UX Friction Audit

**Date:** 2026-03-14 (refreshed from 2026-03-03 original)
**Branch:** `dam` (includes merged work from `sac` through PR #97)
**Method:** Code analysis across current home views, recording flow, agent pipeline, and new features (calendar, inline editing, zones, layout diffs).

---

## 1. Input Lifecycle Friction

### 1.1 Recording → Processing Transition (IMPROVED — verify on device)

**What user experiences:** Transition from recording wave to processing glow.

**Current state:** `RecordingStateView` now uses a reactive dual-harmonic sine wave driven by `TimelineView(.animation)` with per-sample audio modulation. `ProcessingGlowView` uses a faster angular gradient rotation (1.6s), stronger opacity pulse (0.8–1.0 in 0.9s), and scale breathe (1.0–1.03 in 1.1s). Both overlays have been polished since 2026-03-03.

**Remaining concern:** The two overlays are still independent `if` blocks in RootView. The flash between recording and processing may still occur — needs real-device verification. If the timing is tighter now due to the polished animations, this may be resolved in practice.

**Fix direction (if still visible):** Synchronize into a single cross-fade container, or add a brief crossfade where both overlays coexist.

### 1.2 Transcript Vanishes During Processing (STILL PRESENT)

**What user experiences:** The transcript they just spoke disappears when they stop recording. During processing, they see only a glow — no text confirmation of what was captured.

**Technical cause:** `displayTranscript` is set in `stopRecording()` but no view consumes it during `.processing` state. The wave visualization disappears, the processing glow appears, but the user's words are gone from screen.

**Fix direction:** Show `displayTranscript` in a lightweight overlay or inline element during processing.

### 1.3 Mic Button Opacity/Disabled Decoupling (SUBTLE)

**What user experiences:** After tapping stop, the mic button fades to lower opacity over 250ms. During the fade, the button is `.disabled(isProcessing)` but still looks tappable until the opacity animation completes.

**Technical cause:** Opacity animation and disabled state applied independently.

### 1.4 Bottom Nav Redesign (CHANGED — reassess)

**What changed:** BottomNavBar now uses a `NotchedTabBarShape` with a floating mic dome, Focus/All tab labels on either side, and the keyboard button appears top-right of the mic dome. Text input mode shows a capsule text field (1–3 line multiline) with send button and clear (x) button. Transitions use opacity + scale (0.9 anchor).

**Remaining concern:** The keyboard button snap (processing starts → keyboard disappears without animation) may still exist if the processing state transition isn't animated. Needs verification.

### 1.5 Recording Wave Quality (RESOLVED)

**Previous issue:** Waveform, transcript text, and dark fade gradient animated at different speeds (80ms/150ms/250ms).

**Current state:** Recording visualization completely rewritten. Dual-layer harmonics driven by a single `TimelineView(.animation)` with unified phase progression. Amplitude, speed, cycles, and line width all scale smoothly from the same audio buffer. Dark fade uses 6 opacity stops for smooth reading. This is substantially better than before.

---

## 2. Error States & Dead Ends

### 2.1 Error Views — Still Mostly Orphaned (HIGH)

Error views exist in `Murmur/Views/Errors/` but production paths still silently fall back to deterministic UI:

| View | Purpose | Wired? |
|------|---------|--------|
| `MicDeniedView` | Mic icon + "Open Settings" button | NO |
| `OutOfCreditsView` | Transcript + balance + "Top up" + "Save raw" | NO |
| `APIErrorView` | Error details + retry + save buttons | NO |
| `LowTokensView` | Low balance warning + estimated recordings left | NO |

Flagged as TestFlight checklist item #9 (nice-to-have). The deterministic fallback (empty Focus tab, no composition) is the actual user experience when LLM fails.

### 2.2 Mic Permission Denied = Nothing Happens (HIGH)

**Scenario:** User denied mic permission, taps mic button.
**What happens:** `ensureMicPermission()` returns false silently. `inputState` returns to `.idle`. No toast, no error, no guidance.
**What should happen:** Show `MicDeniedView` with "Open Settings" button, or at minimum a toast directing to Settings.

### 2.3 Out of Credits = Invisible Error (HIGH)

**Scenario:** User records, pipeline throws `PipelineError.insufficientCredits`.
**What happens:** Sanitized to "Out of credits." string, appended to `threadItems` as `.error(...)`. Thread items are not rendered in any view.
**What should happen:** Show `OutOfCreditsView` with transcript, balance, and top-up CTA.

**Additional issue:** Credit balance itself is misleading — `LocalCreditGate` charges hardcoded `TokenUsage(inputTokens: 200, outputTokens: 100)` instead of real PPQ usage. User may hit zero credits sooner or later than expected.

### 2.4 Network Error = No Retry (MEDIUM)

**Scenario:** Network glitch during agent processing.
**What happens:** Error sanitized to "Couldn't process — try again." Appended to invisible `threadItems`. `retryError()` exists but no UI calls it.
**What should happen:** Toast with "Retry" action button, or `APIErrorView` with retry and save options.

### 2.5 Thread Items Buffer Is Invisible (ARCHITECTURAL)

`ConversationState.threadItems` collects 5 types: userInput, actionResult, agentText, status, error. All with structured data including retry text, undo transactions, and action summaries. **No view in the app renders any of these.** The conversation system is a write-only buffer.

This is a deliberate design choice (ambient feedback over conversational UI), but it means error recovery, agent undo, and conversation history are all invisible.

### 2.6 Notification Permission Denied = Silent (LOW)

**Scenario:** User sets a reminder, notification permission prompt appears, user denies.
**What happens:** `NotificationService.requestPermissionIfNeeded()` catches the denial. No feedback. Reminders silently don't work. No indicator in Settings.

Notifications need end-to-end real-device verification (TestFlight checklist item #6).

### 2.7 API Key Missing = Silent Empty State (NEW — MEDIUM)

**Scenario:** TestFlight tester has no PPQ API key in their build.
**What happens:** LLM calls fail, deterministic fallback renders the Focus tab, but no error is shown. The app works but the AI features silently do nothing.
**What should happen:** Show `APIErrorView` or a clear message that the API key is missing/invalid.

Flagged as TestFlight checklist items #3 and #9.

---

## 3. Animation Continuity

### 3.1 Entry Arrival Stagger — Three Implementations (MEDIUM)

**What user experiences:** Different arrival animation timings depending on which home view they're using.

**Technical cause:** Each home view has its own stagger timing:
- **DamHomeView:** 60ms per entry with `spring(response: 0.4, dampingFraction: 0.8)`, uses `matchedGeometryEffect` for layout diff moves
- **SacHomeView:** 0.2s initial delay + 0.25s per card
- **ZonedFocusHomeView:** Similar to Sac but with 110pt fade mask for swipe protection
- **AllEntriesView:** `GlowingEntryRow` with 3.5s glow fade (respects `reduceMotion`)

The stagger timing is 3x faster in Scanner than Navigator. This isn't necessarily wrong (scanner = glance, navigator = browse), but it's worth verifying the intentionality.

### 3.2 Tab Swipe vs Card Swipe Gesture Conflict (HIGH — blocking)

**What user experiences:** On the Focus tab, horizontal swipe might trigger tab change instead of card swipe action (or vice versa).

**Technical cause:** `TabView(.page)` captures horizontal swipes for page navigation. `SwipeableCard`'s `DragGesture` also captures horizontal swipes for complete/archive/snooze. Fix in progress: Focus tab passes empty swipe actions so cards use `minimumDistance: .infinity`, letting UIPageViewController handle. On the All tab, swipe actions are active and `TabView(.page)` is not used (or cards override).

**Risk:** UIPageViewController behavior differs between simulator and device. This is TestFlight checklist blocker #2. Must verify on real hardware.

### 3.3 Accessibility Reduce Motion — Partial Coverage (HIGH — accessibility)

**Current state:** `GlowingEntryRow` in `AllEntriesView` respects `accessibilityReduceMotion` — skips 3.5s glow animation and calls `onGlowComplete()` immediately.

**Still unchecked:**
- Empty state pulse rings (3 concurrent 3s loops)
- `ListeningGlowView` / `ProcessingGlowView` (rotation + pulse)
- DamHomeView stagger reveals (spring animations)
- ZonedFocusHomeView zone transitions
- SacHomeView category cluster stagger
- Recording wave visualization (continuous `TimelineView(.animation)`)
- Calendar view transitions

~70% of animations still run unchecked for motion-sensitive users.

### 3.4 DamHomeView matchedGeometryEffect Fragility (MEDIUM)

**Technical cause:** `matchedGeometryEffect` is used for entry move animations during layout diffs. This API is known to be finicky — mismatched IDs, view lifecycle timing, or animation interruption can cause visual glitches (entries snapping, disappearing, or appearing in wrong positions).

**Mitigation:** Open question in dam's STATE.md acknowledges this: "Phase 3 matchedGeometryEffect: known to be finicky — may need fallback to simple opacity transitions."

### 3.5 Zone View Fade Mask (COSMETIC)

**Technical cause:** `ZonedFocusHomeView` applies a fade mask over the top 110pt to prevent content overlap during tab swipe. This may cause a visible gradient cutoff at the top of the zone content, especially if entries are tall or the hero zone card has a large accent stripe.

### 3.6 Transition Inconsistencies (COSMETIC — partially improved)

- Recording/processing overlays: still independent `if` blocks in RootView
- Tab switching: DamHomeView uses ZStack with asymmetric transitions (leading insert, trailing removal), while SacHomeView and ZonedFocusHomeView use `TabView(.page)` — different physics
- Calendar dismiss: 0.35s delay hack before opening entry detail after calendar dismiss. May feel sluggish.

---

## 4. Data Flow Latency

### 4.1 Time to First Visible Result (ACCEPTABLE)

| Phase | Duration | User Sees |
|-------|----------|-----------|
| Stop recording → processing state | Instant + animation | Recording wave fades, processing glow appears |
| Cancel recording + get transcript | 1–10ms | Processing glow |
| Network request + TLS | 50–200ms | Processing glow |
| LLM time-to-first-token | 200–800ms | Processing glow |
| **Total: stop → first entry** | **500–1200ms** | Processing glow + dots |

Acceptable for an LLM-powered app. SSE streaming is well-designed — parsing happens off the main thread, events yield immediately.

### 4.2 Home Composition Load (IMPROVED)

**Previous:** Daily focus used non-streaming `session.data()` — shimmer for 0.8–2+ seconds on cold launch.

**Current:** `HomeComposition` is cached per-variant via `HomeCompositionStore`. On warm launch, cached composition loads instantly. On cold launch (no cache or variant mismatch), `compose_view` is called (full LLM round-trip, similar latency to old daily focus). On foreground, a background diff-only refresh via `requestLayoutRefresh(entries:variant:)` is triggered — this uses `update_layout` which is cheaper than full recomposition.

**Net improvement:** Warm launches are instant. Cold launches have the same latency but are rarer (variant switch or first launch only).

### 4.3 Entry Stagger Varies by View (INTENTIONAL)

- DamHomeView: 60ms × N entries — last of 7 appears at 360ms
- SacHomeView: 200ms + 250ms × N entries — last of 7 appears at 1.95s
- AllEntriesView: 150ms × N per category section

The scanner is designed for quick glance, navigator for browsing. Timing reflects this.

### 4.4 Calendar Entry Navigation Delay (NEW — SUBTLE)

When tapping an entry in the calendar day list, there's a 0.35s delay before the entry detail opens. This is a workaround to allow the calendar sheet to dismiss smoothly before the detail sheet presents. May feel sluggish on fast taps.

### 4.5 Layout Diff vs Full Compose (NEW — GOOD)

| Operation | Token Cost | Latency | When Used |
|-----------|-----------|---------|-----------|
| `compose_view` (full) | High (~2000 tokens) | 1–3s | Cold start, variant switch |
| `get_current_layout` + `update_layout` (diff) | Low (~500 tokens) | 0.5–1s | Foreground refresh, after entry creation |

Diff-based refresh is 3–4x cheaper and faster than full recomposition. This is a significant improvement over the old daily focus system which always did full generation.

---

## 5. New Friction Points (Since 2026-03-03)

### 5.1 Three Home Views — User Can't Choose (MEDIUM)

Users are stuck with whatever variant is set in DevMode. There's no user-facing settings toggle for home view preference. Phase 4 of the layout diff plan calls for a "View" section in Settings with Focus/Browse picker, but it's deferred.

**Impact:** If testers prefer a different layout, they have no way to switch without dev mode access (which is `#if DEBUG` gated in the button display).

### 5.2 Inline Editing Auto-Save (POTENTIAL FRICTION)

Entry detail now auto-saves on every keystroke via `onChange`. This is convenient for quick edits but could cause issues:
- No undo for field edits (unlike delete which has undo toast)
- Accidental edits while scrolling/tapping can't be reverted
- No visual confirmation that changes were saved

If users are used to explicit save buttons, the auto-save behavior may surprise them.

### 5.3 Habit Zone Only Shows Today (SUBTLE)

The "TODAY'S HABITS" strip in ZonedFocusHomeView only shows habits where `appliesToday` is true. If a user has weekly habits due on other days, they won't see them on the Focus tab. They're visible in the All tab and Calendar, but the Focus tab creates an impression that those habits don't exist.

### 5.4 Calendar Month Navigation (COSMETIC)

Calendar uses chevron buttons for month navigation. No swipe gesture for month-to-month navigation. This is a common iOS calendar pattern that users may expect.

---

## 6. Prioritized Fix List

### Tier 1: TestFlight Blockers

1. **Verify tab swipe vs card swipe on device** — UIPageViewController gesture conflict (checklist #2)
2. **API key distribution for testers** — no key = silent empty Focus tab (checklist #3)
3. **Fix hardcoded credit estimates** — read real token usage from PPQ responses (checklist #4)

### Tier 2: User-Blocking (Fix Before TestFlight or First Feedback Round)

4. **Wire error views** — at minimum, surface API key missing/invalid as `APIErrorView` (checklist #9)
5. **Wire `MicDeniedView`** — show alert/toast when mic permission denied
6. **Fix SacHomeView empty state** — move empty state inside FocusTabView (checklist #8)
7. **Show transcript during processing** — consume `displayTranscript` in processing overlay

### Tier 3: Quality (Fix Before Public Launch)

8. **Respect `accessibilityReduceMotion`** broadly — recording wave, processing glow, empty state rings, zone transitions
9. **Add retry to error flow** — toast with "Retry" action calling `retryError()`
10. **Wire `OutOfCreditsView`** — show rich experience when balance hits zero
11. **Add user-facing home view preference** — Phase 4 settings toggle for Scanner/Navigator/Zoned

### Tier 4: Polish

12. **Calendar swipe for month navigation** — common iOS expectation
13. **Calendar dismiss delay** — 0.35s hack feels sluggish, explore cleaner sheet transition
14. **Inline edit undo** — at least for category/priority changes (not every keystroke)
15. **Add notification permission feedback** — toast or Settings indicator when denied
16. **Unify stagger timings** — verify intentionality of 60ms (scanner) vs 250ms (navigator) gap

### Resolved Since Last Audit (2026-03-03)

- ~~Recording animation desync~~ — wave rewritten with unified TimelineView + dual harmonics
- ~~Daily Focus shimmer duration~~ — DailyFocus deleted, replaced by cached HomeComposition
- ~~FocusStripView DispatchQueue fragility~~ — FocusStripView replaced by variant-specific focus tabs
- ~~Multiple .animation() on ScrollView~~ — old HomeView with `dailyFocus` references deleted
- ~~DevModeView button ships in release~~ — button display now `#if DEBUG` gated (activator still not)
