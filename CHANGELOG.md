# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0]

First public release — CardWise is **free and fully on-device**.

### Added
- Smart card recommendation engine with support for fixed, rotating, and selectable categories
- 60+ US credit card database, bundled with the app (`cards.json`)
- Spending analytics with chart visualizations
- Receipt scanning via OCR (Vision framework)
- Home screen widget for quick card recommendations
- Merchant-to-category mapping database
- On-device persistence with SwiftData, synced across the user's devices via CloudKit
- In-app "update available" nudge and a What's New screen
- `PrivacyInfo.xcprivacy` manifest (no tracking, no data collection)
- CI: build + test + SwiftLint on every PR; auto-upload to TestFlight on every push to `main`

### Removed
- Firebase (Firestore/Auth), the Node.js card-data scraper, and Plaid Link — the app no
  longer depends on any backend or third-party SDK

[Unreleased]: https://github.com/tmj-studio/CardWise/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tmj-studio/CardWise/releases/tag/v1.0.0
