# TestFlight CI Setup

GitHub Actions workflow `.github/workflows/release.yml` ships builds to TestFlight
automatically on push to `main` (internal lane) and on tag push `v*` (external
lane candidate).

## Bundle ID and team context

| | |
|---|---|
| Apple team | damsac (Team ID `98GXNZ6NKZ`) |
| Bundle ID | `com.isaacwm.murmur` |
| App Group | `group.com.isaacwm.murmur.shared` |
| App Store profile name | `Murmur App Store` (must match `provisioningProfiles` dict in workflow's ExportOptions.plist) |

Note: the `damsac` namespace is the GitHub org and the team in App Store
Connect. The bundle ID prefix is Isaac-namespaced because that's what was
registered first; renaming would orphan the existing TestFlight history.

## Pushing a release

### Internal builds (continuous)

Just push to `main`. Every commit triggers a build that:

1. Lands in TestFlight a few minutes after CI green
2. Auto-distributes to internal testers (you + sac) once Apple finishes
   processing — push notification on devices with the TestFlight app

`MARKETING_VERSION` is whatever's in `project.yml` (currently `1.0.0`). Bump it
in source if you want internal builds to track a new version.

### External builds (curated)

Push a semver tag:

```bash
git checkout main && git pull
git tag v1.0.1
git push origin v1.0.1
```

The workflow strips the `v` and overrides `MARKETING_VERSION=1.0.1` at
xcodebuild time. Build number = `github.run_number` (monotonic across all
triggers, no collisions).

After the run, the build is in TestFlight but **not yet visible to externals**.
Open the build in App Store Connect → click "Add Group" → select your external
group → submit for Beta App Review. Apple takes 1–3 days for the first build of
each new MARKETING_VERSION; subsequent builds of the same version usually skip
review.

Note: build number is monotonic across both lanes, so a `main` push between
tag and external review will replace the tag build on internal testers' devices.
Most teams handle this by treating tag builds as fixed release points and not
pushing to main between tagging and external release.

## Required GitHub secrets

Stored in [Settings → Secrets and variables → Actions](https://github.com/damsac/Murmur/settings/secrets/actions).

| Secret | Purpose |
|---|---|
| `APPLE_TEAM_ID` | `98GXNZ6NKZ` |
| `ASC_API_KEY_ID` | App Store Connect API key ID |
| `ASC_API_ISSUER_ID` | ASC issuer UUID |
| `ASC_API_KEY_P8` | Full contents of the `.p8` file (text, not base64) |
| `APPLE_CERT_P12` | base64-encoded Distribution `.p12` (`base64 -i Distribution.p12 \| pbcopy`) |
| `APPLE_CERT_PASSWORD` | Password set when exporting the `.p12` |
| `PPQ_API_KEY` | PPQ.ai key, baked into Info.plist at build time |
| `STUDIO_ANALYTICS_API_KEY_RELEASE` | `sk_murmur` for Release config |

## One-time setup (already done)

These are recorded for reference; they were completed during the initial
pipeline setup and do not need to be repeated.

1. **App Group capability** registered on App ID `com.isaacwm.murmur` in
   [Identifiers](https://developer.apple.com/account/resources/identifiers/list),
   configured to include `group.com.isaacwm.murmur.shared`.
2. **App Store Connect API key** generated with **App Manager** role, `.p8`
   downloaded once and stored in `ASC_API_KEY_P8` secret.
3. **Apple Distribution certificate** generated with a CSR from a developer
   Mac, downloaded `.cer`, installed in the same keychain that holds the
   private key, exported as `.p12` with a password.
4. **App Store provisioning profile** named `Murmur App Store` created at
   [Profiles](https://developer.apple.com/account/resources/profiles), bound to
   `com.isaacwm.murmur` App ID and the Distribution cert from step 3, with App
   Groups capability included.
5. **Internal test group** in App Store Connect set to **automatic
   distribution** so internal testers get every build immediately.

## Signing approach

Archive uses **automatic signing** (`CODE_SIGN_STYLE=Automatic` +
`-allowProvisioningUpdates` + ASC API key). Export uses **manual signing**
(`signingStyle: manual` in `ExportOptions.plist`, explicit `provisioningProfiles`
dict, downloaded profile, imported cert, **no** `-allowProvisioningUpdates` on
the export step).

This split is the production pattern (huynguyencong gist, Bitrise reference
workflow). Apple's docs imply automatic everywhere should work, but cloud
signing rejected our App Manager API key at export time consistently.

## Common pitfalls

When something fails, check these first.

### "Murmur is automatically signed for development, but a conflicting code signing identity ... has been manually specified"

XcodeGen's `application_iOS.yml` preset inserts `CODE_SIGN_IDENTITY = "iPhone
Developer"` at target level. With `CODE_SIGN_STYLE=Automatic`, any explicit
identity (including xcodegen's default) triggers this conflict. The fix is
already in `project.yml`: `CODE_SIGN_IDENTITY: ""` per config. If you ever
modify the codesigning section, keep that override or restore it. Tracking
issue: github.com/yonaskolb/XcodeGen/issues/691.

### "Cloud signing permission error" / "No profiles for ... were found" at export

Apple's cloud signing rejected the API key. Don't pass `-allowProvisioningUpdates`
to the export step. The workflow already uses manual export signing — if you
edit it, keep it that way.

### "No signing certificate iOS Distribution found"

The Distribution `.p12` isn't being imported. Verify `APPLE_CERT_P12` and
`APPLE_CERT_PASSWORD` secrets are set and the `Apple-Actions/import-codesign-certs@v3`
step is present.

### "Provisioning profile X doesn't include signing certificate Y"

The profile is bound to a different Distribution cert. Edit the `Murmur App
Store` profile in the developer portal, check the box next to your current cert
under Certificates, save (regenerates the profile file).

### Build runs but missing entitlements (e.g., App Group)

The provisioning profile's saved revision doesn't include the capability even
though the App ID has it enabled. Edit the profile, confirm the capability
appears under Enabled Capabilities, click Save (regenerates).

### `xcodegen: No such file or directory`

Brew cache restored Cellar files but didn't recreate symlinks. The workflow's
"Install tools" step pairs `brew install || true` with `brew link --overwrite
|| true` to handle this. If you copy this pattern elsewhere, keep both lines.

### Cert export: `.p12` greyed out

Cert and private key are in different keychains. Drag the cert in Keychain
Access from System to login (or vice versa) so they reunite. The `.p12` option
becomes selectable when both are visible together with the disclosure triangle
showing the key beneath the cert.

### `xcodebuild` fast-fail (under ~30 seconds)

Almost always a config error, not a real signing/network issue. Look at the
"Debug build settings" step output to see what xcodebuild resolves for
`CODE_SIGN_*`, `PROVISIONING_*`, `PRODUCT_BUNDLE_IDENTIFIER`, etc. Compare to
expected values.

## Verification after a successful run

1. CI run goes green at [Actions → Release](https://github.com/damsac/Murmur/actions/workflows/release.yml).
2. Build appears in App Store Connect → Apps → Murmur → TestFlight tab. Initial
   state: "Processing" (5-15 min). Confirm:
   - Build number matches `github.run_number`
   - `MARKETING_VERSION` matches expectation (`1.0.0` for main, tag value for tag)
3. After processing, internal testers get a TestFlight push notification.
4. Smoke test on device: launch, record a voice note, confirm an entry is
   created.

For external lane verification, after step 3, manually assign to external group
in App Store Connect and submit for Beta App Review.

## References

- Workflow: `.github/workflows/release.yml`
- Design spec: `docs/superpowers/specs/2026-04-28-testflight-release-pipeline-design.md`
- Production pattern reference: [huynguyencong gist](https://gist.github.com/huynguyencong/004e98e4d9e7671f93fec280ddb7fc18)
- XcodeGen preset issue: [yonaskolb/XcodeGen#691](https://github.com/yonaskolb/XcodeGen/issues/691)
- Apple-Actions used: [import-codesign-certs](https://github.com/Apple-Actions/import-codesign-certs), [download-provisioning-profiles](https://github.com/Apple-Actions/download-provisioning-profiles)
