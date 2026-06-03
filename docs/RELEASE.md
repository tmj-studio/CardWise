# Releasing CardWise

## Automated TestFlight build (GitHub Actions + fastlane)

**Every push to `main`** builds the app and uploads a new build to TestFlight / App Store
Connect (`.github/workflows/ios-release.yml` → `fastlane beta`). The build number
auto-increments; the marketing version comes from `MARKETING_VERSION` in `project.yml`.
App Store **submission for review stays manual** in App Store Connect — that step is yours.

```bash
# normal change: just merge/push to main → CI builds and uploads automatically.

# shipping a new App Store version: bump the version first, then push.
#   edit project.yml → MARKETING_VERSION: "1.0.1"
git commit -am "release: 1.0.1" && git push origin main
```

You can also trigger a build by hand from **Actions → iOS Release (TestFlight) → Run workflow**
(`workflow_dispatch`).

### Submitting for review (manual, in App Store Connect)

1. Wait for the build to finish processing in App Store Connect (a few minutes after CI).
2. Open the app version → select the new build.
3. Fill in any required metadata / screenshots (see `AppStore/AppStoreMetadata.md`).
4. Click **Add for Review** → **Submit**.

### One-time setup — GitHub repo secrets

You must create these yourself (they are credentials; they cannot be generated for you).
Add them under **Settings → Secrets and variables → Actions**:

| Secret | What it is | How to get it |
|--------|------------|---------------|
| `ASC_KEY_ID` | App Store Connect API key ID | App Store Connect → Users and Access → Integrations → App Store Connect API → generate a key (Admin/App Manager). Copy the Key ID. |
| `ASC_ISSUER_ID` | API issuer ID | Same page, shown above the keys list. |
| `ASC_KEY_P8_BASE64` | the `.p8` key file, base64 | Download the `.p8` once, then `base64 -i AuthKey_XXXX.p8 \| pbcopy`. |
| `DIST_CERT_P12_BASE64` | Apple Distribution cert + private key | In Xcode/Keychain export your "Apple Distribution" identity as `.p12`, then `base64 -i dist.p12 \| pbcopy`. |
| `DIST_CERT_PASSWORD` | password for the `.p12` | Whatever you set on export (use a non-empty one). |

Notes:
- The App ID (`studio.tmj.cardwise`) + widget (`studio.tmj.cardwise.widget`) and their
  capabilities are already registered.
- Build number is auto-set to `latest TestFlight build + 1`.
- **Signing flow:** the lane *archives* with automatic signing (`-allowProvisioningUpdates`
  refreshes profiles via the API key) and *exports* with manual signing using App Store
  profiles fetched by `sigh`. Exporting manually avoids the "Cloud signing permission error"
  that automatic export hits when the API key can't mint cloud-managed certificates.
- The API key needs the **App Manager** (or Admin) role, and the Distribution cert in
  `DIST_CERT_P12_BASE64` must belong to Team `K434CK85HW`.

## What's New (release notes)

Edit `CardWise/Models/ReleaseNotes.swift` — prepend a `ReleaseNote` for the new version. It is
shown once automatically after users update, and is reachable any time from Settings → What's New.

## Manual fallback

Archive in Xcode (Product → Archive) with automatic signing, then distribute to App Store Connect.
