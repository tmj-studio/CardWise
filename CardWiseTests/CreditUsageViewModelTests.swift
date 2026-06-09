import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class CreditUsageViewModelTests: XCTestCase {
    private func makeVM() throws -> CardViewModel {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CardViewModel(store: CloudStore(context: ModelContext(container)))
    }

    func test_usedAmount_isZero_whenNothingTracked() throws {
        let vm = try makeVM()
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-06"), 0)
    }

    func test_setUsedAmount_thenRead_returnsValue() throws {
        let vm = try makeVM()
        vm.setUsedAmount(8, cardID: "c", creditID: "dining", periodKey: "2026-06")
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-06"), 8)
    }

    func test_setUsedAmount_persistsAcrossReload() throws {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = CloudStore(context: ModelContext(container))
        let vm1 = CardViewModel(store: store)
        vm1.setUsedAmount(5, cardID: "c", creditID: "x", periodKey: "2026-06")
        let vm2 = CardViewModel(store: store)
        XCTAssertEqual(vm2.usedAmount(cardID: "c", creditID: "x", periodKey: "2026-06"), 5)
    }

    func test_differentPeriod_isIndependent() throws {
        let vm = try makeVM()
        vm.setUsedAmount(8, cardID: "c", creditID: "dining", periodKey: "2026-06")
        XCTAssertEqual(vm.usedAmount(cardID: "c", creditID: "dining", periodKey: "2026-07"), 0)
    }
}
