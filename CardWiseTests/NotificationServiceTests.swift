import XCTest
@testable import CardWise

final class NotificationServiceTests: XCTestCase {

    private let defaults = UserDefaults.standard
    private var savedNotificationsEnabled: Any?
    private var savedRotatingReminders: Any?

    override func setUpWithError() throws {
        savedNotificationsEnabled = defaults.object(forKey: "notificationsEnabled")
        savedRotatingReminders = defaults.object(forKey: "rotatingReminders")
    }

    override func tearDownWithError() throws {
        defaults.set(savedNotificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(savedRotatingReminders, forKey: "rotatingReminders")
    }

    // MARK: - Quarter reminder schedule

    func testQuarterReminderDateComponentsCoverAllFourQuarterStarts() {
        let components = NotificationService.quarterReminderDateComponents()

        XCTAssertEqual(components.count, 4, "One reminder per quarter")
        XCTAssertEqual(components.compactMap(\.month), [1, 4, 7, 10], "Quarters start in Jan/Apr/Jul/Oct")
        XCTAssertTrue(components.allSatisfy { $0.day == 1 }, "Reminders fire on the first day of the quarter")
    }

    func testRotatingReminderIdentifiersAreStable() {
        // Cancellation relies on these identifiers matching what was scheduled
        XCTAssertEqual(
            NotificationService.rotatingReminderIdentifiers,
            ["rotating-quarter-Q1", "rotating-quarter-Q2", "rotating-quarter-Q3", "rotating-quarter-Q4"]
        )
    }

    // MARK: - Settings gate

    func testShouldSendRotatingRemindersRespectsToggles() {
        defaults.set(true, forKey: "notificationsEnabled")
        defaults.set(true, forKey: "rotatingReminders")
        XCTAssertTrue(NotificationService.shared.shouldSendRotatingReminders())

        defaults.set(false, forKey: "rotatingReminders")
        XCTAssertFalse(NotificationService.shared.shouldSendRotatingReminders(),
                       "Rotating toggle off must disable reminders")

        defaults.set(true, forKey: "rotatingReminders")
        defaults.set(false, forKey: "notificationsEnabled")
        XCTAssertFalse(NotificationService.shared.shouldSendRotatingReminders(),
                       "Master notifications toggle off must disable reminders")
    }
}
