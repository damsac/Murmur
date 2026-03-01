# Dam's State

What dam is working on right now. Updated with every PR.

---

## Current focus

- Cleaned up Settings view (#26): removed placeholder sections (AI Backend, Views, Data, About), kept only Credits + Notifications
- Redesigned Settings UI: balance hero at top, notification toggle chips (tappable icons instead of toggle switches), capsule CTA for top-up

## Recent decisions

- Settings should only show functional sections — no placeholders
- Balance hero + "Get More Credits" grouped at top (credits are the primary settings concern)
- Notification toggles replaced with tappable icon chips — more compact, more visual
- Added `SettingsGroup` and `SettingsGroupDivider` components for iOS-style grouped rows
- `cancelRecording()` over `stopRecording()` in agent path (speed over completeness)

## Open questions

- How does sac want to structure their PROCESS.md? (Sac should fill in their own)
- Should notification chips have any additional visual feedback (haptic, scale animation)?
- Settings will need sections back when features mature (export, clear data, about) — add them when they're real

## What I need from sac

- Review and agree on the CANON.md decisions (roles, branch model)
- Fill in `meta/sac/PROCESS.md` and `meta/sac/STATE.md`
- Feedback on notification chip pattern — does it feel right on device?
