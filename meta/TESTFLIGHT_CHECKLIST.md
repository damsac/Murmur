# TestFlight Launch Checklist

Target: ship a TestFlight build within ~2 weeks.
**sac** = Isaac (SwiftUI / frontend). **dam** = backend / MurmurCore / LLM.

---

## 🔴 Blockers — must fix before submitting

### 1. ~~Fix launch screen~~ — ✅ DONE
Shipped in `379f927`. Storyboard with mic icon and "murmur" label. May still want a visual polish pass on real device.

### 2. Tab swipe between Focus ↔ All — **sac** ⚠️ NEEDS DEVICE VERIFY
`TabView(.page)` implemented in `1931934` and `23b46a5`. `SwipeableCard` uses `minimumDistance: .infinity` when no swipe actions exist. **Must verify on a real device** — UIPageViewController behavior differs between simulator and device.

### 3. API key distribution to testers — **dam**
`PPQAPIKey` in `Info.plist` is injected from `project.local.yml` at build time (gitignored). Testers don't have this file. When archiving for TestFlight, the key must be baked in.
**dam**: Confirm which PPQ key testers will share (or provision individual keys), document the archive build process.
**sac**: Make sure the archive step is in the Makefile or documented so the key isn't accidentally omitted.

### 4. ~~Credits: hardcoded token estimates~~ — ✅ DONE
Fixed in `e8a4a46`. `composeHomeView` and `refreshLayout` now return real `TokenUsage`. AppState charges actual token counts. Switched from Sonnet 4.6 to Haiku 4.5 via PPQ. Pricing updated to PPQ Haiku rates ($1.05/$5.25 per 1M tokens).

---

## 🟡 High priority — ship this week

### 5. ~~Calendar view~~ — ✅ DONE
Shipped in PR #97 (`abf950b`, `973a3ce`, `23b46a5`). Monthly grid, habits by cadence, day detail, calendar button in Navigator/Zoned top bars. Entry tap navigates to detail view.

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

### 10. ~~Onboarding flow review~~ — ✅ DONE
Transitions smoothed (subtle offset+opacity, no full-width slide). Demo entries are display-only — "Start capturing" no longer saves them, home starts empty. Skip confirmed clean.

### 11. App icon polish — **sac**
Only a 1024×1024 universal icon is provided. Xcode auto-scales, which is fine, but it's worth exporting 180pt / 120pt / 87pt from the source if the auto-scale looks blurry or off on device. Not a blocker.

### 12. ~~Settings + Archive smoke test~~ — ✅ DONE
Verified: top-up, notification toggles, archive/unarchive, empty archive state all working.

### 13. Crash-free device walkthrough — **dam + sac**
Before any external testers, each person does one full walkthrough on a real device:
- Cold launch → onboarding (first time)
- Cold launch → home with entries (returning user)
- Record a voice note → appears as entries
- Type a note via keyboard input
- Open entry detail → edit summary → save (inline editing, auto-saves)
- Swipe an entry on the All tab → complete / snooze
- Settings → toggle notifications → back
- Archive → tap entry → back → unarchive
- Calendar → tap a day → tap entry → detail opens

### 14. TestFlight metadata — **dam + sac**
Required before the first external invite, none of it is code:
- **dam**: App Store Connect record created under the damsac team. Bundle ID confirmed (`com.damsac.murmur`). Encryption export compliance answered (no encryption beyond HTTPS → answer "No"). Register App Group `group.com.damsac.murmur.shared` as a capability on the App ID in the Developer Portal.
- **sac**: At least 1 screenshot per required device size (can be simulator screenshots). Short beta description written for testers. Privacy nutrition labels filled in for microphone + speech recognition.
- **dam**: Ensure a valid Apple Distribution certificate exists (not just Apple Development).

### 15. Hosted privacy policy URL — **dam**
Required for external TestFlight testers. Apple needs a live, publicly accessible URL — a GitHub Pages one-pager is fine. Without this, you cannot invite external testers.

### 16. ~~Add `ITSAppUsesNonExemptEncryption: false`~~ — ✅ DONE
Added to `project.yml` Info.plist properties.

### 17. ~~Lock interface orientation to portrait~~ — ✅ DONE
`UISupportedInterfaceOrientations` set to portrait-only in `project.yml`.

### 18. ~~Gate DevMode behind `#if DEBUG`~~ — ✅ DONE
`DevModeActivator` wrapped in `#if DEBUG`.

### 19. ~~Privacy manifest — add transcribed text as collected data~~ — ✅ DONE
`PrivacyInfo.xcprivacy` updated to declare user-generated text content.

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
| 1 | ~~Launch screen~~ | **sac** | No | ✅ Done |
| 2 | Tab swipe (Focus ↔ All) | **sac** | No (UX) | ⚠️ Needs device verify |
| 3 | API key distribution | **dam + sac** | No (functional) | Not started |
| 4 | ~~Real token counts~~ | **dam** | No | ✅ Done |
| 5 | ~~Calendar view~~ | **sac** | No | ✅ Done |
| 6 | Notifications real-device test | **sac** | No (QA) | Not started |
| 7 | LLM cost tool (backend + UI) | **dam + sac** | No (feature) | Not started |
| 8 | Empty state in FocusTabView | **sac** | No (UX) | Not started |
| 9 | Wire error views | **sac + dam** | No (UX) | Not started |
| 10 | ~~Onboarding review~~ | **sac** | No (polish) | ✅ Done |
| 11 | App icon polish | **sac** | No (polish) | Not started |
| 12 | ~~Settings + Archive smoke test~~ | **sac** | No (QA) | ✅ Done |
| 13 | Crash-free device walkthrough | **dam + sac** | Soft | Not started |
| 14 | TestFlight metadata + App Store Connect | **dam + sac** | **Yes** | Not started |
| 15 | Hosted privacy policy URL | **dam** | **Yes** (external) | Not started |
| 16 | ~~`ITSAppUsesNonExemptEncryption`~~ | **dam** | **Yes** | ✅ Done |
| 17 | ~~Portrait orientation lock~~ | **dam or sac** | No (looks broken) | ✅ Done |
| 18 | ~~Gate DevMode behind `#if DEBUG`~~ | **dam or sac** | No (exposes tools) | ✅ Done |
| 19 | ~~Privacy manifest — transcribed text~~ | **dam** | **Yes** | ✅ Done |
| 20 | Verify StoreKit degradation | **sac** | Soft | Not started |




