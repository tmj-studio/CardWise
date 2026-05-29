import Foundation

struct CardRecommendation: Identifiable, Equatable {
    let id: String
    let card: CreditCard
    let userCard: UserCard
    let effectiveReward: Double
    let isPercentage: Bool
    let estimatedReward: Double  // for a given amount
    let reason: String
    let isRotating: Bool
    let isSelectable: Bool
    let needsActivation: Bool

    // Additional context for improved recommendations
    let signUpBonusProgress: SignUpBonusProgress?
    let spendingCapRemaining: Double?
    let isNearSpendingCap: Bool

    var displayReward: String {
        if isPercentage {
            return "\(Int(effectiveReward))%"
        } else {
            return "\(Int(effectiveReward))x"
        }
    }

    var formattedEstimatedReward: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: estimatedReward)) ?? "$\(estimatedReward)"
    }

    var hasSignUpBonusInProgress: Bool {
        guard let progress = signUpBonusProgress else { return false }
        return !progress.isAchieved && progress.daysRemaining > 0
    }
}

/// Tracks sign-up bonus progress
struct SignUpBonusProgress: Equatable {
    let spentSoFar: Double
    let requirement: Double
    let daysRemaining: Int
    let isAchieved: Bool

    var percentComplete: Double {
        min(100, (spentSoFar / requirement) * 100)
    }

    var amountRemaining: Double {
        max(0, requirement - spentSoFar)
    }

    var formattedProgress: String {
        "$\(Int(spentSoFar)) / $\(Int(requirement))"
    }
}

class RecommendationEngine {
    static let shared = RecommendationEngine()

    private init() {}

    /// Get card recommendations for a spending category
    func getRecommendations(
        for category: SpendingCategory,
        amount: Double = 100,
        userCards: [UserCard],
        allCards: [CreditCard],
        spendings: [Spending] = []  // Optional: for sign-up bonus and cap tracking
    ) -> [CardRecommendation] {
        var recommendations: [CardRecommendation] = []

        for userCard in userCards {
            guard let card = allCards.first(where: { $0.id == userCard.cardId }) else {
                continue
            }

            let reward = calculateEffectiveReward(
                card: card,
                userCard: userCard,
                category: category
            )

            // Calculate spending cap status
            let capInfo = calculateSpendingCapInfo(
                card: card,
                userCard: userCard,
                category: category,
                spendings: spendings,
                amount: amount
            )

            // Calculate sign-up bonus progress
            let bonusProgress = calculateSignUpBonusProgress(
                card: card,
                userCard: userCard,
                spendings: spendings
            )

            // Adjust estimated reward if near spending cap
            var estimatedReward = calculateEstimatedReward(
                amount: amount,
                multiplier: reward.multiplier,
                isPercentage: reward.isPercentage,
                rewardType: card.rewardType
            )

            // If near cap, only count reward up to the remaining cap
            if let remaining = capInfo.remaining, remaining < amount && remaining > 0 {
                let rewardOnRemaining = calculateEstimatedReward(
                    amount: remaining,
                    multiplier: reward.multiplier,
                    isPercentage: reward.isPercentage,
                    rewardType: card.rewardType
                )
                let baseRewardOnRest = calculateEstimatedReward(
                    amount: amount - remaining,
                    multiplier: card.baseReward,
                    isPercentage: card.baseIsPercentage,
                    rewardType: card.rewardType
                )
                estimatedReward = rewardOnRemaining + baseRewardOnRest
            }

            let recommendation = CardRecommendation(
                id: userCard.id,
                card: card,
                userCard: userCard,
                effectiveReward: reward.multiplier,
                isPercentage: reward.isPercentage,
                estimatedReward: estimatedReward,
                reason: reward.reason,
                isRotating: reward.isRotating,
                isSelectable: reward.isSelectable,
                needsActivation: reward.needsActivation,
                signUpBonusProgress: bonusProgress,
                spendingCapRemaining: capInfo.remaining,
                isNearSpendingCap: capInfo.isNearCap
            )

            recommendations.append(recommendation)
        }

        // Sort by: 1) Sign-up bonus in progress (prioritize), 2) Estimated reward (highest first)
        return recommendations.sorted { rec1, rec2 in
            // Prioritize cards with sign-up bonus in progress
            if rec1.hasSignUpBonusInProgress != rec2.hasSignUpBonusInProgress {
                return rec1.hasSignUpBonusInProgress
            }
            // Then by estimated reward
            return rec1.estimatedReward > rec2.estimatedReward
        }
    }

    /// Get recommendations for a merchant (auto-detect category)
    func getRecommendations(
        for merchantName: String,
        amount: Double = 100,
        userCards: [UserCard],
        allCards: [CreditCard]
    ) -> (recommendations: [CardRecommendation], detectedCategory: SpendingCategory?) {
        let detectedCategory = MerchantDatabase.suggestCategory(for: merchantName)
        let category = detectedCategory ?? .other

        let recommendations = getRecommendations(
            for: category,
            amount: amount,
            userCards: userCards,
            allCards: allCards
        )

        return (recommendations, detectedCategory)
    }

    private struct RewardInfo {
        let multiplier: Double
        let isPercentage: Bool
        let reason: String
        let isRotating: Bool
        let isSelectable: Bool
        let needsActivation: Bool
    }

    private func calculateEffectiveReward(
        card: CreditCard,
        userCard: UserCard,
        category: SpendingCategory
    ) -> RewardInfo {
        // Check fixed category rewards first
        if let categoryReward = card.categoryRewards.first(where: { $0.category == category }) {
            return RewardInfo(
                multiplier: categoryReward.multiplier,
                isPercentage: categoryReward.isPercentage,
                reason: "\(categoryReward.displayMultiplier) on \(category.displayName)",
                isRotating: false,
                isSelectable: false,
                needsActivation: false
            )
        }

        // Check rotating categories
        if let rotating = card.rotatingCategories {
            let currentQ = RotatingCategory.currentQuarter()
            let currentY = RotatingCategory.currentYear()

            if let currentRotating = rotating.first(where: { $0.quarter == currentQ && $0.year == currentY }) {
                if currentRotating.categories.contains(category) {
                    return RewardInfo(
                        multiplier: currentRotating.multiplier,
                        isPercentage: currentRotating.isPercentage,
                        reason: "\(currentRotating.displayMultiplier) Q\(currentQ) rotating category",
                        isRotating: true,
                        isSelectable: false,
                        needsActivation: currentRotating.activationRequired
                    )
                }
            }
        }

        // Check selectable categories
        if let config = card.selectableConfig {
            if let selected = userCard.selectedCategories, selected.contains(category) {
                return RewardInfo(
                    multiplier: config.multiplier,
                    isPercentage: config.isPercentage,
                    reason: "\(config.multiplier)\(config.isPercentage ? "%" : "x") selected category",
                    isRotating: false,
                    isSelectable: true,
                    needsActivation: false
                )
            } else if config.availableCategories.contains(category) {
                // Could be selected but isn't
                return RewardInfo(
                    multiplier: card.baseReward,
                    isPercentage: card.baseIsPercentage,
                    reason: "Base reward (can select \(category.displayName) for \(config.multiplier)\(config.isPercentage ? "%" : "x"))",
                    isRotating: false,
                    isSelectable: true,
                    needsActivation: false
                )
            }
        }

        // Fall back to base reward
        return RewardInfo(
            multiplier: card.baseReward,
            isPercentage: card.baseIsPercentage,
            reason: "Base reward",
            isRotating: false,
            isSelectable: false,
            needsActivation: false
        )
    }

    private func calculateEstimatedReward(
        amount: Double,
        multiplier: Double,
        isPercentage: Bool,
        rewardType: RewardType
    ) -> Double {
        if isPercentage {
            // Direct cash back percentage
            return amount * (multiplier / 100)
        } else {
            // Points/miles - estimate value at standard cpp
            let points = amount * multiplier
            return points * RewardConstants.defaultPointsValueCPP
        }
    }

    private struct SpendingCapInfo {
        let remaining: Double?
        let isNearCap: Bool
    }

    private func calculateSpendingCapInfo(
        card: CreditCard,
        userCard: UserCard,
        category: SpendingCategory,
        spendings: [Spending],
        amount: Double
    ) -> SpendingCapInfo {
        // Find applicable cap for this category
        var cap: Double?
        var capPeriod: CapPeriod?

        // Check fixed category rewards
        if let categoryReward = card.categoryRewards.first(where: { $0.category == category }) {
            cap = categoryReward.cap
            capPeriod = categoryReward.capPeriod
        }

        // Check rotating categories
        if cap == nil, let rotating = card.rotatingCategories {
            let currentQ = RotatingCategory.currentQuarter()
            let currentY = RotatingCategory.currentYear()
            if let currentRotating = rotating.first(where: { $0.quarter == currentQ && $0.year == currentY }) {
                if currentRotating.categories.contains(category) {
                    cap = currentRotating.cap
                    capPeriod = .quarterly
                }
            }
        }

        // Check selectable categories
        if cap == nil, let config = card.selectableConfig,
           let selected = userCard.selectedCategories, selected.contains(category) {
            cap = config.cap
            capPeriod = config.capPeriod
        }

        guard let spendingCap = cap, let period = capPeriod else {
            return SpendingCapInfo(remaining: nil, isNearCap: false)
        }

        // Calculate spending in this period for this card in this category
        let periodStart = period.startDate
        let spentInPeriod = spendings
            .filter { $0.cardUsed == userCard.cardId && $0.category == category && $0.date >= periodStart }
            .reduce(0) { $0 + $1.amount }

        let remaining = max(0, spendingCap - spentInPeriod)
        let isNearCap = remaining < amount || (remaining / spendingCap) < 0.2

        return SpendingCapInfo(remaining: remaining, isNearCap: isNearCap)
    }

    private func calculateSignUpBonusProgress(
        card: CreditCard,
        userCard: UserCard,
        spendings: [Spending]
    ) -> SignUpBonusProgress? {
        guard let bonus = card.signUpBonus,
              let startDate = userCard.signUpBonusStartDate,
              !userCard.signUpBonusAchieved else {
            return nil
        }

        let daysRemaining = userCard.daysRemainingForBonus(for: card) ?? 0

        // Calculate spending since sign-up bonus start
        let spentSoFar = spendings
            .filter { $0.cardUsed == userCard.cardId && $0.date >= startDate }
            .reduce(0) { $0 + $1.amount }

        let isAchieved = spentSoFar >= bonus.spendRequirement

        return SignUpBonusProgress(
            spentSoFar: spentSoFar,
            requirement: bonus.spendRequirement,
            daysRemaining: daysRemaining,
            isAchieved: isAchieved
        )
    }

    /// Suggest optimal category selections for cards with selectable categories
    func suggestCategorySelections(
        userCards: [UserCard],
        allCards: [CreditCard],
        spendingHistory: [Spending]
    ) -> [String: [SpendingCategory]] {
        var suggestions: [String: [SpendingCategory]] = [:]

        for userCard in userCards {
            guard let card = allCards.first(where: { $0.id == userCard.cardId }),
                  let config = card.selectableConfig else {
                continue
            }

            // Analyze spending history to find top categories
            let categorySpending = Dictionary(grouping: spendingHistory, by: { $0.category })
            let sortedCategories = categorySpending
                .filter { config.availableCategories.contains($0.key) }
                .sorted { $0.value.reduce(0) { $0 + $1.amount } > $1.value.reduce(0) { $0 + $1.amount } }
                .prefix(config.maxSelections)
                .map { $0.key }

            if !sortedCategories.isEmpty {
                suggestions[userCard.id] = Array(sortedCategories)
            }
        }

        return suggestions
    }
}
