import XCTest
@testable import CardWise

final class CreditModelTests: XCTestCase {
    func test_statementCredit_decodesFromJSON() throws {
        let json = #"""
        {"id":"amex-gold-dining","description":"Dining credit","amount":10,
         "cadence":"monthly","category":"dining"}
        """#
        let credit = try JSONDecoder().decode(StatementCredit.self, from: Data(json.utf8))
        XCTAssertEqual(credit.id, "amex-gold-dining")
        XCTAssertEqual(credit.amount, 10)
        XCTAssertEqual(credit.cadence, .monthly)
        XCTAssertEqual(credit.category, .dining)
    }

    func test_statementCredit_categoryIsOptional() throws {
        let json = #"{"id":"c1","description":"X","amount":50,"cadence":"annual"}"#
        let credit = try JSONDecoder().decode(StatementCredit.self, from: Data(json.utf8))
        XCTAssertNil(credit.category)
    }

    func test_annualizedAmount_multipliesByPeriodsPerYear() {
        let monthly = StatementCredit(id: "m", description: "", amount: 10, cadence: .monthly, category: nil)
        let annual = StatementCredit(id: "a", description: "", amount: 200, cadence: .annual, category: nil)
        XCTAssertEqual(monthly.annualizedAmount, 120)
        XCTAssertEqual(annual.annualizedAmount, 200)
    }

    func test_annualizedCreditTotal_sumsAnnualized() {
        let c = CreditCard(id: "t", name: "T", issuer: "X", network: .amex, annualFee: 325,
            rewardType: .points, baseReward: 1, baseIsPercentage: false, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil,
            credits: [
                StatementCredit(id: "d", description: "Dining", amount: 10, cadence: .monthly, category: .dining),
                StatementCredit(id: "u", description: "Uber", amount: 10, cadence: .monthly, category: .transit)
            ])
        XCTAssertEqual(c.annualizedCreditTotal, 240)
        XCTAssertEqual(c.netAnnualFee, 85)
    }

    func test_netAnnualFee_equalsAnnualFee_whenNoCredits() {
        let c = CreditCard(id: "t2", name: "T2", issuer: "X", network: .visa, annualFee: 95,
            rewardType: .cashback, baseReward: 1, baseIsPercentage: true, categoryRewards: [],
            rotatingCategories: nil, selectableConfig: nil, signUpBonus: nil,
            imageColor: "#000000", imageURL: nil, lastUpdated: nil)
        XCTAssertEqual(c.annualizedCreditTotal, 0)
        XCTAssertEqual(c.netAnnualFee, 95)
    }
}
