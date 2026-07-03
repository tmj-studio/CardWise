import Foundation
import UserNotifications
import os

class NotificationService {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "NotificationService")
    static let shared = NotificationService()

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            #if DEBUG
            Self.logger.error("Notification permission error: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        Task {
            let granted = await requestPermission()
            await MainActor.run {
                completion(granted)
            }
        }
    }

    func checkPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Spending Cap Reminders

    func scheduleSpendingCapAlert(cardName: String, category: String, currentSpend: Double, cap: Double) {
        let percentage = (currentSpend / cap) * 100

        // Alert at 80% and 100%
        guard percentage >= 80 else { return }

        let content = UNMutableNotificationContent()

        if percentage >= 100 {
            content.title = "Spending Cap Reached!"
            content.body = "\(cardName) \(category): You've reached your $\(Int(cap)) cap. Rewards now at base rate."
        } else {
            content.title = "Approaching Spending Cap"
            content.body = "\(cardName) \(category): \(Int(percentage))% of $\(Int(cap)) cap used."
        }

        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "cap-\(cardName)-\(category)-\(Int(percentage))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    func shouldSendSpendingCapAlerts() -> Bool {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        let capAlertsEnabled = defaults.object(forKey: "spendingCapAlerts") as? Bool ?? true
        return notificationsEnabled && capAlertsEnabled
    }

    // MARK: - Rotating Category Reminders

    static let rotatingReminderIdentifiers = (1...4).map { "rotating-quarter-Q\($0)" }

    /// Date components for the four quarter starts (Jan/Apr/Jul/Oct 1st, 9:00 local), repeating yearly.
    static func quarterReminderDateComponents() -> [DateComponents] {
        [1, 4, 7, 10].map { month in
            var components = DateComponents()
            components.month = month
            components.day = 1
            components.hour = 9
            return components
        }
    }

    func shouldSendRotatingReminders() -> Bool {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        let rotatingEnabled = defaults.object(forKey: "rotatingReminders") as? Bool ?? true
        return notificationsEnabled && rotatingEnabled
    }

    /// (Re)schedule the repeating quarter-start reminders, or cancel them when the user
    /// has no rotating-category cards or has turned the toggles off.
    func refreshRotatingReminders(hasRotatingCards: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.rotatingReminderIdentifiers)

        guard hasRotatingCards, shouldSendRotatingReminders() else { return }

        for (index, components) in Self.quarterReminderDateComponents().enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "New Rotating Categories"
            content.body = "Q\(index + 1) just started — activate your cards' rotating bonus categories to earn the full rate."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: Self.rotatingReminderIdentifiers[index],
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    // MARK: - Clear Notifications

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func clearNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
