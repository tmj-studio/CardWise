import Foundation

/// Per-user usage of one statement credit within one calendar period.
struct CreditUsage: Codable, Equatable, Identifiable {
    let id: String          // "\(cardID)|\(creditID)|\(periodKey)"
    let cardID: String
    let creditID: String
    let periodKey: String
    var amountUsed: Double

    init(cardID: String, creditID: String, periodKey: String, amountUsed: Double) {
        self.id = "\(cardID)|\(creditID)|\(periodKey)"
        self.cardID = cardID
        self.creditID = creditID
        self.periodKey = periodKey
        self.amountUsed = amountUsed
    }
}
