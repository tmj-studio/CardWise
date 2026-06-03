import XCTest
@testable import CardWise

final class AppVersionTests: XCTestCase {
    func test_compare_equalVersions() {
        XCTAssertEqual(AppVersion.compare("1.0.0", "1.0.0"), .orderedSame)
        XCTAssertEqual(AppVersion.compare("1.2", "1.2.0"), .orderedSame, "missing components are zero")
    }

    func test_compare_ordering() {
        XCTAssertEqual(AppVersion.compare("1.0.0", "1.0.1"), .orderedAscending)
        XCTAssertEqual(AppVersion.compare("1.2.0", "1.10.0"), .orderedAscending, "numeric, not lexicographic")
        XCTAssertEqual(AppVersion.compare("2.0.0", "1.9.9"), .orderedDescending)
    }

    func test_isNewer() {
        XCTAssertTrue(AppVersion.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertFalse(AppVersion.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(AppVersion.isNewer("0.9.0", than: "1.0.0"))
    }

    func test_compare_toleratesJunk() {
        XCTAssertEqual(AppVersion.compare("1.2.0-beta", "1.2.0"), .orderedSame)
    }
}
