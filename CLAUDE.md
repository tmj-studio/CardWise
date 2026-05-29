# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CardWise is an iOS app that helps users maximize credit card rewards by recommending the best card for each purchase. Features include:
- Credit card reward tracking (fixed, rotating, selectable categories)
- Smart card recommendations based on merchant/category
- Spending tracking and analytics
- Support for US credit card issuers

## Tech Stack

- **Platform**: iOS (iPhone only)
- **UI Framework**: SwiftUI
- **Architecture**: MVVM
- **Backend**: Firebase Firestore
- **Auth**: Firebase Auth (optional)
- **Language**: Swift
- **Scraper**: Node.js + Puppeteer (in `Functions/scraper/`)

## Build and Development

Open `CardWise.xcodeproj` in Xcode (requires Xcode 15+).

To create the Xcode project:
1. Open Xcode → File → New → Project
2. Select iOS → App
3. Product Name: CardWise
4. Interface: SwiftUI, Language: Swift
5. Add all files from `CardWise/` directory to the project

## Architecture

```
CardWise/
├── App/                    # App entry point
├── Models/                 # Data models
│   ├── CreditCard.swift    # Card, rewards, rotating/selectable configs
│   ├── Spending.swift      # Transaction records
│   ├── SpendingCategory.swift
│   └── Merchant.swift      # Merchant → category mapping
├── Views/                  # SwiftUI views (MVVM View layer)
│   ├── Home/
│   ├── Cards/
│   ├── Spending/
│   ├── Recommend/
│   └── Settings/
├── ViewModels/             # State management
│   ├── CardViewModel.swift
│   └── SpendingViewModel.swift
├── Services/               # Business logic
│   ├── FirebaseService.swift   # Firestore data sync
│   ├── RecommendationEngine.swift
│   ├── OCRService.swift
│   └── NotificationService.swift
└── Utils/
    └── Extensions.swift    # Color hex, Date helpers

Functions/
├── firebase/               # Firebase Cloud Functions
│   ├── index.js            # Cloud Functions entry point
│   └── package.json
├── scraper/                # Credit card data scraper
│   ├── index.js            # Main entry, runs all scrapers
│   ├── scrapers/           # Per-issuer scrapers (chase.js, amex.js, etc.)
│   ├── utils/              # BaseScraper, category mapping
│   └── upload-to-firestore.js
└── service-account.json    # Firebase credentials (gitignored)
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

## Scraper Commands

```bash
cd Functions/scraper

npm run scrape          # Run all scrapers
npm run scrape:chase    # Run specific issuer
npm run validate        # Validate scraped data
npm run upload          # Upload to Firestore
npm run full            # Scrape + upload (one command)
```

## Firebase Setup

1. Create a Firebase project
2. Download `service-account.json` from Firebase Console → Project Settings → Service Accounts
3. Place it in `Functions/` directory
4. Configure iOS app with `GoogleService-Info.plist`
