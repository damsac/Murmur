# TestFlight Launch Checklist

Target: ship a TestFlight build within ~2 weeks.
**sac** = Isaac (SwiftUI / frontend). **dam** = backend / MurmurCore / LLM.

---

## 🔴 Blockers — must fix before submitting

### 1. Fix launch screen — **sac**
The storyboard (`LaunchScreen.storyboard`) has a mic icon and lowercase "murmur" label centered on a dark background. Needs a visual pass on a real device to make sure it matches the current design language — correct icon weight, purple tint, font, and spacing. Likely a quick fix but highly visible to testers.

### 2. Tab swipe between Focus ↔ All — **sac**
`TabView(.page)` gesture conflicted with `SwipeableCard`'s `DragGesture`. Fix is in progress in the `tab-swipe` lane: `SwipeableCard` now uses `minimumDistance: .infinity` when no swipe actions exist, and the Focus tab passes empty actions so UIPageViewController handles the swipe.
**Must verify on a real device** — UIPageViewController behavior differs between simulator and device. Swipe left/right should switch tabs without accidentally triggering card swipes on the All tab.

### 3. API key distribution to testers — **dam 
`PPQAPIKey` in `Info.plist` is injected from `project.local.yml` at build time (gitignored). Testers don't have this file. When archiving for TestFlight, the key must be baked in.
**dam**: Confirm which PPQ key testers will share (or provision individual keys), document the archive build process.
**sac**: Make sure the archive step is in the Makefile or documented so the key isn't accidentally omitted.

### 4. Credits: hardcoded token estimates — **dam**
`LocalCreditGate` charges a fixed `TokenUsage(inputTokens: 200, outputTokens: 100)` instead of actual tokens from the LLM response. The credit balance display is misleading.
**Fix**: Read the real `usage` field from PPQ API responses in `LLMService`/`PPQLLMService` and pass actual counts to the credit gate. This is purely in MurmurCore.

---

## 🟡 High priority — ship this week

### 5. Calendar view — **dam**
Active work in the `calendar` lane (`Murmur/Views/Calendar/CalendarView.swift`). A calendar icon in the top-left of the home screen opens a monthly/weekly view of entries with due dates.
**Verify**: Entries with due dates appear on the correct day. Overdue entries are visually distinct. Empty state shown when no dated entries exist. Tapping an entry navigates to the detail view.

### 6. Notifications end-to-end verification — **sac**
The `NotificationService` code is complete (reminders, snooze wake-up, due-soon). Needs real-device testing — notifications don't fully fire in the simulator.
**Test checklist**:
- Create a reminder with a near-future due date → notification fires at the right time
- Snooze an entry → wake-up notification fires at snooze expiration
- Tap a notification → app opens and navigates to the correct entry
- Permission prompt appears naturally (first mic tap), not at app launch
- Toggling notification prefs in Settings cancels/reschedules correctly

### 7. LLM cost visibility tool — **dam** (backend) + **sac** (UI)
**dam**: In `LLMService`/`PPQLLMService`, log each LLM call to a capped local record: `(date, inputTokens, outputTokens, estimatedCostUSD)`. Store in UserDefaults (last 50 calls). Expose via a simple `UsageLog` model.
**sac**: Add a hidden "Usage" row in Settings (debug builds only, or always visible for now). Shows total calls, total tokens, and estimated USD spent over the last 7 days. One screen, read-only, no frills.

### 8. Empty state when entries = 0 — **sac**
`SacHomeView.body` was changed to always render `populatedState` (needed to keep `TabView` alive), which disconnected the standalone empty state (pulsing circles + "speak to start").
**Fix**: Move the empty-state content inside `FocusTabView`. If there are no focus items, no loading, and no composition, show the pulsing mic prompt there. The All tab handles its own empty case already.

---

## 🟢 Nice-to-have — if time allows

### 9. Wire up existing error views — **sac** (UI) + **dam** (trigger conditions)
Error views already exist in `Murmur/Views/Errors/` but most production paths silently fall back to deterministic UI:
- **sac**: If the API key is missing/invalid → show `APIErrorView` instead of a silent empty Focus tab
- **sac**: `OutOfCreditsView` — verify it actually fires when balance hits zero (it exists, check it's wired)
- **dam**: Add a clear error signal when PPQ returns auth/quota errors so the UI can surface them

### 10. Onboarding flow review — **sac**
Run the full 4-screen flow from a cold-launch (wipe `hasCompletedOnboarding` in UserDefaults). Verify:
- Demo entries (reminder, todo, idea) look correct in the current card style
- Skip leaves no broken state
- After onboarding, the home screen shows the 3 saved demo entries

### 11. App icon polish — **sac**
Only a 1024×1024 universal icon is provided. Xcode auto-scales, which is fine, but it's worth exporting 180pt / 120pt / 87pt from the source if the auto-scale looks blurry or off on device. Not a blocker.

### 12. Settings + Archive smoke test — **sac**
Quick tap-through:
- Top-up opens `TopUpView` without crashing
- Notification toggles persist across an app restart
- Archive opens, shows archived entries, un-archive works
- Empty archive shows an empty state (not a crash)

### 13. Crash-free device walkthrough — **dam + sac**
Before any external testers, each person does one full walkthrough on a real device:
- Cold launch → onboarding (first time)
- Cold launch → home with entries (returning user)
- Record a voice note → appears as entries
- Type a note via keyboard input
- Open entry detail → edit summary → save
- Swipe an entry on the All tab → complete / snooze
- Settings → toggle notifications → back
- Archive → tap entry → back → unarchive

### 14. TestFlight metadata — **dam + sac**
Required before the first external invite, none of it is code:
- **dam**: App Store Connect record created under the damsac team. Bundle ID confirmed (`com.damsac.murmur`). Encryption export compliance answered (no encryption beyond HTTPS → answer "No"). Register App Group `group.com.damsac.murmur.shared` as a capability on the App ID in the Developer Portal.
- **sac**: At least 1 screenshot per required device size (can be simulator screenshots). Short beta description written for testers. Privacy nutrition labels filled in for microphone + speech recognition.
- **dam**: Ensure a valid Apple Distribution certificate exists (not just Apple Development).

### 15. Hosted privacy policy URL — **dam**
Required for external TestFlight testers. Apple needs a live, publicly accessible URL — a GitHub Pages one-pager is fine. Without this, you cannot invite external testers.

### 16. Add `ITSAppUsesNonExemptEncryption: false` — **dam**
One-line addition to `project.yml` Info.plist properties. Without it, App Store Connect prompts for export compliance manually on every single upload. The app only uses standard HTTPS — this is exempt.

### 17. Lock interface orientation to portrait — **dam or sac**
No explicit `UISupportedInterfaceOrientations` is set. Without it the app rotates to landscape, which will look broken. Add to `project.yml` build settings or Info.plist properties.

### 18. Gate DevMode behind `#if DEBUG` — **dam or sac**
The 5-tap gesture opens dev tools for all users including TestFlight testers. Wrap `DevModeActivator` and `DevModeView` in `#if DEBUG` so it doesn't ship in release builds.

### 19. Privacy manifest — add transcribed text as collected data — **dam**
`PrivacyInfo.xcprivacy` declares `AudioData` collection but the app also sends transcribed text to `api.ppq.ai`. Apple reviewers may flag this. Consider adding a collected data type for user-generated text content.

### 20. Verify StoreKit graceful degradation — **sac**
IAP products (credit packs) may not exist in App Store Connect for the first beta. Verify the app doesn't crash or show broken UI when StoreKit returns no products. If it doesn't degrade gracefully, either fix it or remove the StoreKit scheme config for beta.

---

## Out of scope for this sprint

- iCloud sync / account system (local-only is fine for beta)
- iPad support
- Widgets, Share extension, Siri
- Export (CSV, PDF)
- Real-time collaboration

---

## Summary table

| # | Item | Owner | Apple Req? | Status |
|---|------|-------|-----------|--------|
| 1 | Fix launch screen | **sac** | No (polish) | Not started |
| 2 | Tab swipe (Focus ↔ All) | **sac** | No (UX bug) | In progress |
| 3 | API key distribution | **dam + sac** | No (functional) | Not started |
| 4 | Real token counts for credits | **dam** | No (feature) | Not started |
| 5 | Calendar view | **dam** | No (feature) | In progress |
| 6 | Notifications real-device test | **sac** | No (QA) | Not started |
| 7 | LLM cost tool (backend) | **dam** | No (feature) | Not started |
| 7 | LLM cost tool (UI) | **sac** | No (feature) | Not started |
| 8 | Empty state in FocusTabView | **sac** | No (UX) | Not started |
| 9 | Wire error views | **sac + dam** | No (UX) | Not started |
| 10 | Onboarding review | **sac** | No (polish) | Not started |
| 11 | App icon polish | **sac** | No (polish) | Not started |
| 12 | Settings + Archive smoke test | **sac** | No (QA) | Not started |
| 13 | Crash-free device walkthrough | **dam + sac** | Soft (crashes = rejection) | Not started |
| 14 | TestFlight metadata + App Store Connect | **dam + sac** | **Yes** | Not started |
| 15 | Hosted privacy policy URL | **dam** | **Yes** (external testers) | Not started |
| 16 | `ITSAppUsesNonExemptEncryption: false` | **dam** | **Yes** | Not started |
| 17 | Portrait orientation lock | **dam or sac** | No (but will look broken) | Not started |
| 18 | Gate DevMode behind `#if DEBUG` | **dam or sac** | No (but exposes dev tools) | Not started |
| 19 | Privacy manifest — transcribed text | **dam** | **Yes** (may cause rejection) | Not started |
| 20 | Verify StoreKit graceful degradation | **sac** | Soft (crashes = rejection) | Not started |
