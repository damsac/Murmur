# Launch UI Readiness Brainstorm
_2026-03-03 — sac_

## Context

Full audit of current UI state vs. what's needed to launch. Goal: cool + appealing without sacrificing usability and simplicity.

---

## What's already solid

The core loop works and looks good: voice → waveform → entries appear → focus strip → swipe to act. The onboarding flow is clean. Category colors are now visually distinct. The recording overlay has nice animation. Swipe gestures are fast and intuitive.

---

## What's missing or weak — tiered by impact

---

### P0 — Blockers (can't launch without)

**Privacy/encryption**
Canon explicitly says "required for production release, not yet implemented." Gates everything. Dam's domain.

---

### P1 — Launch quality (these hurt if absent)

**1. Category simplification**
The roadmap already flags this. Current 8: todo, reminder, habit, idea, note, list, question, thought.

- `thought` is orphaned — no UI paths, color-mapped but not surfaced
- `question` and `list` are rarely distinct enough from `note` to justify their own sections

Proposal: consolidate to 5 — **todo, reminder, habit, idea, note** — and silently map `question`, `list`, `thought` → `note`. Fewer dots on the home screen, cleaner category sections, no decision fatigue. The AI does the categorization; the user sees organized output.

**2. The briefing message is buried**
`DailyFocus` has a `briefingMessage: String?` from the LLM — but there's no UI surface for it. This is the single highest-leverage "wow" moment in the app: an AI that *speaks to you* about your day. Even one line above the focus strip ("3 things need your attention today. The habit streak is going well.") makes Murmur feel alive vs. just a list app.

**3. Launch screen**
None exists. Cold start is a black flash. A simple screen with the wordmark takes an hour and removes a jarring first impression.

**4. Search**
With 30+ entries the home screen becomes unmanageable. A basic full-text search on summary/content — triggered by pull-down or a search icon — is table stakes for a capture app. Without it, old entries effectively disappear.

---

### P2 — Wow factor (differentiating, achievable before launch)

**5. Real recording overlay vs. demo overlay**
Two recording views exist:
- `RecordingStateView` — production: waveform + transcript only
- `LiveFeedRecordingView` — onboarding demo: items materialize in real-time, much richer

The demo is more impressive than the real thing. Users who go through onboarding will notice the gap. Either simplify the demo to match reality, or bring the real recording overlay closer to the demo's richness.

**6. Habit streak UI**
Habits are a strong retention hook but there's no streak display anywhere — not on the card, not in detail view. A "5-day streak" indicator on the habit card would make habits feel rewarding and increase daily opens. The data (`lastHabitCompletionDate` + `cadence`) is all there.

**7. iOS Widget**
Today's focus strip as a lock screen or home screen widget would be the single biggest driver of daily active use — it surfaces the app's value without requiring an open. The data is already there (`DailyFocus` top 3 items). Needs a separate Widget target.

---

### P3 — Post-launch

- Calendar/due date view (entries grouped by "due this week")
- Sharing/collaboration
- VoiceOver accessibility (already on ROADMAP)
- Spotlight integration (search Murmur entries from iOS search)
- Memory management UI (view/edit what the agent knows about you)

---

## The core tension to hold

Murmur's value is **capture speed** and **AI curation** — not feature breadth. Every addition should be tested against: *does this make capturing faster or surfacing better?*

- Search: yes
- Briefing message: yes
- Habit streaks: yes (retention)
- Calendar view: maybe later
- Sharing: definitely later

The risk isn't shipping too little — it's shipping a cluttered app that buries the magic. The mic button + focus strip is the product. Everything else is scaffolding.

---

## Suggested order of attack (UI lane — sac)

| # | Work | Effort | Impact |
|---|------|--------|--------|
| 1 | Launch screen | 1–2h | High perceived quality |
| 2 | Category simplification (8 → 5) | Medium | Reduces clutter, cleaner home screen |
| 3 | Briefing message above focus strip | Small | AI personality, key differentiator |
| 4 | Search (pull-down, filter by content) | Medium | Table stakes for long-term use |
| 5 | Habit streak counter (card + detail) | Small | Retention hook |
| 6 | Real recording overlay polish | Medium | Closes gap with onboarding demo |
| 7 | iOS Widget | Large | Biggest daily-active-use driver |
