import XCTest
@testable import SmartCard

final class ModelTests: XCTestCase {

    // MARK: - CreditCard Tests

    func testCreditCardBaseRewardDisplay() {
        let card = MockData.creditCards.first { $0.id == "citi-double-cash" }!
        XCTAssertEqual(card.displayBaseReward, "2%", "Citi Double Cash should show 2%")
    }

    func testCreditCardPointsDisplay() {
        let card = MockData.creditCards.first { $0.id == "chase-sapphire-preferred" }!
        XCTAssertEqual(card.displayBaseReward, "1x", "CSP should show 1x")
    }

    // MARK: - UserCard Tests

    func testUserCardUtilization() {
        var userCard = UserCard(card: MockData.creditCards[0], creditLimit: 10000)
        userCard.currentBalance = 3000

        XCTAssertNotNil(userCard.utilization)
        XCTAssertEqual(userCard.utilization!, 30.0, accuracy: 0.1, "Utilization should be 30%")
    }

    func testUserCardUtilizationWithZeroLimit() {
        var userCard = UserCard(card: MockData.creditCards[0], creditLimit: 0)
        userCard.currentBalance = 100

        XCTAssertNil(userCard.utilization, "Utilization should be nil with zero limit")
    }

    func testUserCardUtilizationWithoutBalance() {
        let userCard = UserCard(card: MockData.creditCards[0], creditLimit: 10000)

        XCTAssertNil(userCard.utilization, "Utilization should be nil without balance")
    }

    // MARK: - CapPeriod Tests

    func testCapPeriodMonthlyStartDate() {
        let startDate = CapPeriod.monthly.startDate
        let calendar = Calendar.current
        let day = calendar.component(.day, from: startDate)

        XCTAssertEqual(day, 1, "Monthly start date should be first of month")
    }

    func testCapPeriodQuarterlyStartDate() {
        let startDate = CapPeriod.quarterly.startDate
        let calendar = Calendar.current
        let month = calendar.component(.month, from: startDate)
        let day = calendar.component(.day, from: startDate)

        XCTAssertTrue([1, 4, 7, 10].contains(month), "Quarterly start should be Jan, Apr, Jul, or Oct")
        XCTAssertEqual(day, 1, "Quarterly start should be first of quarter")
    }

    func testCapPeriodYearlyStartDate() {
        let startDate = CapPeriod.yearly.startDate
        let calendar = Calendar.current
        let month = calendar.component(.month, from: startDate)
        let day = calendar.component(.day, from: startDate)

        XCTAssertEqual(month, 1, "Yearly start should be January")
        XCTAssertEqual(day, 1, "Yearly start should be first day")
    }

    // MARK: - CategoryReward Tests

    func testCategoryRewardDisplayMultiplier() {
        let cashbackReward = CategoryReward(
            category: .grocery,
            multiplier: 6,
            isPercentage: true,
            cap: 6000,
            capPeriod: .yearly
        )
        XCTAssertEqual(cashbackReward.displayMultiplier, "6%")

        let pointsReward = CategoryReward(
            category: .dining,
            multiplier: 4,
            isPercentage: false,
            cap: nil,
            capPeriod: nil
        )
        XCTAssertEqual(pointsReward.displayMultiplier, "4x")
    }

    // MARK: - RotatingCategory Tests

    func testRotatingCategoryCurrentQuarter() {
        let currentQ = RotatingCategory.currentQuarter()
        XCTAssertTrue((1...4).contains(currentQ), "Quarter should be 1-4")
    }

    func testRotatingCategoryCurrentYear() {
        let currentY = RotatingCategory.currentYear()
        XCTAssertGreaterThanOrEqual(currentY, 2025, "Year should be 2025 or later")
    }

    // MARK: - SignUpBonus Tests

    func testSignUpBonusFormattedBonus() {
        let pointsBonus = SignUpBonus(
            bonusAmount: 60000,
            bonusType: .points,
            spendRequirement: 4000,
            timeframeDays: 90,
            description: "Test"
        )
        XCTAssertEqual(pointsBonus.formattedBonus, "60,000 points")

        let cashBonus = SignUpBonus(
            bonusAmount: 200,
            bonusType: .cashback,
            spendRequirement: 500,
            timeframeDays: 90,
            description: "Test"
        )
        XCTAssertEqual(cashBonus.formattedBonus, "$200")

        let milesBonus = SignUpBonus(
            bonusAmount: 50000,
            bonusType: .miles,
            spendRequirement: 3000,
            timeframeDays: 90,
            description: "Test"
        )
        XCTAssertEqual(milesBonus.formattedBonus, "50,000 miles")
    }

    // MARK: - SpendingCategory Tests

    func testAllCategoriesHaveIcons() {
        for category in SpendingCategory.allCases {
            XCTAssertFalse(category.icon.isEmpty, "\(category.rawValue) should have an icon")
        }
    }
}
