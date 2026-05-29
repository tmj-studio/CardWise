import Foundation

struct Spending: Identifiable, Codable, Equatable {
    let id: String
    let amount: Double
    let merchant: String
    let category: SpendingCategory
    let cardUsed: String          // cardId
    let date: Date
    let note: String?
    let rewardEarned: Double
    let optimalCardId: String?    // what would have been the best card
    let missedReward: Double?     // how much reward was missed

    init(
        amount: Double,
        merchant: String,
        category: SpendingCategory,
        cardUsed: String,
        date: Date = Date(),
        note: String? = nil,
        rewardEarned: Double,
        optimalCardId: String? = nil,
        missedReward: Double? = nil
    ) {
        self.id = UUID().uuidString
        self.amount = amount
        self.merchant = merchant
        self.category = category
        self.cardUsed = cardUsed
        self.date = date
        self.note = note
        self.rewardEarned = rewardEarned
        self.optimalCardId = optimalCardId
        self.missedReward = missedReward
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    var formattedReward: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: rewardEarned)) ?? "$\(rewardEarned)"
    }
}
