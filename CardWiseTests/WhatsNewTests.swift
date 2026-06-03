import XCTest
@testable import CardWise

final class WhatsNewTests: XCTestCase {
    func test_freshInstall_showsNothing() {
        // Empty lastSeen => fresh install; onboarding handles the welcome, not What's New.
        XCTAssertTrue(WhatsNew.notesToPresent(lastSeen: "", current: "1.0.0").isEmpty)
    }

    func test_sameVersion_showsNothing() {
        XCTAssertTrue(WhatsNew.notesToPresent(lastSeen: "1.0.0", current: "1.0.0").isEmpty)
    }

    func test_upgrade_showsNewVersionNotes() {
        let notes = WhatsNew.notesToPresent(lastSeen: "0.9.0", current: "1.0.0")
        XCTAssertEqual(notes.map(\.version), ["1.0.0"])
    }

    func test_doesNotShowNotesNewerThanCurrent() {
        // A note for a version above `current` must never appear.
        let notes = WhatsNew.notesToPresent(lastSeen: "0.9.0", current: "0.9.5")
        XCTAssertTrue(notes.allSatisfy { AppVersion.compare($0.version, "0.9.5") != .orderedDescending })
    }
}
