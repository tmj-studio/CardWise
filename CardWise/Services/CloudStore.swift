import Foundation
import SwiftData
import os

@Model
final class UserCardRecord {
    var id: String = ""
    var payload: Data = Data()
    init(id: String = "", payload: Data = Data()) {
        self.id = id
        self.payload = payload
    }
}

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

    func saveUserCards(_ cards: [UserCard]) throws {
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
        try context.save()
    }

    // MARK: - Spendings
    func loadSpendings() -> [Spending] {
        let records = (try? context.fetch(FetchDescriptor<SpendingRecord>())) ?? []
        return records
            .compactMap { try? decoder.decode(Spending.self, from: $0.payload) }
            .sorted { $0.date > $1.date }
    }

    func saveSpendings(_ spendings: [Spending]) throws {
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
        try context.save()
    }

    // MARK: - One-time Keychain migration
    /// Migrates legacy Keychain data into SwiftData exactly once, then clears the
    /// Keychain. Guarded by a UserDefaults flag so it never runs twice.
    func migrateFromKeychainIfNeeded() {
        let flag = "didMigrateKeychainToSwiftData"
        guard !UserDefaults.standard.bool(forKey: flag) else { return }
        var allSucceeded = true

        if let cards: [UserCard] = try? KeychainHelper.shared.load(forKey: "userCards"), !cards.isEmpty {
            do {
                try saveUserCards(cards)
                KeychainHelper.shared.delete(forKey: "userCards")
            } catch {
                allSucceeded = false
                #if DEBUG
                Self.logger.error("UserCard migration failed: \(error.localizedDescription)")
                #endif
            }
        }
        if let spendings: [Spending] = try? KeychainHelper.shared.load(forKey: "spendings"), !spendings.isEmpty {
            do {
                try saveSpendings(spendings)
                KeychainHelper.shared.delete(forKey: "spendings")
            } catch {
                allSucceeded = false
                #if DEBUG
                Self.logger.error("Spending migration failed: \(error.localizedDescription)")
                #endif
            }
        }

        if allSucceeded {
            UserDefaults.standard.set(true, forKey: flag)
        }
    }
}

// MARK: - Preview / Test helpers

extension CloudStore {
    /// Returns an in-memory CloudStore suitable for SwiftUI #Previews and tests.
    @MainActor
    static func preview() -> CloudStore {
        // swiftlint:disable:next force_try - preview/test-only in-memory store
        let container = try! ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return CloudStore(context: container.mainContext)
    }
}
