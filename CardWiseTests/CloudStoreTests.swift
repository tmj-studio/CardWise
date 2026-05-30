import XCTest
import SwiftData
@testable import CardWise

final class CloudStoreTests: XCTestCase {

    func test_saveAndLoadUserCards_roundTrips() async throws {
        try await MainActor.run {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: UserCardRecord.self, SpendingRecord.self,
                configurations: config
            )
            let store = CloudStore(context: container.mainContext)
            let card = MockData.creditCards[0]
            let userCard = UserCard(card: card, nickname: "Daily")
            try store.saveUserCards([userCard])
            let loaded = store.loadUserCards()
            XCTAssertEqual(loaded.count, 1)
            XCTAssertEqual(loaded.first?.id, userCard.id)
            XCTAssertEqual(loaded.first?.nickname, "Daily")
        }
    }

    func test_saveUserCards_replacesRemoved() async throws {
        try await MainActor.run {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: UserCardRecord.self, SpendingRecord.self,
                configurations: config
            )
            let store = CloudStore(context: container.mainContext)
            let a = UserCard(card: MockData.creditCards[0])
            let b = UserCard(card: MockData.creditCards[1])
            try store.saveUserCards([a, b])
            try store.saveUserCards([a])
            let loaded = store.loadUserCards()
            XCTAssertEqual(loaded.map { $0.id }, [a.id])
        }
    }

    func test_saveAndLoadSpendings_roundTrips() async throws {
        try await MainActor.run {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: UserCardRecord.self, SpendingRecord.self,
                configurations: config
            )
            let store = CloudStore(context: container.mainContext)
            let s = Spending(amount: 12.5, merchant: "Cafe", category: .dining,
                             cardUsed: "card-1", rewardEarned: 0.5)
            try store.saveSpendings([s])
            let loaded = store.loadSpendings()
            XCTAssertEqual(loaded.count, 1)
            XCTAssertEqual(loaded.first?.merchant, "Cafe")
        }
    }
}
