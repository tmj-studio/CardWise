import Foundation
import StoreKit

/// Wraps StoreKit 2 and exposes Pro entitlement state to the UI.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    enum ProductID {
        static let monthly = "com.smartcard.app.pro.monthly"
        static let yearly = "com.smartcard.app.pro.yearly"
        static let all = [monthly, yearly]
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
                // .unverified means the JWS signature didn't validate — treat as not purchased.
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
    private func updateEntitlements() async {
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
    /// Non-detached so it inherits this @MainActor context; `self` is held strongly
    /// because the singleton lives for the app's lifetime.
    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await updateEntitlements()
            }
        }
    }
}
