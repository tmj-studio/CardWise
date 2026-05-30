# CardWise Free v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship CardWise as a 100% free, zero-backend iOS app — Firebase, Plaid, and StoreKit removed; card database bundled; user data persisted locally via SwiftData and synced through CloudKit — with all App Store compliance blockers resolved.

**Architecture:** Keep the existing Codable struct domain models (`CreditCard`, `UserCard`, `Spending`) and `RecommendationEngine` untouched. Swap the *card database source* from Firebase to a bundled `cards.json`. Swap *user-data persistence* from Keychain to a thin SwiftData store (`@Model` record classes that hold the Codable structs as `Data` blobs), backed by CloudKit for sync. Remove the subscription paywall so every feature is unlocked.

**Tech Stack:** Swift, SwiftUI, MVVM, SwiftData + CloudKit (replaces Firebase/Keychain), Vision (OCR, unchanged), WidgetKit (unchanged). Build/test via `xcodebuild`.

---

## File Structure

**Created:**
- `CardWise/Resources/cards.json` — bundled card reward database (114 cards), extracted from `Functions/scraper/scraped-cards.json`.
- `CardWise/Services/CardCatalog.swift` — decodes bundled `cards.json`, falls back to `MockData`.
- `CardWise/Services/CloudStore.swift` — SwiftData `@Model` records + a store that loads/saves `[UserCard]` and `[Spending]`, and migrates from Keychain.
- `CardWise/PrivacyInfo.xcprivacy` — App Store privacy manifest.
- `CardWiseTests/CardCatalogTests.swift`, `CardWiseTests/CloudStoreTests.swift` — unit tests.

**Modified:**
- `CardWise/ViewModels/CardViewModel.swift` — load cards from `CardCatalog`; persist user cards via `CloudStore`.
- `CardWise/ViewModels/SpendingViewModel.swift` — persist spendings via `CloudStore`.
- `CardWise/App/CardWiseApp.swift` — remove Firebase init; inject the SwiftData `ModelContainer`; drop `subscription`.
- `CardWise/Views/Settings/SettingsView.swift`, `Views/Cards/CardListView.swift`, `Views/Home/HomeView.swift`, `Views/Spending/ScanReceiptView.swift` — remove paywall gating and Plaid entry.
- `CardWise/Services/WidgetDataManager.swift`, `Services/NotificationService.swift` — drop `isPro` parameters.
- `CardWise/Models/CreditCard.swift` — remove the `lastUpdated`/Firestore comment coupling (kept optional, no code change needed beyond comment).
- `CLAUDE.md` — update stack/architecture.

**Deleted (from build + disk; git history preserves them):**
- `CardWise/Services/FirebaseService.swift`, `Services/AuthService.swift`, `Services/PlaidService.swift`
- `CardWise/Views/Settings/LinkBankView.swift`
- `CardWise/Views/Paywall/PaywallView.swift`, `Services/SubscriptionManager.swift`, `Services/SubscriptionGate.swift`, `CardWiseTests/SubscriptionGateTests.swift`
- `CardWise/GoogleService-Info.plist`
- `Functions/service-account.json`
- All 26 ` 2.swift` duplicate files.

**SPM dependencies removed:** `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `LinkKit`.

---

## Task 0: Create feature branch and clean duplicate files

**Files:** none (git + filesystem only)

- [ ] **Step 1: Create and switch to a feature branch**

```bash
cd /Users/rich/Desktop/CardWise
git checkout -b feature/free-v1
```

- [ ] **Step 2: Delete the 26 ` 2.swift`/` 2.plist`/` 2.json` duplicate files**

```bash
cd /Users/rich/Desktop/CardWise
find . -name "* 2.swift" -delete
find . -name "* 2.plist" -delete
find . -name "* 2.json" -delete
git status --short | grep " 2\." || echo "no duplicate files remain"
```

Expected: command prints `no duplicate files remain` (the untracked duplicates are gone).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove duplicate ' 2' files and start free-v1 branch"
```

---

## Task 1: Extract bundled card database (`cards.json`)

**Files:**
- Create: `CardWise/Resources/cards.json`

- [ ] **Step 1: Extract the `cards` array into a standalone JSON file**

```bash
cd /Users/rich/Desktop/CardWise
python3 - <<'PY'
import json
src = json.load(open("Functions/scraper/scraped-cards.json"))
cards = src["cards"]
with open("CardWise/Resources/cards.json", "w") as f:
    json.dump(cards, f, ensure_ascii=False, indent=2)
print("wrote", len(cards), "cards to CardWise/Resources/cards.json")
PY
```

Expected: `wrote 114 cards to CardWise/Resources/cards.json`

- [ ] **Step 2: Add `cards.json` to the Xcode app target as a bundle resource**

In Xcode: select `CardWise/Resources/cards.json` in the navigator → File Inspector → under **Target Membership**, check the **CardWise** app target. (Alternatively, drag the file into the `Resources` group and ensure "Add to target: CardWise" is checked.)

Verify it is in the Copy Bundle Resources phase:

```bash
grep -c "cards.json" CardWise.xcodeproj/project.pbxproj
```

Expected: a non-zero count.

- [ ] **Step 3: Commit**

```bash
git add CardWise/Resources/cards.json CardWise.xcodeproj/project.pbxproj
git commit -m "feat: bundle card reward database (114 cards) as app resource"
```

---

## Task 2: CardCatalog — decode bundled cards with MockData fallback

**Files:**
- Create: `CardWise/Services/CardCatalog.swift`
- Test: `CardWiseTests/CardCatalogTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// CardWiseTests/CardCatalogTests.swift
import XCTest
@testable import CardWise

final class CardCatalogTests: XCTestCase {
    func test_loadCards_decodesBundledJSON_withManyCards() {
        let cards = CardCatalog.loadCards()
        // Bundled cards.json ships 114 cards; must decode well past the MockData count (70).
        XCTAssertGreaterThan(cards.count, 100, "Expected bundled cards.json to decode, got \(cards.count)")
    }

    func test_loadCards_allCardsHaveStableIDs() {
        let cards = CardCatalog.loadCards()
        let ids = Set(cards.map { $0.id })
        XCTAssertEqual(ids.count, cards.count, "Card IDs must be unique")
        XCTAssertFalse(ids.contains(""), "No card may have an empty id")
    }

    func test_decode_fallsBackToMockData_whenDataInvalid() {
        let cards = CardCatalog.decodeCards(from: Data("not json".utf8))
        XCTAssertEqual(cards.count, MockData.creditCards.count)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CardWiseTests/CardCatalogTests`
Expected: FAIL — `CardCatalog` is undefined.

- [ ] **Step 3: Write the implementation**

```swift
// CardWise/Services/CardCatalog.swift
import Foundation
import os

/// Loads the read-only credit-card reward database bundled with the app.
/// Replaces the former Firebase/Firestore download. Falls back to MockData
/// if the bundled file is missing or cannot be decoded.
enum CardCatalog {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "CardCatalog")

    /// Decode a `[CreditCard]` array from raw JSON data, falling back to MockData on failure.
    static func decodeCards(from data: Data) -> [CreditCard] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cards = try? decoder.decode([CreditCard].self, from: data), !cards.isEmpty {
            return cards
        }
        return MockData.creditCards
    }

    /// Load cards from the bundled `cards.json`, or MockData if unavailable.
    static func loadCards() -> [CreditCard] {
        guard let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            logger.error("cards.json not found in bundle; using MockData")
            #endif
            return MockData.creditCards
        }
        return decodeCards(from: data)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CardWiseTests/CardCatalogTests`
Expected: PASS. If `test_loadCards` fails on the dateDecodingStrategy, note that `cards.json` has no `lastUpdated` field (it is optional) so decoding must still succeed; if a different field mismatches, fix `cards.json` extraction in Task 1.

- [ ] **Step 5: Commit**

```bash
git add CardWise/Services/CardCatalog.swift CardWiseTests/CardCatalogTests.swift
git commit -m "feat: add CardCatalog to load bundled card database with MockData fallback"
```

---

## Task 3: Point CardViewModel at CardCatalog (remove Firebase load)

**Files:**
- Modify: `CardWise/ViewModels/CardViewModel.swift:12-46`

- [ ] **Step 1: Replace the init Task and the Firebase loader**

Replace lines 12-46 (the `init()` block and the entire `// MARK: - Firebase` section through `loadCardsFromFirebase()`) with:

```swift
    init() {
        loadUserCards()
        allCards = CardCatalog.loadCards()
    }

    // MARK: - Card Database (bundled)

    func reloadCatalog() {
        allCards = CardCatalog.loadCards()
    }
```

(Removes `loadCardsFromFirebase()` and its `FirebaseService` dependency. `isLoading` remains a published property; it is simply no longer toggled here.)

- [ ] **Step 2: Build to verify no remaining FirebaseService reference in this file**

```bash
grep -n "Firebase\|loadCardsFromFirebase" CardWise/ViewModels/CardViewModel.swift || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Commit**

```bash
git add CardWise/ViewModels/CardViewModel.swift
git commit -m "refactor: load card database from CardCatalog instead of Firebase"
```

---

## Task 4: Remove Firebase, Plaid, and Auth source files

**Files:**
- Delete: `CardWise/Services/FirebaseService.swift`, `Services/AuthService.swift`, `Services/PlaidService.swift`, `Views/Settings/LinkBankView.swift`, `GoogleService-Info.plist`

- [ ] **Step 1: Delete the files from disk and the Xcode target**

In Xcode: select each file in the navigator → right-click → **Delete** → **Move to Trash** (this removes both the file and its target membership / pbxproj reference). Files:
- `CardWise/Services/FirebaseService.swift`
- `CardWise/Services/AuthService.swift`
- `CardWise/Services/PlaidService.swift`
- `CardWise/Views/Settings/LinkBankView.swift`
- `CardWise/GoogleService-Info.plist`

- [ ] **Step 2: Verify references are gone from the project file**

```bash
cd /Users/rich/Desktop/CardWise
grep -c "FirebaseService.swift\|AuthService.swift\|PlaidService.swift\|LinkBankView.swift\|GoogleService-Info" CardWise.xcodeproj/project.pbxproj
ls CardWise/Services/FirebaseService.swift 2>&1 | grep -q "No such file" && echo "files deleted"
```

Expected: count `0`, then `files deleted`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove Firebase, Plaid, and Auth source files"
```

---

## Task 5: Remove the bank-linking entry from SettingsView

**Files:**
- Modify: `CardWise/Views/Settings/SettingsView.swift` (lines around 82 and 283, and any `LinkBankView`/`PlaidService` references)

- [ ] **Step 1: Find every Plaid / bank-linking reference**

```bash
grep -n "LinkBank\|Plaid\|bankLinking\|linkBank" CardWise/Views/Settings/SettingsView.swift
```

- [ ] **Step 2: Delete the bank-linking section**

Remove the `if subscription.isPro { ... } else if SubscriptionGate.isUnlocked(.bankLinking, ...) { ... }` block near line 82 and any navigation/sheet that presents `LinkBankView`. The "Link Bank Account" row and its surrounding `Section`/conditional must be deleted entirely. After editing, re-run the grep from Step 1 and confirm no matches remain.

- [ ] **Step 3: Verify**

```bash
grep -n "LinkBank\|Plaid\|bankLinking\|linkBank" CardWise/Views/Settings/SettingsView.swift || echo "clean"
```

Expected: `clean`.

- [ ] **Step 4: Commit**

```bash
git add CardWise/Views/Settings/SettingsView.swift
git commit -m "feat: remove bank-linking (Plaid) UI from Settings"
```

---

## Task 6: Remove the StoreKit paywall and unlock all features

**Files:**
- Delete: `CardWise/Views/Paywall/PaywallView.swift`, `Services/SubscriptionManager.swift`, `Services/SubscriptionGate.swift`, `CardWiseTests/SubscriptionGateTests.swift`
- Modify: `CardWise/App/CardWiseApp.swift`, `Views/Cards/CardListView.swift`, `Views/Settings/SettingsView.swift`, `Views/Home/HomeView.swift`, `Views/Spending/ScanReceiptView.swift`, `Services/WidgetDataManager.swift`, `Services/NotificationService.swift`

- [ ] **Step 1: Find every subscription reference across the app**

```bash
cd /Users/rich/Desktop/CardWise
grep -rn "isPro\|SubscriptionGate\|SubscriptionManager\|PaywallView\|ProFeature\|\.environmentObject(subscription)\|subscription" CardWise --include=*.swift | grep -v "_Tests"
```

Use this list as the authoritative set of edits for the steps below.

- [ ] **Step 2: Delete the paywall source + its test in Xcode**

In Xcode, delete (Move to Trash): `PaywallView.swift`, `SubscriptionManager.swift`, `SubscriptionGate.swift`, `SubscriptionGateTests.swift`.

- [ ] **Step 3: `CardWiseApp.swift` — drop the subscription StateObject and environment**

- Remove the line `@StateObject private var subscription = SubscriptionManager.shared`.
- Remove every `.environmentObject(subscription)` (appears for both `MainTabView()` and `OnboardingView()`).
- In `updateWidgetData()`, change the call to drop the `isPro:` argument:

```swift
    private func updateWidgetData() {
        WidgetDataManager.shared.updateWidgetData(
            cardViewModel: cardViewModel,
            spendingViewModel: spendingViewModel
        )
    }
```

- [ ] **Step 4: `WidgetDataManager.swift` — drop the `isPro` parameter**

Change the signature `func updateWidgetData(cardViewModel:spendingViewModel:isPro:)` to `func updateWidgetData(cardViewModel:spendingViewModel:)` and delete any `isPro`-conditional logic inside (treat the widget as always available).

- [ ] **Step 5: `NotificationService.swift` — drop `isPro` from `shouldSendSpendingCapAlerts`**

Change `func shouldSendSpendingCapAlerts(isPro: Bool) -> Bool` to `func shouldSendSpendingCapAlerts() -> Bool` and `return true` (cap alerts are now free). Update both call sites in `HomeView.swift:665` and `ScanReceiptView.swift:312` to call `shouldSendSpendingCapAlerts()` with no argument.

- [ ] **Step 6: `CardListView.swift` — remove the 3-card limit and paywall sheet**

- Around line 82, replace `if SubscriptionGate.canAddCard(currentCount: cardViewModel.userCards.count, isPro: subscription.isPro) { ... }` so the body always runs (the add-card flow is always allowed). Delete the `else` branch that presents the paywall.
- Around line 71, delete the `.sheet { PaywallView() }` presentation and any `@State` that drove it.
- Remove `@EnvironmentObject var subscription` from the view.

- [ ] **Step 7: `SettingsView.swift` — remove remaining subscription UI**

- Around line 23 (`if subscription.isPro { ... }`) delete the Pro/Upgrade status row and any "Restore Purchases" / "Upgrade to Pro" rows and the `.sheet { PaywallView() }` near line 283.
- Around line 146, replace `if SubscriptionGate.isUnlocked(.capAlerts, isPro: subscription.isPro) { ... }` so cap-alert settings are always shown.
- Remove `@EnvironmentObject var subscription`.

- [ ] **Step 8: `HomeView.swift` — drop `isPro` usage**

At line 665, the `notifyCapAlerts:` argument now calls `NotificationService.shared.shouldSendSpendingCapAlerts()` (no `isPro`). Remove `@EnvironmentObject var subscription` if present.

- [ ] **Step 9: `ScanReceiptView.swift` — drop `isPro` usage**

At line 312, same change as HomeView: `shouldSendSpendingCapAlerts()` with no argument. Remove `@EnvironmentObject var subscription` if present.

- [ ] **Step 10: Verify no subscription references remain**

```bash
grep -rn "isPro\|SubscriptionGate\|SubscriptionManager\|PaywallView\|ProFeature\|subscription" CardWise --include=*.swift || echo "clean"
```

Expected: `clean`.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: remove StoreKit paywall; all features free"
```

---

## Task 7: Remove SPM dependencies (Firebase + Plaid LinkKit)

**Files:**
- Modify: `CardWise.xcodeproj/project.pbxproj`, `CardWise.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

- [ ] **Step 1: Remove the package products from the target in Xcode**

In Xcode: select the project → **CardWise** target → **General** tab → **Frameworks, Libraries, and Embedded Content**: remove `FirebaseAuth`, `FirebaseFirestore`, `FirebaseCore` (and any other Firebase products), and `LinkKit`.

Then: project → **Package Dependencies** tab → select the `firebase-ios-sdk` package and the `plaid-link-ios` (LinkKit) package → click **−** to remove them.

- [ ] **Step 2: Verify the packages are gone**

```bash
cd /Users/rich/Desktop/CardWise
grep -o "Firebase[A-Za-z]*\|LinkKit\|plaid\|firebase-ios-sdk\|plaid-link" CardWise.xcodeproj/project.pbxproj | sort -u || echo "clean"
```

Expected: `clean` (no Firebase/Plaid product references).

- [ ] **Step 3: Resolve packages and build**

```bash
xcodebuild -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' -resolvePackageDependencies
xcodebuild build -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: BUILD SUCCEEDED. If the build fails with "no such module FirebaseCore" or similar, an `import` was missed — grep for `import Firebase` and `import LinkKit` and remove those lines.

```bash
grep -rn "import Firebase\|import LinkKit" CardWise --include=*.swift || echo "no stale imports"
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove Firebase and Plaid LinkKit SPM dependencies"
```

---

## Task 8: SwiftData store — records, encode/decode, and migration logic

**Files:**
- Create: `CardWise/Services/CloudStore.swift`
- Test: `CardWiseTests/CloudStoreTests.swift`

> CloudKit-backed SwiftData requires every stored property to have a default value and forbids unique constraints, so the record classes use plain `String`/`Data` with defaults and uniqueness is enforced in code by `id`.

- [ ] **Step 1: Write the failing test (in-memory ModelContainer)**

```swift
// CardWiseTests/CloudStoreTests.swift
import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class CloudStoreTests: XCTestCase {
    private func makeStore() throws -> CloudStore {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self,
            configurations: config
        )
        return CloudStore(context: container.mainContext)
    }

    func test_saveAndLoadUserCards_roundTrips() throws {
        let store = try makeStore()
        let card = MockData.creditCards[0]
        let userCard = UserCard(card: card, nickname: "Daily")
        store.saveUserCards([userCard])

        let loaded = store.loadUserCards()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, userCard.id)
        XCTAssertEqual(loaded.first?.nickname, "Daily")
    }

    func test_saveUserCards_replacesRemoved() throws {
        let store = try makeStore()
        let a = UserCard(card: MockData.creditCards[0])
        let b = UserCard(card: MockData.creditCards[1])
        store.saveUserCards([a, b])
        store.saveUserCards([a]) // b removed
        let loaded = store.loadUserCards()
        XCTAssertEqual(loaded.map { $0.id }, [a.id])
    }

    func test_saveAndLoadSpendings_roundTrips() throws {
        let store = try makeStore()
        let s = Spending(amount: 12.5, merchant: "Cafe", category: .dining,
                         cardUsed: "card-1", rewardEarned: 0.5)
        store.saveSpendings([s])
        let loaded = store.loadSpendings()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.merchant, "Cafe")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CardWiseTests/CloudStoreTests`
Expected: FAIL — `CloudStore` / `UserCardRecord` undefined.

- [ ] **Step 3: Write the implementation**

```swift
// CardWise/Services/CloudStore.swift
import Foundation
import SwiftData
import os

/// SwiftData record wrapping a Codable UserCard as a JSON blob.
/// CloudKit-compatible: all properties have defaults, no unique constraints.
@Model
final class UserCardRecord {
    var id: String = ""
    var payload: Data = Data()
    init(id: String = "", payload: Data = Data()) {
        self.id = id
        self.payload = payload
    }
}

/// SwiftData record wrapping a Codable Spending as a JSON blob.
@Model
final class SpendingRecord {
    var id: String = ""
    var payload: Data = Data()
    init(id: String = "", payload: Data = Data()) {
        self.id = id
        self.payload = payload
    }
}

/// Persists the user's cards and spendings via SwiftData (CloudKit-synced in the
/// app; in-memory in tests). The ViewModels remain the source of truth and hand
/// the full arrays to `save*`; the store upserts by id and prunes anything removed.
@MainActor
final class CloudStore {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "CloudStore")
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - UserCards

    func loadUserCards() -> [UserCard] {
        let records = (try? context.fetch(FetchDescriptor<UserCardRecord>())) ?? []
        return records.compactMap { try? decoder.decode(UserCard.self, from: $0.payload) }
    }

    func saveUserCards(_ cards: [UserCard]) {
        let keepIds = Set(cards.map { $0.id })
        let existing = (try? context.fetch(FetchDescriptor<UserCardRecord>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for record in existing where !keepIds.contains(record.id) {
            context.delete(record)
            byId[record.id] = nil
        }
        for card in cards {
            guard let data = try? encoder.encode(card) else { continue }
            if let record = byId[card.id] {
                record.payload = data
            } else {
                context.insert(UserCardRecord(id: card.id, payload: data))
            }
        }
        try? context.save()
    }

    // MARK: - Spendings

    func loadSpendings() -> [Spending] {
        let records = (try? context.fetch(FetchDescriptor<SpendingRecord>())) ?? []
        return records
            .compactMap { try? decoder.decode(Spending.self, from: $0.payload) }
            .sorted { $0.date > $1.date }
    }

    func saveSpendings(_ spendings: [Spending]) {
        let keepIds = Set(spendings.map { $0.id })
        let existing = (try? context.fetch(FetchDescriptor<SpendingRecord>())) ?? []
        var byId = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })

        for record in existing where !keepIds.contains(record.id) {
            context.delete(record)
            byId[record.id] = nil
        }
        for spending in spendings {
            guard let data = try? encoder.encode(spending) else { continue }
            if let record = byId[spending.id] {
                record.payload = data
            } else {
                context.insert(SpendingRecord(id: spending.id, payload: data))
            }
        }
        try? context.save()
    }

    // MARK: - One-time Keychain migration

    /// Migrates legacy Keychain data into SwiftData exactly once, then clears the
    /// Keychain. Guarded by a UserDefaults flag so it never runs twice.
    func migrateFromKeychainIfNeeded() {
        let flag = "didMigrateKeychainToSwiftData"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }

        if let cards: [UserCard] = try? KeychainHelper.shared.load(forKey: "userCards"), !cards.isEmpty {
            saveUserCards(cards)
            KeychainHelper.shared.delete(forKey: "userCards")
        }
        if let spendings: [Spending] = try? KeychainHelper.shared.load(forKey: "spendings"), !spendings.isEmpty {
            saveSpendings(spendings)
            KeychainHelper.shared.delete(forKey: "spendings")
        }
        UserDefaults.standard.set(true, forKey: flag)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CardWiseTests/CloudStoreTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add CardWise/Services/CloudStore.swift CardWiseTests/CloudStoreTests.swift
git commit -m "feat: add SwiftData CloudStore for user cards and spendings with Keychain migration"
```

---

## Task 9: Wire the ModelContainer into the app and ViewModels

**Files:**
- Modify: `CardWise/App/CardWiseApp.swift`, `CardWise/ViewModels/CardViewModel.swift`, `CardWise/ViewModels/SpendingViewModel.swift`

- [ ] **Step 1: Create the shared CloudKit-backed container in `CardWiseApp.swift`**

Add, at file scope (above `@main`):

```swift
import SwiftData

enum AppContainer {
    /// CloudKit-synced in the app. The container identifier must match the
    /// iCloud capability configured in Task 11.
    static let shared: ModelContainer = {
        let config = ModelConfiguration(
            "CardWise",
            cloudKitDatabase: .private("iCloud.com.cardwise.app")
        )
        do {
            return try ModelContainer(
                for: UserCardRecord.self, SpendingRecord.self,
                configurations: config
            )
        } catch {
            // Fall back to a local-only store so the app still launches if CloudKit is unavailable.
            let local = ModelConfiguration("CardWise", cloudKitDatabase: .none)
            return try! ModelContainer(for: UserCardRecord.self, SpendingRecord.self, configurations: local)
        }
    }()
}
```

- [ ] **Step 2: Inject the store into the ViewModels at app start**

In `CardWiseApp`'s `init()`, after `AppAppearance.apply()`, build a `CloudStore` from `AppContainer.shared.mainContext`, run migration, and pass it to the view models. Change the `@StateObject` declarations to construct the VMs with the store:

```swift
    @StateObject private var cardViewModel: CardViewModel
    @StateObject private var spendingViewModel: SpendingViewModel

    init() {
        AppAppearance.apply()
        let store = CloudStore(context: AppContainer.shared.mainContext)
        store.migrateFromKeychainIfNeeded()
        _cardViewModel = StateObject(wrappedValue: CardViewModel(store: store))
        _spendingViewModel = StateObject(wrappedValue: SpendingViewModel(store: store))
    }
```

Also add `.modelContainer(AppContainer.shared)` to the `WindowGroup` content (both the `MainTabView` and `OnboardingView` branches) so SwiftData is available in the environment.

- [ ] **Step 3: Update `CardViewModel` to persist via the store**

Replace the persistence section. The `init()` becomes:

```swift
    private let store: CloudStore

    init(store: CloudStore) {
        self.store = store
        userCards = store.loadUserCards()
        allCards = CardCatalog.loadCards()
    }
```

Replace `loadUserCards()`, `saveUserCards()`, and `clearAllData()`:

```swift
    private func saveUserCards() {
        store.saveUserCards(userCards)
    }

    func clearAllData() {
        userCards = []
        store.saveUserCards([])
    }
```

(Delete `Self.keychainKey`, the old `loadUserCards()`, and the `UserDefaultsKeys.userCards` references in this file.)

- [ ] **Step 4: Update `SpendingViewModel` to persist via the store**

```swift
    private let store: CloudStore

    init(store: CloudStore) {
        self.store = store
        spendings = store.loadSpendings()
    }

    private func saveSpendings() {
        store.saveSpendings(spendings)
    }

    func clearAllData() {
        spendings = []
        store.saveSpendings([])
    }
```

(Delete `Self.keychainKey`, the old `loadSpendings()`, and the `UserDefaultsKeys.spendings` references in this file.)

- [ ] **Step 5: Fix any other construction sites of the view models**

```bash
grep -rn "CardViewModel()\|SpendingViewModel()" CardWise --include=*.swift
```

For any preview or call that constructs a VM with no arguments, pass an in-memory store, e.g.:

```swift
CardViewModel(store: CloudStore(context: try! ModelContainer(for: UserCardRecord.self, SpendingRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)).mainContext))
```

- [ ] **Step 6: Build**

Run: `xcodebuild build -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: persist user data via SwiftData CloudStore (replaces Keychain)"
```

---

## Task 10: PrivacyInfo.xcprivacy manifest

**Files:**
- Create: `CardWise/PrivacyInfo.xcprivacy`

- [ ] **Step 1: Create the privacy manifest**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Add it to the app target in Xcode**

Drag `PrivacyInfo.xcprivacy` into the `CardWise` group with **Target Membership: CardWise** checked.

```bash
grep -c "PrivacyInfo.xcprivacy" CardWise.xcodeproj/project.pbxproj
```

Expected: non-zero.

- [ ] **Step 3: Commit**

```bash
git add CardWise/PrivacyInfo.xcprivacy CardWise.xcodeproj/project.pbxproj
git commit -m "feat: add PrivacyInfo.xcprivacy manifest (no tracking, no data collection)"
```

---

## Task 11: Add iCloud / CloudKit capability (requires Apple Developer account)

**Files:**
- Modify: `CardWise/CardWise.entitlements` (created by Xcode), `CardWise.xcodeproj/project.pbxproj`

> This task requires the user's Apple Developer Program account to provision the CloudKit container. If the account is not yet available, the app still builds and runs locally via the `.none` fallback in `AppContainer`; complete this task before submitting to the App Store.

- [ ] **Step 1: Enable capabilities in Xcode**

Project → **CardWise** target → **Signing & Capabilities** → **+ Capability**:
- Add **iCloud**, check **CloudKit**, and add the container `iCloud.com.cardwise.app` (must match the identifier in `AppContainer`).
- Add **Background Modes**, check **Remote notifications** (required for CloudKit push sync).

- [ ] **Step 2: Verify the entitlements file**

```bash
cat CardWise/CardWise.entitlements 2>/dev/null | grep -A2 "CloudKit\|iCloud.com.cardwise.app" && echo "entitlements set"
```

Expected: shows the CloudKit container and `entitlements set`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: enable iCloud CloudKit capability and remote-notification background mode"
```

---

## Task 12: Update in-app Privacy Policy & Terms text

**Files:**
- Modify: the views containing `PrivacyPolicyView` and `TermsOfServiceView` (locate with the grep below)

- [ ] **Step 1: Locate the policy text**

```bash
grep -rln "PrivacyPolicyView\|TermsOfServiceView\|Privacy Policy\|Last Updated" CardWise --include=*.swift
```

- [ ] **Step 2: Rewrite the data-practices section to match the free/local architecture**

The policy must state plainly: CardWise stores the user's cards and spending **on their device and in their personal iCloud account**; CardWise has **no servers**, does **not** collect or transmit personal data to the developer, does **not** use Firebase or Plaid, does **not** link bank accounts, and does **not** track users or share data with third parties. Camera and photo-library access are used **only** locally for on-device receipt OCR. Update the "Last Updated" date to `2026-05-31`. Remove any mention of Firebase, Plaid, bank linking, or subscriptions.

- [ ] **Step 3: Build to confirm the views still compile**

Run: `xcodebuild build -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "docs: rewrite in-app privacy policy and terms for free/local architecture"
```

---

## Task 13: Publish Privacy Policy & Terms as public GitHub Gists

**Files:**
- Create: `docs/legal/privacy-policy.md`, `docs/legal/terms-of-service.md`

- [ ] **Step 1: Write the two markdown documents**

Create `docs/legal/privacy-policy.md` and `docs/legal/terms-of-service.md` with the same content used in Task 12 (the user-facing policy and terms), formatted as standalone markdown with a title and the `Last Updated: 2026-05-31` line.

- [ ] **Step 2: Publish each as a public gist and capture the URLs**

```bash
cd /Users/rich/Desktop/CardWise
gh gist create --public docs/legal/privacy-policy.md --desc "CardWise Privacy Policy"
gh gist create --public docs/legal/terms-of-service.md --desc "CardWise Terms of Service"
```

Expected: each command prints a public gist URL. Record both URLs.

- [ ] **Step 3: Wire the URLs into the app**

If the in-app policy views link out (e.g., a "View online" button or App Store metadata constant), set those to the gist URLs. Add a `Legal` constants file if none exists:

```swift
// CardWise/Utils/LegalLinks.swift
import Foundation

enum LegalLinks {
    // Filled from Task 13 Step 2 output.
    static let privacyPolicyURL = URL(string: "<PRIVACY_GIST_URL>")!
    static let termsOfServiceURL = URL(string: "<TERMS_GIST_URL>")!
}
```

Replace `<PRIVACY_GIST_URL>` / `<TERMS_GIST_URL>` with the real URLs from Step 2.

- [ ] **Step 4: Commit**

```bash
git add docs/legal/ CardWise/Utils/LegalLinks.swift CardWise.xcodeproj/project.pbxproj
git commit -m "docs: publish privacy policy and terms as public gists; link in app"
```

---

## Task 14: Delete the leaked service-account key and update CLAUDE.md

**Files:**
- Delete: `Functions/service-account.json`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Delete the local service-account key**

```bash
cd /Users/rich/Desktop/CardWise
rm -f Functions/service-account.json
ls Functions/service-account.json 2>&1 | grep -q "No such file" && echo "deleted"
```

Expected: `deleted`. (It was never committed — confirmed gitignored — so no history scrub is needed. **User action:** revoke this key in the Firebase Console regardless.)

- [ ] **Step 2: Update `CLAUDE.md`**

- Remove the "To create the Xcode project" manual steps (the project already exists).
- In **Tech Stack**, remove **Backend: Firebase Firestore** and **Auth: Firebase Auth**; replace with "Persistence: SwiftData + CloudKit (local + iCloud sync)". Remove Plaid from the feature list / note it as deferred.
- In **Architecture**, remove `FirebaseService.swift` and Plaid references; add `CardCatalog.swift` and `CloudStore.swift`.
- Remove the **Firebase Setup** section (or replace with a short note that v1 has no backend).

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "docs: remove service-account key; update CLAUDE.md for free/local v1"
```

---

## Task 15: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Confirm no forbidden references remain**

```bash
cd /Users/rich/Desktop/CardWise
grep -rn "import Firebase\|import LinkKit\|FirebaseService\|PlaidService\|SubscriptionManager\|SubscriptionGate\|PaywallView" CardWise --include=*.swift || echo "clean"
```

Expected: `clean`.

- [ ] **Step 2: Clean build**

Run: `xcodebuild clean build -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the full test suite**

Run: `xcodebuild test -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: all tests pass (RecommendationEngine, Model, MerchantDatabase, SearchHistoryManager, CardCatalog, CloudStore). The deleted `SubscriptionGateTests` must no longer be referenced.

- [ ] **Step 4: Launch in the simulator and smoke-test**

Use the `/run` skill or:

```bash
xcodebuild build -scheme CardWise -destination 'platform=iOS Simulator,name=iPhone 16'
xcrun simctl boot "iPhone 16" 2>/dev/null; open -a Simulator
```

Manually verify: card list populates from bundled data (>100 cards available to add); add more than 3 cards (no paywall); record a spending and see a recommendation; scan a receipt (OCR); no "Link Bank Account" row in Settings; no "Upgrade to Pro" anywhere.

- [ ] **Step 5: Final commit and branch summary**

```bash
git add -A
git commit -m "chore: free-v1 verification pass" --allow-empty
git log --oneline feature/free-v1 ^dev
```

---

## Self-Review Notes

- **Spec coverage:** A1-A5 → Tasks 1-5,7; B1-B3 → Task 6; C1-C5 → Tasks 8,9,11; D1-D7 → Tasks 10,12,13,14,(5); E1-E3 → Task 15. All spec items mapped.
- **CloudKit caveat:** Task 11 requires the Apple Developer account; `AppContainer` falls back to local-only so Tasks 8-10,12-15 are fully executable and verifiable without it.
- **Migration safety:** Task 8 `migrateFromKeychainIfNeeded()` is flag-guarded and tested; existing users' Keychain data moves into SwiftData on first launch.
- **Card data shape:** verified `scraped-cards.json.cards` keys match `CreditCard` (only optional `lastUpdated` absent); Task 2 test guards decode.
