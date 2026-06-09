import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class CreditUsageStoreTests: XCTestCase {
    private func makeStore() throws -> CloudStore {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CloudStore(context: ModelContext(container))
    }

    func test_compositeID_isStable() {
        let u = CreditUsage(cardID: "card1", creditID: "dining", periodKey: "2026-06", amountUsed: 4)
        XCTAssertEqual(u.id, "card1|dining|2026-06")
    }

    func test_saveThenLoad_roundTrips() throws {
        let store = try makeStore()
        let u = CreditUsage(cardID: "card1", creditID: "dining", periodKey: "2026-06", amountUsed: 4)
        try store.saveCreditUsages([u])
        XCTAssertEqual(store.loadCreditUsages(), [u])
    }

    func test_save_prunesRemoved() throws {
        let store = try makeStore()
        let a = CreditUsage(cardID: "c", creditID: "x", periodKey: "2026-06", amountUsed: 1)
        let b = CreditUsage(cardID: "c", creditID: "y", periodKey: "2026-06", amountUsed: 2)
        try store.saveCreditUsages([a, b])
        try store.saveCreditUsages([a])
        XCTAssertEqual(store.loadCreditUsages(), [a])
    }

    func test_save_updatesExisting() throws {
        let store = try makeStore()
        var u = CreditUsage(cardID: "c", creditID: "x", periodKey: "2026-06", amountUsed: 1)
        try store.saveCreditUsages([u])
        u.amountUsed = 9
        try store.saveCreditUsages([u])
        XCTAssertEqual(store.loadCreditUsages().first?.amountUsed, 9)
    }
}
