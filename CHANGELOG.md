# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Renamed project from SmartCard to **CardWise** across all docs, CI, and metadata

### Added
- Open source community files (LICENSE, CODE_OF_CONDUCT, SECURITY, CHANGELOG)
- CI/CD workflows for PR checks
- CODEOWNERS for automatic reviewer assignment
- Dependabot configuration for dependency updates

## [0.1.0] - 2025-01-01

### Added
- Smart card recommendation engine with support for fixed, rotating, and selectable categories
- 60+ US credit card database with accurate reward tracking
- Spending analytics with chart visualizations
- Receipt scanning via OCR (Vision framework)
- Home screen widget for quick card recommendations
- Firebase Cloud Sync for card data
- Merchant-to-category mapping database
- Credit card data scraper infrastructure (Node.js + Puppeteer)
  - Per-issuer scrapers (Chase, Amex, Capital One, Citi, Discover, Wells Fargo, Bank of America, US Bank)
  - Automated image URL validation
  - Data validation and Firestore upload utilities
- GitHub Actions monthly scraper workflow
- Issue and PR templates
- Contributing guide

### Fixed
- Amex card image URL updates
- Image URL validation with GET+Range header checks
- Duplicate category detection with note support
- Plaid Link not opening after loading

[Unreleased]: https://github.com/Rich627/SmartCard/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Rich627/SmartCard/releases/tag/v0.1.0
