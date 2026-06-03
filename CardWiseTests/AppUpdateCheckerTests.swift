import XCTest
@testable import CardWise

final class AppUpdateCheckerTests: XCTestCase {
    func test_shouldPrompt_whenStoreNewerAndNotDismissed() {
        XCTAssertTrue(AppUpdateChecker.shouldPrompt(installed: "1.0.0", store: "1.1.0", dismissed: ""))
    }

    func test_shouldNotPrompt_whenStoreNotNewer() {
        XCTAssertFalse(AppUpdateChecker.shouldPrompt(installed: "1.1.0", store: "1.1.0", dismissed: ""))
        XCTAssertFalse(AppUpdateChecker.shouldPrompt(installed: "1.2.0", store: "1.1.0", dismissed: ""))
    }

    func test_shouldNotPrompt_whenVersionDismissed() {
        XCTAssertFalse(AppUpdateChecker.shouldPrompt(installed: "1.0.0", store: "1.1.0", dismissed: "1.1.0"))
    }

    func test_lookupURL_buildsExpectedQuery() {
        let url = AppUpdateChecker.lookupURL(bundleID: "studio.tmj.cardwise", country: "us")
        XCTAssertEqual(url?.absoluteString,
                       "https://itunes.apple.com/lookup?bundleId=studio.tmj.cardwise&country=us")
    }

    func test_parse_validResponse() {
        let json = #"{"resultCount":1,"results":[{"version":"2.3.1","trackViewUrl":"https://apps.apple.com/app/id6776198130"}]}"#
        let info = AppUpdateChecker.parse(Data(json.utf8))
        XCTAssertEqual(info?.version, "2.3.1")
        XCTAssertEqual(info?.trackViewUrl, "https://apps.apple.com/app/id6776198130")
    }

    func test_parse_emptyResults_returnsNil() {
        let json = #"{"resultCount":0,"results":[]}"#
        XCTAssertNil(AppUpdateChecker.parse(Data(json.utf8)))
    }

    func test_parse_garbage_returnsNil() {
        XCTAssertNil(AppUpdateChecker.parse(Data("not json".utf8)))
    }
}
