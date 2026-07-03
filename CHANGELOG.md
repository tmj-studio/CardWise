# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- CloudKit sync enabled: user data now syncs across the user's own devices via the
  iCloud private database (local-only fallback when iCloud is unavailable)

## [1.0.3]

### Added
- Home "Credits to Use" summary card aggregating unused statement credits
- Net annual fee (annual fee minus usable credits) shown in card detail
- Statement-credit data researched and seeded for all annual-fee cards
- `Scripts/` cards.json update pipeline: deterministic validator (`validate_cards.py`),
  SAFE/SUSPICIOUS diff classifier (`diff_cards.py`), pre-push validation hook, and a weekly
  launchd-scheduled orchestrator (`update_cards.sh`) that opens data PRs for human review

### Fixed
- Negative net-fee display; trimmed 3 over-stated Amex Platinum credits

## [1.0.2]

### Added
- Statement-credit catalog (`StatementCredit`) shown in card detail
- Statement-credit usage tracking with partial amounts (`CreditUsage` + CloudStore persistence)
- `CreditPeriod` calendar-key helper with full quarterly-boundary test coverage
- Remote card catalog: fetch `cards.json` from GitHub on launch, validate, and cache for next
  start (`RemoteCatalogService`); cache-first card loading with bundled fallback

### Fixed
- Purge credit usages when a card is removed or all data is cleared
- Corrected Amex Gold fee ($325) and Hilton Aspire earning data

## [1.0.1]

### Added
- Versioned envelope format for the bundled `cards.json` catalog
- `SECURITY.md` and `CODE_OF_CONDUCT.md`

### Changed
- CI release hardening: run on `macos-26` (working `altool`), sign the archive manually to
  stop certificate exhaustion, upload via a direct `xcrun altool --upload-app` call
- App Store metadata aligned with the free/local architecture; encryption exemption declared

## [1.0.0]

First public release — CardWise is **free and fully on-device**.

### Added
- Smart card recommendation engine with support for fixed, rotating, and selectable categories
- 60+ US credit card database, bundled with the app (`cards.json`)
- Spending analytics with chart visualizations
- Receipt scanning via OCR (Vision framework)
- Home screen widget for quick card recommendations
- Merchant-to-category mapping database
- On-device persistence with SwiftData (CloudKit sync entitlement-ready but not yet enabled)
- In-app "update available" nudge and a What's New screen
- `PrivacyInfo.xcprivacy` manifest (no tracking, no data collection)
- CI: build + test + SwiftLint on every PR; auto-upload to TestFlight on every push to `main`

### Removed
- Firebase (Firestore/Auth), the Node.js card-data scraper, and Plaid Link — the app no
  longer depends on any backend or third-party SDK

[Unreleased]: https://github.com/tmj-studio/CardWise/compare/v1.0.3...HEAD
[1.0.3]: https://github.com/tmj-studio/CardWise/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/tmj-studio/CardWise/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/tmj-studio/CardWise/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/tmj-studio/CardWise/releases/tag/v1.0.0
