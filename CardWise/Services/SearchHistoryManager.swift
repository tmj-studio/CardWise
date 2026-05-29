import Foundation

/// Manages search history for merchant recommendations
class SearchHistoryManager {
    static let shared = SearchHistoryManager()

    private let keychainKey = "searchHistory"
    private let userDefaultsKey = UserDefaultsKeys.searchHistory
    private let maxHistoryItems = 20

    /// In-memory cache (fallback when Keychain is unavailable, e.g. CI)
    private var cachedItems: [SearchItem]?

    private init() {}

    /// Recent search terms with timestamps
    struct SearchItem: Codable, Identifiable, Equatable {
        let id: UUID
        let query: String
        let category: String?  // Detected category name
        let timestamp: Date

        init(query: String, category: SpendingCategory?) {
            self.id = UUID()
            self.query = query
            self.category = category?.rawValue
            self.timestamp = Date()
        }

        var spendingCategory: SpendingCategory? {
            guard let category = category else { return nil }
            return SpendingCategory(rawValue: category)
        }

        var displayText: String {
            if let category = category {
                return "\(query) (\(category))"
            }
            return query
        }
    }

    /// Get all search history items (Keychain-first with in-memory cache fallback)
    var history: [SearchItem] {
        // Try Keychain first
        if let items: [SearchItem] = try? KeychainHelper.shared.load(forKey: keychainKey) {
            cachedItems = items
            return items.sorted { $0.timestamp > $1.timestamp }
        }

        // Fallback: in-memory cache (covers CI/testing where Keychain is unavailable)
        if let cached = cachedItems {
            return cached.sorted { $0.timestamp > $1.timestamp }
        }

        // Fallback: migrate from UserDefaults
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([SearchItem].self, from: data) {
            try? KeychainHelper.shared.save(items, forKey: keychainKey)
            cachedItems = items
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            return items.sorted { $0.timestamp > $1.timestamp }
        }

        return []
    }

    /// Add a search term to history
    func addSearch(_ query: String, category: SpendingCategory?) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        var items = history

        // Remove duplicate (same query)
        items.removeAll { $0.query.lowercased() == trimmedQuery.lowercased() }

        // Add new item at the beginning
        let newItem = SearchItem(query: trimmedQuery, category: category)
        items.insert(newItem, at: 0)

        // Limit to max items
        if items.count > maxHistoryItems {
            items = Array(items.prefix(maxHistoryItems))
        }

        save(items)
    }

    /// Remove a specific search item
    func removeSearch(_ item: SearchItem) {
        var items = history
        items.removeAll { $0.id == item.id }
        save(items)
    }

    /// Clear all search history
    func clearHistory() {
        cachedItems = nil
        KeychainHelper.shared.delete(forKey: keychainKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    /// Get recent searches (limited)
    func recentSearches(limit: Int = 5) -> [SearchItem] {
        Array(history.prefix(limit))
    }

    /// Search within history
    func searchHistory(query: String) -> [SearchItem] {
        guard !query.isEmpty else { return history }
        return history.filter { $0.query.lowercased().contains(query.lowercased()) }
    }

    private func save(_ items: [SearchItem]) {
        cachedItems = items
        try? KeychainHelper.shared.save(items, forKey: keychainKey)
    }
}
