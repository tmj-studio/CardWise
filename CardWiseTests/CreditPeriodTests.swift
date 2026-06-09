import XCTest
@testable import CardWise

final class CreditPeriodTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func test_monthly_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 15), cadence: .monthly), "2026-06")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 1, 1), cadence: .monthly), "2026-01")
    }
    func test_quarterly_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 1, 1), cadence: .quarterly), "2026-Q1")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 30), cadence: .quarterly), "2026-Q2")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 12, 31), cadence: .quarterly), "2026-Q4")
        // every quarter boundary flip
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 3, 31), cadence: .quarterly), "2026-Q1")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 4, 1), cadence: .quarterly), "2026-Q2")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 7, 1), cadence: .quarterly), "2026-Q3")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 10, 1), cadence: .quarterly), "2026-Q4")
    }
    func test_semiannual_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 6, 30), cadence: .semiannual), "2026-H1")
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 7, 1), cadence: .semiannual), "2026-H2")
    }
    func test_annual_key() {
        XCTAssertEqual(CreditPeriod.key(for: date(2026, 3, 9), cadence: .annual), "2026")
    }
}
