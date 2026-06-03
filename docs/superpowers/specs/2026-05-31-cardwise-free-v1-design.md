# CardWise Free v1 — App Store Readiness Design

**Date:** 2026-05-31
**Goal:** Ship CardWise to the App Store as a 100% free, zero-backend app — no Firebase, no Plaid, no in-app purchase — with user data stored locally and synced via CloudKit. Resolve all App Store compliance blockers.

## Decisions (locked)

1. **Zero backend, free.** Card reward database is bundled into the app; recommendations are computed on-device (already the case).
2. **Drop Plaid for v1.** Bank-account linking is removed from the shipping build. Code is preserved in git history for a possible future paid version.
3. **User data: SwiftData + CloudKit.** The user's own cards and spending records are stored locally with SwiftData and synced across their devices via the CloudKit private database (free; uses the user's own iCloud).
4. **Completely free.** The subscription paywall and StoreKit in-app purchase are removed. All features are unlocked for everyone; the 3-card free limit is removed.
5. **Privacy Policy + Terms published as public GitHub Gists** via `gh`, producing public URLs for the App Store listing and in-app links.

## Known prerequisites (user-owned, cannot be automated)

- **Apple Developer Program membership ($99/yr)** is required both to ship to the App Store and to provision the CloudKit container. This is an Apple requirement and cannot be bypassed.
- **App Store Connect tasks** (creating the app record, uploading screenshots, filling metadata, the privacy nutrition label answers, submitting for review) require the user's account.
- **Revoking the leaked Firebase service-account key** in the Firebase Console is a user action.

## Current state (verified)

- User cards and spending are **already stored locally** in Keychain (`CardViewModel.swift:48`, `SpendingViewModel.swift:13`), not in Firebase.
- Firebase is only used to download the card reward database (`CardViewModel.loadCardsFromFirebase()`), with a `MockData` fallback (70 cards).
- A richer card dataset already exists: `Functions/scraper/scraped-cards.json` (114 cards).
- Firebase/Plaid coupling is confined to 5 files: `CardWiseApp.swift`, `CreditCard.swift`, `PlaidService.swift`, `FirebaseService.swift`, `AuthService.swift`.
- SPM dependencies in the project: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `LinkKit` (Plaid).
- Subscription gating lives in `SubscriptionGate.swift` (free = 3 cards; Pro = unlimited cards, bankLinking, advancedAnalytics, capAlerts, widget). `bankLinking` is obsolete once Plaid is removed.

## Architecture

```
┌─────────────────────────────────────────────┐
│ CardWise (iOS, SwiftUI, MVVM) — no backend    │
│                                               │
│  Bundled cards.json (114) ──► CardViewModel   │
│        (read-only reward DB)     │            │
│                                  ▼            │
│                          RecommendationEngine  │  (on-device, unchanged)
│                                               │
│  User cards + spending ──► SwiftData models   │
│                              │                │
│                              ▼                │
│                      CloudKit private DB ◄────┼──► user's iCloud (sync)
└─────────────────────────────────────────────┘
```

No network calls to any first-party server. Outbound network is limited to loading remote card-art images (existing behaviour).

## Work breakdown

### Phase A — Remove the backend (make it free)

- **A1.** Add `cards.json` (copied/renamed from `Functions/scraper/scraped-cards.json`, validated against the `CreditCard` Codable shape) to the app bundle as a resource.
- **A2.** Replace `CardViewModel.loadCardsFromFirebase()` with `loadBundledCards()` that decodes `cards.json`; keep `MockData.creditCards` as the final fallback if decode fails.
- **A3.** Remove SPM dependencies: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `LinkKit`.
- **A4.** Remove from the build target: `FirebaseService.swift`, `AuthService.swift`, `PlaidService.swift`, `LinkBankView.swift`. Strip the Firebase init from `CardWiseApp.swift`; remove the bank-linking entry in `SettingsView.swift`; remove Firebase references in `CreditCard.swift`.
- **A5.** Delete the placeholder `CardWise/GoogleService-Info.plist`.

### Phase B — Remove the paywall (fully free)

- **B1.** Remove `PaywallView.swift`, `SubscriptionManager.swift`, `SubscriptionGate.swift`, and `SubscriptionGateTests`.
- **B2.** Update all call sites so every feature is unlocked: remove the 3-card limit (`CardListView.swift`), remove paywall sheets, treat `isPro` as always true / delete the parameter. Affected: `CardWiseApp.swift`, `SettingsView.swift`, `CardListView.swift`, `HomeView.swift`, `ScanReceiptView.swift`.
- **B3.** Remove `bankLinking` and any Plaid-related UI/strings (folds in from Phase A).

### Phase C — User data: SwiftData + CloudKit

- **C1.** Define SwiftData `@Model` types for the user's cards and spending records (mirroring current `UserCard` and `Spending`).
- **C2.** Configure a CloudKit-backed `ModelContainer` (private database, automatic sync).
- **C3.** One-time migration: on first launch of the new version, read existing Keychain data into SwiftData, then clear the Keychain entries. No user data loss.
- **C4.** Update `CardViewModel` / `SpendingViewModel` to read/write through SwiftData instead of Keychain.
- **C5.** Add the iCloud capability with CloudKit + the container identifier, and the `remote-notification` background mode (required for CloudKit sync). Provisioning the container requires the Apple Developer account (user).

### Phase D — App Store compliance

- **D1.** Create `PrivacyInfo.xcprivacy`: declare camera and photo-library usage, the `UserDefaults` API reason code, and **no tracking / no data collected off-device**.
- **D2.** Verify Info.plist usage strings (camera, photo library — already present), app icon (1024 present), launch screen, version `1.0.0` / build `1`.
- **D3.** Update the in-app `PrivacyPolicyView` and `TermsOfServiceView` text to match the new reality: data stored on-device and in the user's iCloud, no third-party data sharing, no Firebase, no Plaid.
- **D4.** Publish the updated Privacy Policy and Terms as public GitHub Gists via `gh gist create`; wire the resulting URLs into the app and hand them to the user for the App Store listing.
- **D5.** Delete the 26 ` 2.swift` duplicate files.
- **D6.** Update `CLAUDE.md`: remove the manual-project-creation step (project exists), remove Firebase/Plaid from the tech stack, reflect the local + CloudKit architecture.
- **D7.** Delete the local `Functions/service-account.json` and remind the user to revoke the key in the Firebase Console.

### Phase E — Verify

- **E1.** `xcodebuild` compiles clean with no Firebase/Plaid/StoreKit references remaining.
- **E2.** Unit tests pass (recommendation engine, models, merchant DB, search history). Remove subscription tests.
- **E3.** Launch in the simulator and smoke-test: recommend a card, add/remove user cards (no limit), record spending, scan a receipt (OCR), confirm card list populates from bundled data.

## Out of scope for v1

- Plaid / automatic bank-transaction sync (deferred to a possible paid future version).
- Any subscription or in-app purchase.
- Cloud-hosted card-database updates (cards ship bundled; updates come via app updates for now).
- Deploying or maintaining the `Functions/` backend (left in the repo, not shipped).

## Risks

- **CloudKit testing** needs the $99 Apple Developer account; sync cannot be fully verified locally without it. Local SwiftData persistence is verifiable without it.
- **Keychain → SwiftData migration** must be correct to avoid losing existing users' data; covered by C3 and a migration test.
- **Card data freshness**: bundled JSON goes stale between app updates. Acceptable for v1; a free static-JSON refresh (e.g. GitHub raw) can be added later without a backend.
