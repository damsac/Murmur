# Release Readiness Audit

**Date:** 2026-03-10
**Scope:** Full codebase scan for blockers, missing features, and production-readiness gaps
**Note:** Onboarding flow polish is explicitly deferred until UI is finalized.

---

## Blockers (must fix before any release)

| # | Issue | Location |
|---|-------|----------|
| 1 | **DevMode ships in production** — 5-tap gesture opens dev tools for all users | `DevMode/DevModeActivator.swift`, `DevMode/DevModeView.swift` — wrap in `#if DEBUG` |
| 2 | **API key exposed in IPA** — PPQ key is plaintext in Info.plist, extractable in 30s | `project.yml:61` — needs server-side proxy before production |
| 3 | **Encryption at rest not implemented** — CANON.md flags this as required for production; all SwiftData entries stored plaintext | `Murmur/Shared/PersistenceConfig.swift` |
| 4 | **Missing `ITSAppUsesNonExemptEncryption: false`** — TestFlight prompts export compliance on every upload without it | Add to `project.yml` info properties |

---

## Important (should fix before shipping)

| # | Issue | Location |
|---|-------|----------|
| 5 | **LLM pricing mismatch** — credits deduct at Haiku rates ($1/$5) but running Sonnet ($3/$15), bleeding ~3x real cost | `AppState.swift:86-97` (3 hardcoded locations) |
| 6 | **~10 `print()` calls in production code paths** | `AppState.swift`, `AgentActionExecutor.swift`, `EntryDetailView.swift:274`, `RootView.swift:549`, others |
| 7 | **No launch screen** — app cold-starts with a black flash | `project.yml` — `UILaunchScreen` dict exists but no custom view |
| 8 | **Release signing untested** — only `"Apple Development"` specified; archive builds rely on Automatic Signing implicitly | `project.yml:16-17` |
| 9 | **Build number not automated** — must manually bump `CURRENT_PROJECT_VERSION` before every TestFlight upload | `project.yml:47` |
| 10 | **Privacy Policy & Terms of Service missing from Settings** — legal requirement for App Store | `Views/Settings/SettingsFullView.swift` |
| 11 | **Data save failures silently swallowed** — entry save errors print to console, no user-facing message | `EntryDetailView.swift:274`, `RootView.swift:549` |

---

## Nice to have (can defer post-launch)

- **Category consolidation (8 → 5)** — `thought`, `question`, `list` are rarely distinct; ROADMAP flags as "Up Next" — `Packages/MurmurCore/Sources/MurmurCore/Enums.swift`
- **Briefing message UI** — `HomeComposition.briefing` is populated by the LLM but never displayed in any home view
- **Full-text search** — no search at all; becomes a real problem with 30+ entries
- **Habit streak display** — data exists (`lastHabitCompletionDate`), no UI surface for it
- **Real recording overlay ≠ onboarding demo** — `LiveFeedRecordingView` is richer than production `RecordingView`; gap is noticeable
- **iOS widget** — focus strip as lock screen widget; biggest driver of daily retention

---

## Already good

- Settings view fully wired (credits, top-up, notifications, archive)
- StoreKit integrated with local test config (`Murmur.storekit`)
- Entitlements correct: microphone, speech recognition, app group
- App icon present (1024×1024 in `Assets.xcassets`)
- Onboarding flow exists and saves demo entries (polish deferred)
- Empty states covered in list and archive views
- Notification preferences functional (reminders, due soon, snooze wake-up)
- Schema versioning in place (`schemaVersion = 4`, deletion migration for early alpha)
- Privacy usage strings present in Info.plist (mic + speech recognition)

---

## Recommended ship sequence

**Before TestFlight:**
- [ ] Gate DevMode behind `#if DEBUG` (#1)
- [ ] Add `ITSAppUsesNonExemptEncryption: false` to project.yml (#4)
- [ ] Wrap production `print()` calls with `#if DEBUG` (#6)
- [ ] Test one archive build manually with Automatic Signing (#8)
- [ ] Document build number bump process (#9)

**Before production:**
- [ ] Implement encryption at rest (#3)
- [ ] Replace plaintext API key with server-side proxy (#2)
- [ ] Fix pricing mismatch — update to Sonnet rates or switch to Haiku (#5)
- [ ] Add launch screen (#7)
- [ ] Add Privacy Policy & Terms of Service links in Settings (#10)
- [ ] Show user-facing error on data save failure (#11)
