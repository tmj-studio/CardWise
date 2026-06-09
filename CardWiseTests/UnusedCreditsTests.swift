import XCTest
import SwiftData
@testable import CardWise

@MainActor
final class UnusedCreditsTests: XCTestCase {
    private func makeVM() throws -> CardViewModel {
        let container = try ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return CardViewModel(store: CloudStore(context: ModelContext(container)))
    }
    private func card(_ id: String, _ credits: [StatementCredit]) -> CreditCard {
        CreditCard(id: id, name: "Card \(id)", issuer: "X", network: .visa, annualFee: 100,
            rewardType: .points, baseReward: 1, baseIsPercentage: false, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil, credits: credits)
    }

    func test_unusedCredits_listsRemainingAndSortsMonthlyFirst() throws {
        let vm = try makeVM()
        let c = card("c1", [
            StatementCredit(id: "annualx", description: "Annual", amount: 200, cadence: .annual, category: nil),
            StatementCredit(id: "dining", description: "Dining", amount: 10, cadence: .monthly, category: .dining)
        ])
        vm.allCards = [c]; vm.addCard(c)
        let unused = vm.unusedCreditsThisPeriod
        XCTAssertEqual(unused.map { $0.credit.id }, ["dining", "annualx"])
        XCTAssertEqual(unused.first?.remaining, 10)
        XCTAssertEqual(vm.totalUnusedCredits, 210)
    }

    func test_unusedCredits_excludesFullyUsed() throws {
        let vm = try makeVM()
        let c = card("c2", [StatementCredit(id: "dining", description: "Dining", amount: 10, cadence: .monthly, category: .dining)])
        vm.allCards = [c]; vm.addCard(c)
        let pk = CreditPeriod.key(for: Date(), cadence: .monthly)
        vm.setUsedAmount(10, cardID: "c2", creditID: "dining", periodKey: pk)
        XCTAssertTrue(vm.unusedCreditsThisPeriod.isEmpty)
        XCTAssertEqual(vm.totalUnusedCredits, 0)
    }

    func test_unusedCredits_emptyWhenNoCreditCards() throws {
        let vm = try makeVM()
        XCTAssertTrue(vm.unusedCreditsThisPeriod.isEmpty)
    }
}
