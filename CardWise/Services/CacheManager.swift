import Foundation

/// A simple in-memory cache with expiration support
final class CacheManager {
    static let shared = CacheManager()

    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "com.smartcard.cache", attributes: .concurrent)

    private init() {}

    struct CacheEntry {
        let value: Any
        let expiration: Date

        var isExpired: Bool {
            Date() > expiration
        }
    }

    /// Store a value in cache with expiration
    func set<T>(_ value: T, forKey key: String, ttl: TimeInterval = 300) {
        let entry = CacheEntry(
            value: value,
            expiration: Date().addingTimeInterval(ttl)
        )
        queue.async(flags: .barrier) { [weak self] in
            self?.cache[key] = entry
        }
    }

    /// Retrieve a value from cache
    func get<T>(forKey key: String) -> T? {
        var result: T?
        queue.sync { [weak self] in
            guard let entry = self?.cache[key],
                  !entry.isExpired,
                  let value = entry.value as? T else {
                return
            }
            result = value
        }
        return result
    }

    /// Remove a specific key from cache
    func remove(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeValue(forKey: key)
        }
    }

    /// Clear all expired entries
    func clearExpired() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache = self?.cache.filter { !$0.value.isExpired } ?? [:]
        }
    }

    /// Clear all cache
    func clearAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.cache.removeAll()
        }
    }
}

// MARK: - Recommendation Cache Keys

extension CacheManager {
    /// Generate cache key for recommendations
    static func recommendationKey(category: SpendingCategory, amount: Double, userCardCount: Int) -> String {
        "recommendations_\(category.rawValue)_\(Int(amount))_\(userCardCount)"
    }

    /// Generate cache key for merchant search
    static func merchantSearchKey(query: String) -> String {
        "merchant_\(query.lowercased())"
    }
}

// MARK: - Cached Recommendation Engine Extension

extension RecommendationEngine {
    /// Get cached recommendations (with 5 minute TTL)
    func getCachedRecommendations(
        for category: SpendingCategory,
        amount: Double = 100,
        userCards: [UserCard],
        allCards: [CreditCard],
        spendings: [Spending] = []
    ) -> [CardRecommendation] {
        let cacheKey = CacheManager.recommendationKey(
            category: category,
            amount: amount,
            userCardCount: userCards.count
        )

        // Try to get from cache
        if let cached: [CardRecommendation] = CacheManager.shared.get(forKey: cacheKey) {
            return cached
        }

        // Calculate and cache
        let recommendations = getRecommendations(
            for: category,
            amount: amount,
            userCards: userCards,
            allCards: allCards,
            spendings: spendings
        )

        CacheManager.shared.set(recommendations, forKey: cacheKey, ttl: 300) // 5 minutes
        return recommendations
    }
}

// MARK: - Cached Merchant Search Extension

extension MerchantDatabase {
    /// Search merchants with caching
    static func searchMerchantsCached(query: String) -> [Merchant] {
        guard !query.isEmpty else { return [] }

        let cacheKey = CacheManager.merchantSearchKey(query: query)

        // Try to get from cache
        if let cached: [Merchant] = CacheManager.shared.get(forKey: cacheKey) {
            return cached
        }

        // Search and cache
        let results = searchMerchants(query: query)
        CacheManager.shared.set(results, forKey: cacheKey, ttl: 600) // 10 minutes
        return results
    }

    /// Suggest category with caching
    static func suggestCategoryCached(for merchant: String) -> SpendingCategory? {
        guard !merchant.isEmpty else { return nil }

        let cacheKey = "category_\(merchant.lowercased())"

        // Try to get from cache
        if let cached: SpendingCategory = CacheManager.shared.get(forKey: cacheKey) {
            return cached
        }

        // Suggest and cache
        if let category = suggestCategory(for: merchant) {
            CacheManager.shared.set(category, forKey: cacheKey, ttl: 600) // 10 minutes
            return category
        }

        return nil
    }
}
