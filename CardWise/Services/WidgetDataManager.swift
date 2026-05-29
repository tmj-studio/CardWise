import Foundation
import WidgetKit

@MainActor
class WidgetDataManager {
    static let shared = WidgetDataManager()

    private static let appGroupID = "group.com.cardwise.app"
    private static let widgetDataKey = "widget_data"

    private let defaults: UserDefaults? = {
        let suite = UserDefaults(suiteName: appGroupID)
        if suite == nil {
            assertionFailure("Failed to create UserDefaults suite '\(appGroupID)' — check App Group entitlements")
        }
        return suite
    }()

    private init() {}

    // MARK: - Widget Data Model

    struct WidgetPayload: Codable {
        let topCategory: String
        let topCategoryIcon: String
        let bestCard: String
        let bestCardColor: String
        let rewardRate: String
        let rotatingCategories: [String]
        let rotatingCard: String?
        let spendingThisMonth: Double
        let rewardsThisMonth: Double
    }

    // MARK: - Write Widget Data

    func updateWidgetData(
        cardViewModel: CardViewModel,
        spendingViewModel: SpendingViewModel,
        isPro: Bool
    ) {
        guard SubscriptionGate.isUnlocked(.widget, isPro: isPro) else {
            writePayload(
                WidgetPayload(
                    topCategory: "CardWise Pro",
                    topCategoryIcon: "star.circle",
                    bestCard: "Upgrade to Pro",
                    bestCardColor: "#808080",
                    rewardRate: "Pro",
                    rotatingCategories: [],
                    rotatingCard: nil,
                    spendingThisMonth: 0,
                    rewardsThisMonth: 0
                )
            )
            return
        }

        // Find best card for common category (Dining as default)
        let diningRecs = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: cardViewModel.userCards,
            allCards: cardViewModel.allCards
        )

        var payload: WidgetPayload

        if let topRec = diningRecs.first {
            // Get rotating categories
            let currentQ = Date().currentQuarter
            let currentY = RotatingCategory.currentYear()

            var rotatingCategories: [String] = []
            var rotatingCard: String?

            for userCard in cardViewModel.userCards {
                guard let card = cardViewModel.getCard(for: userCard),
                      let rotating = card.rotatingCategories,
                      let currentRotating = rotating.first(where: { $0.quarter == currentQ && $0.year == currentY }) else {
                    continue
                }

                rotatingCategories = currentRotating.categories.map { $0.rawValue }
                rotatingCard = userCard.nickname ?? card.name
                break
            }

            // This month stats
            let thisMonthSpendings = spendingViewModel.spendingsThisMonth()
            let totalSpent = thisMonthSpendings.reduce(0) { $0 + $1.amount }
            let totalRewards = thisMonthSpendings.reduce(0) { $0 + $1.rewardEarned }

            payload = WidgetPayload(
                topCategory: "Dining",
                topCategoryIcon: "fork.knife",
                bestCard: topRec.userCard.nickname ?? topRec.card.name,
                bestCardColor: topRec.card.imageColor,
                rewardRate: topRec.displayReward,
                rotatingCategories: rotatingCategories,
                rotatingCard: rotatingCard,
                spendingThisMonth: totalSpent,
                rewardsThisMonth: totalRewards
            )
        } else {
            let thisMonthSpendings = spendingViewModel.spendingsThisMonth()
            let totalSpent = thisMonthSpendings.reduce(0) { $0 + $1.amount }
            let totalRewards = thisMonthSpendings.reduce(0) { $0 + $1.rewardEarned }

            payload = WidgetPayload(
                topCategory: "Dining",
                topCategoryIcon: "fork.knife",
                bestCard: "Add Cards",
                bestCardColor: "#808080",
                rewardRate: "-",
                rotatingCategories: [],
                rotatingCard: nil,
                spendingThisMonth: totalSpent,
                rewardsThisMonth: totalRewards
            )
        }

        writePayload(payload)
    }

    private func writePayload(_ payload: WidgetPayload) {
        if let jsonData = try? JSONEncoder().encode(payload) {
            defaults?.set(jsonData, forKey: Self.widgetDataKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read Widget Data (for Widget extension)

    static func loadWidgetPayload() -> WidgetPayload? {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let data = defaults?.data(forKey: widgetDataKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}
