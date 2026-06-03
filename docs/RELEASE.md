# Releasing CardWise

## Automated TestFlight build (GitHub Actions + fastlane)

Pushing a tag like `v1.0.1` builds that version and uploads it to TestFlight
(`.github/workflows/ios-release.yml` → `fastlane beta`). App Store **submission stays manual**
in App Store Connect.

```bash
# bump the version, commit, then:
git tag v1.0.1
git push origin v1.0.1
```

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
  capabilities are already registered. The workflow uses `-allowProvisioningUpdates`, so Xcode
  creates/refreshes the App Store provisioning profiles automatically via the API key.
- Build number is auto-set to `latest TestFlight build + 1`.
- **First run may need a tweak** (CI signing is fiddly): watch the first `fastlane beta` log. If
  signing fails, the usual fix is confirming the Distribution cert matches Team `K434CK85HW` and
  that the API key has the App Manager role.

## What's New (release notes)

Edit `CardWise/Models/ReleaseNotes.swift` — prepend a `ReleaseNote` for the new version. It is
shown once automatically after users update, and is reachable any time from Settings → What's New.

## Manual fallback

Archive in Xcode (Product → Archive) with automatic signing, then distribute to App Store Connect.
