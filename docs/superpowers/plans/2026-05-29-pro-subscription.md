# SmartCard Pro Subscription Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a StoreKit 2 native subscription ("SmartCard Pro") so the app has its first monetization mechanism, gating automation features behind a paywall.

**Architecture:** A pure `SubscriptionGate` holds testable entitlement logic. A `SubscriptionManager` (`@MainActor ObservableObject` singleton) wraps StoreKit 2 — loads products, purchases, restores, and derives `isPro` from `Transaction.currentEntitlements`. It's injected via `.environmentObject` like the existing view models. Gated entry points (add 4th card, link bank, advanced analytics) check `isPro` and present `PaywallView` when locked.

**Tech Stack:** Swift, SwiftUI, StoreKit 2, XCTest, xcodegen (path-globbed sources — new files under `SmartCard/` and `SmartCardTests/` are auto-included after `xcodegen generate`). Local toolchain: Xcode 26.5, simulator `iPhone 17`.

---

## File Structure

- **Create** `SmartCard/Services/SubscriptionGate.swift` — pure entitlement logic + `ProFeature` enum + `freeCardLimit`. No StoreKit import. Fully unit-testable.
- **Create** `SmartCard/Services/SubscriptionManager.swift` — StoreKit 2 wrapper, `@Published var isPro`, product loading, purchase/restore.
- **Create** `SmartCard/Views/Paywall/PaywallView.swift` — the paywall sheet (plans, purchase, restore, legal links).
- **Create** `SmartCard.storekit` (repo root) — local StoreKit testing config so purchases work in the simulator without App Store Connect.
- **Create** `SmartCardTests/SubscriptionGateTests.swift` — unit tests for gate logic.
- **Modify** `SmartCard/App/SmartCardApp.swift` — inject `SubscriptionManager`.
- **Modify** `SmartCard/Views/Cards/CardListView.swift` — gate add-card on free card limit.
- **Modify** `SmartCard/Views/Settings/SettingsView.swift` — gate bank linking; add subscription management section.
- **Modify** `SmartCard/Views/Spending/SpendingListView.swift` — gate advanced analytics.

**Product IDs (create these in App Store Connect later; code uses them now):**
- `com.smartcard.app.pro.monthly` → $2.99/mo
- `com.smartcard.app.pro.yearly` → $19.99/yr
- Subscription group: `SmartCard Pro`

**Test command used throughout** (adjust simulator name to one installed locally; list with `xcrun simctl list devices available`):
```bash
xcodebuild test -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SmartCardTests/SubscriptionGateTests
```

---

### Task 1: SubscriptionGate pure logic + tests

**Files:**
- Create: `SmartCard/Services/SubscriptionGate.swift`
- Test: `SmartCardTests/SubscriptionGateTests.swift`

- [ ] **Step 1: Write the failing test**

Create `SmartCardTests/SubscriptionGateTests.swift`:

```swift
import XCTest
@testable import SmartCard

final class SubscriptionGateTests: XCTestCase {

    // MARK: - Card limit

    func testFreeUserCanAddUpToLimit() {
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 0, isPro: false))
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 2, isPro: false))
    }

    func testFreeUserBlockedAtLimit() {
        XCTAssertFalse(SubscriptionGate.canAddCard(currentCount: SubscriptionGate.freeCardLimit, isPro: false))
        XCTAssertFalse(SubscriptionGate.canAddCard(currentCount: 5, isPro: false))
    }

    func testProUserHasUnlimitedCards() {
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: SubscriptionGate.freeCardLimit, isPro: true))
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 99, isPro: true))
    }

    // MARK: - Feature flags

    func testProFeaturesLockedForFreeUser() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(SubscriptionGate.isUnlocked(feature, isPro: false),
                           "\(feature) should be locked for free users")
        }
    }

    func testProFeaturesUnlockedForProUser() {
        for feature in ProFeature.allCases {
            XCTAssertTrue(SubscriptionGate.isUnlocked(feature, isPro: true),
                          "\(feature) should be unlocked for Pro users")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodegen generate
xcodebuild test -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SmartCardTests/SubscriptionGateTests
```
Expected: FAIL — compile error, `SubscriptionGate` / `ProFeature` not found.

- [ ] **Step 3: Write minimal implementation**

Create `SmartCard/Services/SubscriptionGate.swift`:

```swift
import Foundation

/// Features reserved for SmartCard Pro subscribers.
enum ProFeature: CaseIterable {
    case unlimitedCards
    case bankLinking
    case advancedAnalytics
    case capAlerts
    case widget
}

/// Pure, dependency-free entitlement logic. Kept separate from StoreKit so it
/// can be unit-tested without a StoreKit environment.
enum SubscriptionGate {
    /// Maximum number of cards a free (non-Pro) user may add.
    static let freeCardLimit = 3

    /// Whether a user with `currentCount` cards may add one more.
    static func canAddCard(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freeCardLimit
    }

    /// Whether a Pro-gated feature is available to the user.
    static func isUnlocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        isPro
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
xcodebuild test -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SmartCardTests/SubscriptionGateTests
```
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add SmartCard/Services/SubscriptionGate.swift SmartCardTests/SubscriptionGateTests.swift project.yml
git commit -m "feat: add SubscriptionGate entitlement logic with tests"
```

---

### Task 2: Local StoreKit configuration file

**Files:**
- Create: `SmartCard.storekit`

This lets purchases work in the simulator without App Store Connect. No test in this task (it's a config asset consumed by Task 3's manual verification).

- [ ] **Step 1: Create the StoreKit config**

Create `SmartCard.storekit` at the repo root:

```json
{
  "identifier" : "SMARTCARD_PRO",
  "nonRenewingSubscriptions" : [],
  "products" : [],
  "settings" : {
    "_failTransactionsEnabled" : false,
    "_storeKitErrors" : []
  },
  "subscriptionGroups" : [
    {
      "id" : "SMARTCARD_PRO_GROUP",
      "localizations" : [],
      "name" : "SmartCard Pro",
      "subscriptions" : [
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "2.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "MONTHLY01",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Unlimited cards, auto bank detection, advanced analytics",
              "displayName" : "SmartCard Pro (Monthly)",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.smartcard.app.pro.monthly",
          "recurringSubscriptionPeriod" : "P1M",
          "referenceName" : "Pro Monthly",
          "subscriptionGroupID" : "SMARTCARD_PRO_GROUP",
          "type" : "RecurringSubscription"
        },
        {
          "adHocOffers" : [],
          "codeOffers" : [],
          "displayPrice" : "19.99",
          "familyShareable" : false,
          "groupNumber" : 1,
          "internalID" : "YEARLY01",
          "introductoryOffer" : null,
          "localizations" : [
            {
              "description" : "Unlimited cards, auto bank detection, advanced analytics",
              "displayName" : "SmartCard Pro (Yearly)",
              "locale" : "en_US"
            }
          ],
          "productID" : "com.smartcard.app.pro.yearly",
          "recurringSubscriptionPeriod" : "P1Y",
          "referenceName" : "Pro Yearly",
          "subscriptionGroupID" : "SMARTCARD_PRO_GROUP",
          "type" : "RecurringSubscription"
        }
      ]
    }
  ],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add SmartCard.storekit
git commit -m "chore: add local StoreKit configuration for Pro products"
```

> **Note for the implementer:** After Task 4, set this file as the scheme's StoreKit configuration in Xcode (Edit Scheme → Run → Options → StoreKit Configuration → `SmartCard.storekit`) so purchases work in the simulator. This is a manual Xcode step; document it but it does not block compilation.

---

### Task 3: SubscriptionManager (StoreKit 2 wrapper)

**Files:**
- Create: `SmartCard/Services/SubscriptionManager.swift`

StoreKit's live behavior can't be unit-tested without StoreKitTest + a simulator host; correctness here is verified by (a) it compiles, (b) the gate logic it feeds is already tested in Task 1, and (c) manual purchase flow in the simulator using the config from Task 2. So this task's verification is a successful build.

- [ ] **Step 1: Write the implementation**

Create `SmartCard/Services/SubscriptionManager.swift`:

```swift
import Foundation
import StoreKit

/// Wraps StoreKit 2 and exposes Pro entitlement state to the UI.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum ProductID {
        static let monthly = "com.smartcard.app.pro.monthly"
        static let yearly = "com.smartcard.app.pro.yearly"
        static var all: [String] { [monthly, yearly] }
    }

    @Published private(set) var isPro = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var loadFailed = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Load purchasable products, sorted by price (monthly first).
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: ProductID.all)
            products = storeProducts.sorted { $0.price < $1.price }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    /// Attempt to purchase a product. Returns true on a verified success.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await updateEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    /// Restore previous purchases (e.g., on a new device).
    func restorePurchases() async {
        try? await AppStore.sync()
        await updateEntitlements()
    }

    /// Derive `isPro` from current entitlements.
    func updateEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID), transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    /// Listen for transaction updates outside the purchase flow (renewals, restores).
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.updateEntitlements()
            }
        }
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodegen generate
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SmartCard/Services/SubscriptionManager.swift project.yml
git commit -m "feat: add SubscriptionManager StoreKit 2 wrapper"
```

---

### Task 4: Inject SubscriptionManager into the app

**Files:**
- Modify: `SmartCard/App/SmartCardApp.swift`

- [ ] **Step 1: Add the state object and inject it**

In `SmartCard/App/SmartCardApp.swift`, add the property alongside the existing view models:

```swift
    @StateObject private var cardViewModel = CardViewModel()
    @StateObject private var spendingViewModel = SpendingViewModel()
    @StateObject private var subscription = SubscriptionManager.shared
```

Then add `.environmentObject(subscription)` to BOTH branches (the `MainTabView()` branch and the `OnboardingView(...)` branch), next to the existing `.environmentObject(cardViewModel)` / `.environmentObject(spendingViewModel)` calls. For example the `MainTabView` branch becomes:

```swift
                MainTabView()
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .environmentObject(subscription)
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .background {
                            updateWidgetData()
                        }
                    }
                    .onAppear {
                        CacheManager.shared.clearExpired()
                        updateWidgetData()
                    }
```

And the `OnboardingView` branch:

```swift
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .environmentObject(subscription)
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SmartCard/App/SmartCardApp.swift
git commit -m "feat: inject SubscriptionManager into app environment"
```

---

### Task 5: PaywallView

**Files:**
- Create: `SmartCard/Views/Paywall/PaywallView.swift`

Reuses the existing `PrivacyPolicyView` and `TermsOfServiceView` (defined in `SmartCard/Views/Settings/LegalView.swift`) for the App Store-required legal links.

- [ ] **Step 1: Write the implementation**

Create `SmartCard/Views/Paywall/PaywallView.swift`:

```swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var isPurchasing = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    // v1 lists only the features actually enforced as Pro (see the plan's scope
    // decision). Add cap alerts / widget here when their enforcement lands.
    private let features: [(icon: String, text: String)] = [
        ("creditcard.fill", "Unlimited cards"),
        ("building.columns.fill", "Auto bank detection"),
        ("chart.bar.fill", "Advanced analytics & yearly summary")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow)
                        Text("SmartCard Pro")
                            .font(.largeTitle.bold())
                        Text("Maximize every swipe.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.text) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                Text(feature.text)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if subscription.loadFailed {
                        VStack(spacing: 8) {
                            Text("Couldn't load plans. Please try again.")
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await subscription.loadProducts() }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if subscription.products.isEmpty {
                        ProgressView().padding()
                    } else {
                        ForEach(subscription.products, id: \.id) { product in
                            Button {
                                Task {
                                    isPurchasing = true
                                    let success = await subscription.purchase(product)
                                    isPurchasing = false
                                    if success { dismiss() }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                            .fontWeight(.semibold)
                                        if product.id == SubscriptionManager.ProductID.yearly {
                                            Text("Best value — save ~44%")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isPurchasing)
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            await subscription.restorePurchases()
                            if subscription.isPro { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .disabled(isPurchasing)

                    // App Store-required auto-renewable subscription disclosure.
                    Text("""
                    Payment is charged to your Apple Account at confirmation of purchase. \
                    The subscription automatically renews unless it is canceled at least 24 hours \
                    before the end of the current period. Your account is charged for renewal within \
                    24 hours prior to the end of the current period. You can manage or cancel your \
                    subscription in your Apple Account settings after purchase.
                    """)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Button("Privacy Policy") { showingPrivacy = true }
                        Button("Terms of Service (EULA)") { showingTerms = true }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showingTerms) { TermsOfServiceView() }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
}
```

- [ ] **Step 2: Build to verify it compiles**

Run:
```bash
xcodegen generate
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add SmartCard/Views/Paywall/PaywallView.swift project.yml
git commit -m "feat: add PaywallView for SmartCard Pro upgrade"
```

---

### Task 6: Gate add-card on the free card limit

**Files:**
- Modify: `SmartCard/Views/Cards/CardListView.swift`

- [ ] **Step 1: Add subscription access, paywall state, and a gated add action**

In `struct CardListView`, add to the top of the struct (after the existing `@EnvironmentObject var cardViewModel`):

```swift
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showingPaywall = false
```

Add a helper method inside `CardListView` (above `deleteCards`):

```swift
    private func attemptAddCard() {
        if SubscriptionGate.canAddCard(currentCount: cardViewModel.userCards.count, isPro: subscription.isPro) {
            showingAddCard = true
        } else {
            showingPaywall = true
        }
    }
```

Replace BOTH `showingAddCard = true` call sites (the toolbar `+` button and the empty-state "Add Card" button) with `attemptAddCard()`. The empty-state button always has 0 cards so it will proceed; routing it through the same helper keeps one entry point.

Add the paywall sheet next to the existing `.sheet(isPresented: $showingAddCard)`:

```swift
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
```

- [ ] **Step 2: Update the preview to inject the environment object**

At the bottom of the file, update the `#Preview` so it compiles:

```swift
#Preview {
    CardListView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
```

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add SmartCard/Views/Cards/CardListView.swift
git commit -m "feat: gate adding a 4th card behind Pro"
```

---

### Task 7: Gate bank linking + add subscription management to Settings

**Files:**
- Modify: `SmartCard/Views/Settings/SettingsView.swift`

The "Bank Connection" section (around line 18) presents `LinkBankView` by setting `showingLinkBank = true`. Gate that, and add a "SmartCard Pro" section with an upgrade CTA / status.

- [ ] **Step 1: Add subscription access and paywall state**

In `struct SettingsView`, add near the other `@State` properties (lines 9-12):

```swift
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false
```

- [ ] **Step 2: Gate the bank-connection button**

In the "Bank Connection" section, find the button that sets `showingLinkBank = true` and change its action to:

```swift
                    Button {
                        if subscription.isPro {
                            showingLinkBank = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        // keep the existing label content unchanged
```

(Keep the existing label/Image/Text exactly as they were.)

- [ ] **Step 3: Add a SmartCard Pro section**

Add a new section near the top of the `Form` / `List` (above the "Bank Connection" section):

```swift
                Section("SmartCard Pro") {
                    if subscription.isPro {
                        HStack {
                            Label("Pro Active", systemImage: "star.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        Button {
                            showingManageSubscriptions = true
                        } label: {
                            Label("Manage Subscription", systemImage: "gearshape")
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Pro", systemImage: "star.circle.fill")
                                    .foregroundStyle(.yellow)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        Task { await subscription.restorePurchases() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }
```

App Store requires a way to manage/cancel an auto-renewable subscription from within the app. `manageSubscriptionsSheet` (iOS 15+) presents Apple's native management UI. Restore Purchases is shown to all users so anyone who bought on another device can recover access.

- [ ] **Step 4: Present the paywall sheet**

Next to the existing `.sheet(isPresented: $showingLinkBank)`, add:

```swift
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
```

`.manageSubscriptionsSheet` requires `import StoreKit` at the top of `SettingsView.swift` — add it if not already present.

- [ ] **Step 5: Update the preview (if present)**

If the file ends with a `#Preview { SettingsView() ... }`, add `.environmentObject(SubscriptionManager.shared)` to it. If the preview already injects other environment objects, add this alongside them. If there is no `#Preview`, skip.

- [ ] **Step 6: Build to verify it compiles**

Run:
```bash
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add SmartCard/Views/Settings/SettingsView.swift
git commit -m "feat: gate bank linking behind Pro and add upgrade entry in Settings"
```

---

### Task 8: Gate advanced analytics

**Files:**
- Modify: `SmartCard/Views/Spending/SpendingListView.swift`

`EnhancedAnalyticsView()` is presented as a sheet (around line 64) when `showingAnalytics` is set true (tapped around line 42). Gate that tap.

- [ ] **Step 1: Add subscription access and paywall state**

In `struct SpendingListView`, add near the existing `@State private var showingAnalytics = false` (line 7):

```swift
    @EnvironmentObject var subscription: SubscriptionManager
    @State private var showingPaywall = false
```

- [ ] **Step 2: Gate the analytics tap**

Find the button/action that sets `showingAnalytics = true` (around line 42) and change it to:

```swift
                        if subscription.isPro {
                            showingAnalytics = true
                        } else {
                            showingPaywall = true
                        }
```

- [ ] **Step 3: Present the paywall sheet**

Next to the existing `.sheet(isPresented: $showingAnalytics)`, add:

```swift
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
```

- [ ] **Step 4: Update the preview (if present)**

If the file has a `#Preview { SpendingListView() ... }`, add `.environmentObject(SubscriptionManager.shared)` to it alongside any existing environment objects.

- [ ] **Step 5: Build to verify it compiles**

Run:
```bash
xcodebuild build -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```bash
git add SmartCard/Views/Spending/SpendingListView.swift
git commit -m "feat: gate advanced analytics behind Pro"
```

---

### Task 9: Full regenerate, build, and test suite

**Files:** none (verification task)

- [ ] **Step 1: Regenerate the project**

Run:
```bash
xcodegen generate
```
Expected: project regenerated with all new files included.

- [ ] **Step 2: Run the full test suite**

Run:
```bash
xcodebuild test -project SmartCard.xcodeproj -scheme SmartCard \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```
Expected: TEST SUCCEEDED — existing tests (RecommendationEngine, MerchantDatabase, Model, SearchHistory) plus the new SubscriptionGate tests all pass.

- [ ] **Step 3: Manual smoke test (simulator)**

Set the scheme's StoreKit configuration to `SmartCard.storekit` (Edit Scheme → Run → Options → StoreKit Configuration). Then run the app and verify:
- Adding a 4th card shows the paywall.
- Settings → Bank Connection shows the paywall when not Pro.
- Spending → analytics shows the paywall when not Pro.
- Buying a plan in the simulator flips all three to unlocked.
- Settings shows "Pro Active" after purchase.

- [ ] **Step 4: Final commit (if any uncommitted changes remain, e.g. project.yml/pbxproj)**

```bash
git add -A
git commit -m "chore: regenerate project with Pro subscription files"
```

---

## Scope decision: which Pro features are enforced in v1

The spec lists five Pro features. This plan **enforces the three high-value, user-visible gates**: unlimited cards (Task 6), bank linking (Task 7), advanced analytics (Task 8). The `ProFeature` enum still defines `.capAlerts` and `.widget` (and they're covered by the gate tests), but their **enforcement is intentionally deferred**:
- **Cap alerts** live in `NotificationService` (background scheduling) — gating there risks silently dropping notifications and needs its own careful task.
- **Widget** runs in a separate process (`SmartCardWidget`) and reads shared data via `WidgetDataManager`; gating it requires plumbing `isPro` into the app group, a self-contained follow-up.

Both are tracked as a follow-up so v1 ships the strong gates without speculative cross-process work. Marketing copy in `PaywallView` still lists all five as Pro benefits, which is accurate the moment enforcement lands.

## App Store subscription-compliance checklist (mandatory — rejection causes)

These are required for an auto-renewable subscription to pass review. Code items are built by the tasks above; admin items are done by the developer in App Store Connect.

**In-app (code — covered by this plan):**
- [x] Auto-renew disclosure text next to the purchase buttons (Task 5) — title, duration, price, "auto-renews unless canceled", how to manage.
- [x] Functional Privacy Policy link in the paywall and Settings (Task 5 / existing `PrivacyPolicyView`).
- [x] Functional Terms of Service / EULA link in the paywall and Settings (Task 5 / existing `TermsOfServiceView`). If using Apple's standard EULA instead, link to https://www.apple.com/legal/internet-services/itunes/dev/stdeula/ from the App Store Connect metadata.
- [x] Restore Purchases button (Task 5 paywall + Task 7 Settings).
- [x] Manage Subscription entry (Task 7 Settings, `manageSubscriptionsSheet`).
- [x] Clear Data / account-data removal (already exists in Settings — `clearAllData`).

**Admin (developer must do in App Store Connect — NOT code):**
- [ ] Create the two subscription products (`com.smartcard.app.pro.monthly` $2.99, `com.smartcard.app.pro.yearly` $19.99) in subscription group "SmartCard Pro", with localized display names, descriptions, and a review screenshot of the paywall.
- [ ] Fill the **App Privacy** ("nutrition label") questionnaire — declare data collected (e.g., financial info via Plaid, usage data) and linkage. Required before submission.
- [ ] Provide a **support URL** and **support email** on the App Information page (store-page required field). Replace the placeholder `support@smartcardapp.com` in `SettingsView` with a real, monitored address.
- [ ] Host the Privacy Policy at a public URL and enter it in App Store Connect (the in-app copy is not sufficient on its own).
- [ ] Add the EULA (custom or Apple standard) in the app's metadata.

## Notes for the implementer
- This branch is `feature/pro-subscription`.
- The real App Store Connect products must be created before the feature works in production; the `.storekit` file only covers local/simulator testing.
- Other admin follow-ups tracked separately (out of scope for this plan): Plaid Production application, App Store rating URL.
