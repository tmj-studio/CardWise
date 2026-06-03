# Release & Update Experience — Design

Date: 2026-06-03
Status: Approved

## Goal
Add three release-related capabilities to CardWise plus finish the App Store launch:
1. **In-app "update available" nudge** — gentle, dismissible, backend-free.
2. **"What's New" screen** — shown once after the app updates; content bundled in the app.
3. **CI/CD release pipeline** — GitHub Actions + fastlane, builds and uploads to TestFlight on a git tag.

## Constraints
- App is free / local-first, **no backend**. Version discovery must not require a server.
- Bundle ID `studio.tmj.cardwise`, Team `K434CK85HW`, App Store Connect app `6776198130`.
- Match existing patterns: `@AppStorage`, `Theme` design system, XCTest. New files under `CardWise/` and `CardWiseTests/` are auto-picked up by `xcodegen generate`.

## 1. Version tracking core
`CardWise/Utils/AppVersion.swift`:
- `AppVersion.current` → `CFBundleShortVersionString`.
- `AppVersion.compare(_:_:)` → dotted-version semantic compare (pads missing components, tolerates junk).
- `AppVersion.isNewer(_:than:)` convenience.
Pure, fully unit-tested.

## 2. What's New (bundled)
`CardWise/Models/ReleaseNotes.swift`:
- `ReleaseNote(version, highlights:[String])`, newest-first `ReleaseNotes.all` (edited each release).
- `WhatsNew.notesToPresent(lastSeen:current:)` → notes for versions in `(lastSeen, current]`; returns `[]` for fresh installs (empty `lastSeen`) or when not upgraded. Pure, tested.

`CardWise/Views/WhatsNew/WhatsNewView.swift`: purple hero-gradient header + checkmark highlight list + Continue button. Reused by Settings.

Integration in `CardWiseApp` (MainTab branch only): on `.task`, compute notes, present sheet if non-empty, then set `@AppStorage("lastSeenVersion") = AppVersion.current`. Fresh installs go through onboarding and never see What's New for the install version.

Settings gets a "What's New" row that re-opens the current version's notes.

## 3. Update nudge (iTunes Lookup)
`CardWise/Services/AppUpdateChecker.swift` (`@MainActor ObservableObject`):
- Queries `https://itunes.apple.com/lookup?bundleId=studio.tmj.cardwise&country=us`.
- `parse(_:Data)` → `{version, trackViewUrl}` (tested with fixtures).
- `shouldPrompt(installed:store:dismissed:)` → store newer than installed AND not the dismissed version (tested).
- Rate-limited to once / 24h via `@AppStorage("update.lastCheck")`; dismissals remembered via `@AppStorage("update.dismissedVersion")`.
- Network failure or app-not-on-store → silent no-op (safe before launch).
- UI: dismissible `.alert` — **Update** (opens `trackViewUrl`) / **Later**.

## 4. CI/CD (GitHub Actions + fastlane → TestFlight on tag)
- `fastlane/Fastfile` `beta` lane: build number = `latest_testflight_build_number + 1`, build signed archive (`gym`), `upload_to_testflight`.
- Signing **without match**: ASC API key (`.p8` base64, key id, issuer id) for auth + upload; distribution cert (`.p12` base64 + password) imported into a temp keychain; `sigh` fetches/creates the provisioning profile via the API key.
- `.github/workflows/ios-release.yml`: `on: push: tags: ['v*']`; macOS runner; selects Xcode; `xcodegen generate`; `bundle exec fastlane beta`; `MARKETING_VERSION` from the tag.
- App Store submission stays **manual** in ASC.
- Required GitHub secrets (documented for the user to add): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `DIST_CERT_P12_BASE64`, `DIST_CERT_PASSWORD`.

## 5. Finish the launch (operational)
Tag `v1.0.0` → CI uploads first build to TestFlight → in ASC fill metadata/keywords, age rating 4+, Free pricing, upload the 4 marketing screenshots, attach build, submit for review (browser-driven where possible).

## Testing
TDD on pure logic: `AppVersion` compare, `WhatsNew.notesToPresent`, `AppUpdateChecker.shouldPrompt` + `parse`. CI/signing verified via documented dry-run (needs real secrets).

## Out of scope (YAGNI)
Forced/blocking updates, remote-config changelog, staged rollouts, automated App Store submission.
