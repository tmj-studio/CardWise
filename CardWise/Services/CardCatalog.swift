import Foundation
import os

/// On-disk / remote shape of the bundled card database.
struct CardCatalogFile: Decodable {
    let version: Int
    let updatedAt: String   // ISO-8601 date string, display only
    let cards: [CreditCard]
}

/// Loads the read-only credit-card reward database bundled with the app.
/// Replaces the former Firebase/Firestore download. Falls back to MockData
/// if the bundled file is missing or cannot be decoded.
enum CardCatalog {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "CardCatalog")

    static func decodeFile(from data: Data) -> CardCatalogFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CardCatalogFile.self, from: data)
    }

    static func decodeCards(from data: Data) -> [CreditCard] {
        // New wrapper format
        if let file = decodeFile(from: data), !file.cards.isEmpty {
            return file.cards
        }
        // Legacy bare-array format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let cards = try? decoder.decode([CreditCard].self, from: data), !cards.isEmpty {
            return cards
        }
        return MockData.creditCards
    }

    static func loadCards(cacheURL: URL? = RemoteCatalogService.defaultCacheURL) -> [CreditCard] {
        if let cacheURL, let cached = loadFromCache(cacheURL) {
            return cached
        }
        return loadFromBundle() ?? MockData.creditCards
    }

    static func currentVersion(cacheURL: URL? = RemoteCatalogService.defaultCacheURL) -> Int {
        if let cacheURL, let data = try? Data(contentsOf: cacheURL),
           let file = decodeFile(from: data) {
            return file.version
        }
        if let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
           let data = try? Data(contentsOf: url), let file = decodeFile(from: data) {
            return file.version
        }
        return 0
    }

    private static func loadFromCache(_ cacheURL: URL) -> [CreditCard]? {
        guard let data = try? Data(contentsOf: cacheURL),
              let file = decodeFile(from: data), !file.cards.isEmpty else { return nil }
        return file.cards
    }

    private static func loadFromBundle() -> [CreditCard]? {
        guard let url = Bundle.main.url(forResource: "cards", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            #if DEBUG
            logger.error("cards.json not found in bundle; using MockData")
            #endif
            return nil
        }
        let cards = decodeCards(from: data)
        return cards.isEmpty ? nil : cards
    }
}
