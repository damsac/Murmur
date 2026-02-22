# Murmur — Market Research & Competitive Analysis

> Written from the perspective of a founder with an early MVP. Current date: February 2026.

---

## What Murmur Does (MVP Summary)

Murmur is a voice-first capture app. You speak, the app transcribes your words, an LLM extracts structured entries (todos, reminders, ideas, notes, habits, questions, thoughts), and those entries live in an organized feed. You can archive, snooze, and view details for each entry.

**Core loop:** Voice → Transcription (Apple Speech) → LLM extraction (Claude via PPQ.ai) → Structured entries in SwiftData → Home feed

---

## Competitive Landscape

### Category 1: Meeting & Voice Transcription Tools

These tools transcribe conversations, not individual voice captures.

| App | What it does | Weakness vs. Murmur |
|-----|-------------|---------------------|
| **Otter.ai** | Meeting transcription, speaker diarization, summaries | Built for meetings, not personal capture. No structured extraction to task/habit/idea types. |
| **Fireflies.ai** | Meeting notes, CRM integrations, action item detection | Enterprise-focused, heavy integration layer. Not personal ambient use. |
| **Notion AI** / **Mem** | AI-enhanced note-taking, meeting transcription plugin | Still fundamentally a note editor — doesn't vanish after capture. |
| **Whisper (OpenAI)** | Best-in-class open source transcription | Just transcription — no extraction, no structure, no app. |

**Murmur's edge here:** Nobody else treats a single spoken sentence as a first-class object that gets categorized, tagged, snoozed, and managed independently.

---

### Category 2: Voice-to-Content / Voice Note Apps

These are the closest competitors to Murmur's core experience.

| App | What it does | Weakness vs. Murmur |
|-----|-------------|---------------------|
| **Limitless** | Wearable + app that captures everything you say/hear all day | Passive capture — records everything vs. intentional trigger. Privacy-first concern. No structured extraction. |
| **Plaud Note** | AI pin that records and summarizes | Hardware-dependent, again passive/meeting-oriented. |
| **AudioPen** | Voice → cleaned-up written note (text reformatting only) | No categorization. Output is a blob of text, not structured entries. Single-type output. |
| **Cleft Notes** / **Voicenotes.app** | Simple voice journaling with transcription | Journaling use case, no task extraction or actionability. |
| **Superwhisper** | macOS dictation replacement | Desktop only, no structured extraction. |

**Murmur's edge here:** Murmur is the only one treating voice as the input to a structured intelligence layer — not just a transcription or a clean note.

---

### Category 3: AI Task Managers & Personal Productivity

These are apps that try to organize your life with AI assistance.

| App | What it does | Weakness vs. Murmur |
|-----|-------------|---------------------|
| **Todoist AI** | AI-assisted task creation from natural language | Text-first, not voice-first. Still requires intentional task framing. One type only (tasks). |
| **Reclaim.ai** / **Motion** | AI calendar scheduling and task prioritization | Requires structured input. Scheduling-layer tool, not capture. |
| **Things 3** / **OmniFocus** | Premium task management | Zero AI extraction. Manual entry. |
| **Reflect Notes** | AI-enhanced networked notes | Networked PKM, not a quick-capture or voice tool. |
| **Apple Reminders / Notes** | Built-in, Siri integration | Siri can set reminders but extracts only one thing at a time. No multi-entity extraction in a single utterance. |

**Murmur's edge here:** Multi-entity extraction in a single utterance is genuinely novel. Saying "Remind me to call the dentist Thursday, and I had an idea for an app that scans receipts" and getting two separate, correctly-categorized, independently-actionable entries is not something any of these tools do.

---

## Honest MVP Assessment

### What's Working
- **The core magic is real.** Multi-entity voice extraction into typed entries is genuinely impressive and differentiated.
- **Progressive disclosure UX.** The app revealing more features as users add entries is thoughtful and reduces first-launch overwhelm.
- **Category intelligence.** Having 8 entry types (todo, reminder, idea, note, habit, question, thought, list) that are correctly identified from natural speech is strong.
- **Dark, minimal aesthetic.** The visual design is clean and premium-feeling.

### What's Missing (Honest Gaps)

| Gap | Impact | Priority |
|-----|--------|----------|
| **No push notifications for reminders/snooze wake-ups** | Snooze and due dates are inert — no real-world signal | 🔴 Critical |
| **No search** | Users can't find entries. With >20 entries, the app becomes unusable as a knowledge store | 🔴 Critical |
| **No home screen widget** | Quick voice capture requires unlocking the app. Frictionless capture is the whole value prop | 🔴 High |
| **No "ask your entries" feature** | Can't query: "What did I say about the dentist?" Closes the loop on the intelligence layer | 🟡 High |
| **No habit tracking / completion** | Habits are captured but there's no check-in or streak logic | 🟡 Medium |
| **No sharing or export** | Ideas and lists can't leave the app | 🟡 Medium |
| **No onboarding demonstration** | Users don't know what to say or what multi-entity extraction looks like | 🟡 Medium |
| **No recurring reminders** | Time-based reminders fire once (when they fire at all, given the notification gap) | 🟠 Medium |
| **macOS / watchOS missing** | Voice capture on Apple Watch would be the killer surface | 🟠 Lower |
| **No pricing / paywall** | Can't ship to the App Store without a plan | 🟠 Ship blocker |

---

## What to Build Next (Prioritized)

### P0 — Make the current features actually work end-to-end

1. **Push notifications for snooze + due dates** (`UNUserNotificationCenter`)
   - Without this, snooze and reminders are theater.

2. **Search bar** over entries
   - Full-text search on `summary`, `content`, and `transcript`.

### P1 — Close the voice capture loop

3. **Dynamic Island / Lock Screen widget** for one-tap capture
   - This reduces tap-to-capture to 1 step from outside the app.

4. **Apple Watch app** — tap crown, speak, done
   - This is where Murmur beats every competitor. A watch app for ambient brain dumps is the killer feature.

### P2 — Activate the intelligence layer

5. **"Ask your entries" voice query**
   - User speaks a question, app searches and summarizes relevant entries using the LLM.
   - Example: "What were my ideas last week?" → surfaced list.
   - This turns Murmur into a personal knowledge base, not just a capture tool.

6. **Habit check-ins and streaks**
   - Daily notification, tap to log, streak counter on the home screen.

### P3 — Monetization & Growth

7. **Subscription pricing**
   - Free tier: 10 captures/month (LLM calls cost money)
   - Pro tier: $4.99/month unlimited captures + habit tracking + widget

8. **Shareable entry cards**
   - Export an idea or list as a clean image for social sharing → growth loop.

---

## Positioning Recommendation

**Murmur should own: "The app that empties your mind."**

The enemy is the mental overhead of keeping track of things. Murmur's promise is that you can speak anything — fragmented, half-formed, multi-topic — and it will sort it out. You don't have to think before you speak. That's the opposite of every other productivity app that asks you to conform to its schema.

**Tagline candidates:**
- *"Speak. It handles the rest."*
- *"Your brain, organized."*
- *"Don't think. Say it."*

**Target user:** Knowledge workers, entrepreneurs, ADHD users, and anyone who's ever said "I'll remember that" and didn't. The core insight is that the cost of capture friction is 100% of the idea — if you don't capture it in the moment, it's gone.

**Differentiation in one sentence:** Murmur is the only app where you can say three unrelated things in one breath and get three separate, correctly-typed, independently-actionable entries — without touching your phone.

---

## Market Size & Opportunity

- Productivity app market: ~$100B globally, growing
- Voice interface adoption accelerating post-AirPods, Apple Watch
- LLM capability makes this possible at consumer scale for the first time (2023+)
- No direct competitor has nailed the "voice → structured multi-entity" primitive
- **Window of opportunity:** 12–18 months before Apple builds this into Siri natively

---

## Key Risk

**Apple.** Siri + Apple Intelligence could absorb this entire use case natively within 2 iOS releases. The defensible moat is: category granularity (8 types vs. Siri's task/reminder binary), cross-entry intelligence (the "ask your entries" feature), and the community/brand built before Apple catches up.
