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
}
