# TestFlight CI Setup

One-time prerequisites for the `Release` workflow (`.github/workflows/release.yml`).
Once these are done, pushing to `main` ships an internal TestFlight build and
pushing a `v*` tag ships a build that's ready for external beta review.

> **Note on bundle ID:** the bundle ID is `com.isaacwm.murmur` (registered
> under the damsac Apple Developer team). The `damsac` namespace is the
> GitHub org and the team in App Store Connect; the bundle ID prefix
> happens to be Isaac-namespaced because that's what was registered first.
> All instructions below use that bundle ID.

## 1. Register App Group capability on the App ID

The app uses the App Group `group.com.isaacwm.murmur.shared` for sharing data
between the app and any future extensions. Automatic provisioning will fail
unless this is registered as a capability on the App ID itself.

1. Open [Apple Developer → Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Find the App ID `com.isaacwm.murmur` (create it if missing).
3. Edit → check **App Groups** under Capabilities → Configure → add
   `group.com.isaacwm.murmur.shared`.
4. Save.

## 2. Generate an App Store Connect API key

You'll need this for both signing (Apple cloud-generates the Distribution
cert and provisioning profile on demand) and the TestFlight upload.

1. Open [App Store Connect → Users and Access → Integrations → App Store
   Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Generate a new key. **Role: App Manager.** (Developer cannot sign for
   distribution.)
3. Download the `.p8` file immediately — Apple will not let you download it
   again. Note the **Key ID** and the **Issuer ID** shown on the page.

## 3. Configure auto-distribution to internal testers

1. Open the Murmur app in App Store Connect.
2. TestFlight tab → Internal Testing → your group.
3. Enable **automatic distribution** so internal testers get every uploaded
   build immediately.

External testers stay manual: after a tag-triggered build lands in TestFlight,
go to the build, add it to the external group, and submit for Beta App Review.

## 4. Add GitHub repository secrets

[Settings → Secrets and variables → Actions](https://github.com/damsac/Murmur/settings/secrets/actions)
on the repository. Add each as a "Repository secret":

| Secret | Value |
|---|---|
| `APPLE_TEAM_ID` | 10-character team ID (e.g., `ABCD123456`). Find at [Apple Developer → Membership](https://developer.apple.com/account#MembershipDetailsCard). |
| `ASC_API_KEY_ID` | Key ID from step 2 (e.g., `2X9YPDMS47`). |
| `ASC_API_ISSUER_ID` | Issuer UUID from step 2. |
| `ASC_API_KEY_P8` | **Full contents** of the `.p8` file from step 2. Paste the file as text, including the `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----` lines. Do not base64-encode. |
| `PPQ_API_KEY` | The PPQ.ai key that production builds should use. |
| `STUDIO_ANALYTICS_API_KEY_RELEASE` | `sk_murmur` (the Release-config Studio Analytics key). |

## 5. Verify

Push a no-op commit to `main`. Watch the Release workflow run in
[GitHub Actions](https://github.com/damsac/Murmur/actions/workflows/release.yml).
A new build should appear in App Store Connect → TestFlight within a few
minutes of the workflow completing. Internal testers get it automatically.

To ship to externals, push a tag:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The build will land in TestFlight with `MARKETING_VERSION=1.0.1`. Open it in
ASC, add the external group, and submit for Beta App Review.

## Troubleshooting

- **"No profiles for ... were found"** — App Group capability not registered
  on the App ID (step 1) or the API key role is too low (step 2).
- **"Invalid version number"** — TestFlight rejects a build whose
  `MARKETING_VERSION + CURRENT_PROJECT_VERSION` already exists. Build numbers
  come from `github.run_number` so collisions are impossible from CI; if you
  see this, you likely uploaded a colliding build manually from a laptop.
- **"Authentication failed"** on `xcodebuild` — the `.p8` was pasted with
  trailing whitespace stripped or BEGIN/END lines missing. Re-paste the
  entire file verbatim.
- **Workflow fails on tag push with "Tag does not match v<major>.<minor>.<patch>"** —
  use a strict semver tag (`v1.0.0`, not `v1.0` or `release-1.0.0`).
