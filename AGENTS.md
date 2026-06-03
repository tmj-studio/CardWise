# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CardWise is an iOS app that helps users maximize credit card rewards by recommending the best card for each purchase. Features include:
- Credit card reward tracking (fixed, rotating, selectable categories)
- Smart card recommendations based on merchant/category
- Spending tracking and analytics
- Support for US credit card issuers

The app is **free and fully local** — no accounts, no backend. User data lives on-device
via SwiftData and syncs across the user's own devices through CloudKit. The credit-card
reward database ships bundled with the app (`CardWise/Resources/cards.json`).

## Tech Stack

- **Platform**: iOS 17+ (iPhone only)
- **UI Framework**: SwiftUI
- **Architecture**: MVVM
- **Persistence**: SwiftData + CloudKit (private database) via `CloudStore`
- **Project generation**: XcodeGen (`project.yml` is the source of truth)
- **Language**: Swift 5.9
- **Dependencies**: none (no SPM packages; no Firebase/Plaid/StoreKit)

## Build and Development

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonsm/XcodeGen):

```bash
brew install xcodegen   # once
xcodegen generate       # regenerate CardWise.xcodeproj after editing project.yml
open CardWise.xcodeproj
```

Run tests from the command line:

```bash
xcodebuild test -project CardWise.xcodeproj -scheme CardWise \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Edit build settings, bundle ids, entitlements and the marketing version in `project.yml`,
**not** in the generated `.xcodeproj`.

## Architecture

```
CardWise/
├── App/                    # App entry point (CardWiseApp.swift)
├── DesignSystem/           # Shared colors, typography, components
├── Models/                 # Data models
│   ├── CreditCard.swift    # Card, rewards, rotating/selectable configs
│   ├── Spending.swift      # Transaction records
│   ├── SpendingCategory.swift
│   └── Merchant.swift      # Merchant → category mapping
├── Views/                  # SwiftUI views (MVVM View layer)
│   ├── Home/ Cards/ Spending/ Recommend/ Settings/
├── ViewModels/             # State management (CardViewModel, SpendingViewModel)
├── Services/               # Business logic
│   ├── CloudStore.swift        # SwiftData + CloudKit persistence
│   ├── CardCatalog.swift       # Loads bundled cards.json (read-only catalog)
│   ├── RecommendationEngine.swift
│   ├── OCRService.swift        # Receipt scanning (Vision)
│   ├── NotificationService.swift
│   ├── AppUpdateChecker.swift  # In-app "update available" nudge
│   ├── WidgetDataManager.swift # Shares data with the widget via app group
│   └── …
├── Resources/
│   └── cards.json          # Bundled read-only reward database
└── Utils/
    └── Extensions.swift    # Color hex, Date helpers

CardWiseWidget/             # Home-screen widget (app-extension)
CardWiseTests/              # Unit tests
fastlane/                   # Release automation (Fastfile → `beta` lane)
```

## Key Components

### RecommendationEngine
Calculates best card for a category considering:
- Fixed category bonuses
- Rotating quarterly categories (activation status)
- User-selectable categories
- Spending caps

### Credit Card Types
- **Fixed categories**: Always earn bonus (e.g., Amex Gold 4x dining)
- **Rotating categories**: Quarterly bonuses requiring activation (e.g., Chase Freedom Flex)
- **Selectable categories**: User-chosen bonus category (e.g., BoA Customized Cash)

## Data Flow

1. User selects category or enters merchant name
2. `MerchantDatabase` maps merchant → category
3. `RecommendationEngine` evaluates all user cards
4. Results sorted by estimated reward value

## CI / Release

- **`.github/workflows/ci.yml`** — builds and runs tests + SwiftLint on every PR and on
  pushes to non-main branches.
- **`.github/workflows/ios-release.yml`** — on every push to `main`, builds a signed
  App Store archive and uploads a new build to TestFlight / App Store Connect (build number
  auto-increments; marketing version comes from `project.yml`). **Submission for review stays
  manual** in App Store Connect. See `docs/RELEASE.md` for secrets and the signing flow.
