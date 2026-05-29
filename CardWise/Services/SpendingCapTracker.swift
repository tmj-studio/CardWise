import Foundation

struct SpendingCapProgress: Identifiable {
    let id: String
    let cardId: String
    let cardName: String
    let category: String
    let currentSpend: Double
    let cap: Double?  // nil means unlimited
    let period: CapPeriod?
    let isRotating: Bool

    var isUnlimited: Bool {
        cap == nil
    }

    var percentage: Double {
        guard let cap = cap, cap > 0 else { return 0 }
        return min((currentSpend / cap) * 100, 100)
    }

    var remaining: Double {
        guard let cap = cap else { return .infinity }
        return max(cap - currentSpend, 0)
    }

    var isNearCap: Bool {
        guard !isUnlimited else { return false }
        return percentage >= 80
    }

    var isAtCap: Bool {
        guard !isUnlimited else { return false }
        return percentage >= 100
    }

    var formattedProgress: String {
        guard let cap = cap else {
            return "$\(Int(currentSpend)) / Unlimited"
        }
        return "$\(Int(currentSpend)) / $\(Int(cap))"
    }

    var formattedRemaining: String {
        guard let cap = cap else {
            return "Unlimited"
        }
        return "$\(Int(max(cap - currentSpend, 0))) remaining"
    }
}

class SpendingCapTracker {
    static let shared = SpendingCapTracker()

    private init() {}

    /// Calculate spending cap progress for all user cards
    func calculateCapProgress(
        userCards: [UserCard],
        allCards: [CreditCard],
        spendings: [Spending]
    ) -> [SpendingCapProgress] {
        var results: [SpendingCapProgress] = []

        for userCard in userCards {
            guard let card = allCards.first(where: { $0.id == userCard.cardId }) else {
                continue
            }

            // Check fixed category rewards with caps
            for reward in card.categoryRewards {
                if let cap = reward.cap, let period = reward.capPeriod {
                    let spend = calculateSpendInPeriod(
                        spendings: spendings,
                        cardId: card.id,
                        category: reward.category,
                        period: period
                    )

                    results.append(SpendingCapProgress(
                        id: "\(card.id)-\(reward.category.rawValue)",
                        cardId: card.id,
                        cardName: userCard.nickname ?? card.name,
                        category: reward.category.rawValue,
                        currentSpend: spend,
                        cap: cap,
                        period: period,
                        isRotating: false
                    ))
                }
            }

            // Check rotating categories with caps
            if let rotating = card.rotatingCategories {
                let currentQ = RotatingCategory.currentQuarter()
                let currentY = RotatingCategory.currentYear()

                if let currentRotating = rotating.first(where: { $0.quarter == currentQ && $0.year == currentY }),
                   let cap = currentRotating.cap {
                    // Sum spending across all rotating categories
                    var totalSpend: Double = 0
                    for category in currentRotating.categories {
                        totalSpend += calculateSpendInPeriod(
                            spendings: spendings,
                            cardId: card.id,
                            category: category,
                            period: .quarterly
                        )
                    }

                    results.append(SpendingCapProgress(
                        id: "\(card.id)-rotating-Q\(currentQ)",
                        cardId: card.id,
                        cardName: userCard.nickname ?? card.name,
                        category: "Q\(currentQ) Rotating (\(currentRotating.categories.map { $0.rawValue }.joined(separator: ", ")))",
                        currentSpend: totalSpend,
                        cap: cap,
                        period: .quarterly,
                        isRotating: true
                    ))
                }
            }

            // Check selectable categories with caps
            if let config = card.selectableConfig,
               let cap = config.cap,
               let capPeriod = config.capPeriod,
               let selectedCategories = userCard.selectedCategories {
                var totalSpend: Double = 0
                for category in selectedCategories {
                    totalSpend += calculateSpendInPeriod(
                        spendings: spendings,
                        cardId: card.id,
                        category: category,
                        period: capPeriod
                    )
                }

                results.append(SpendingCapProgress(
                    id: "\(card.id)-selectable",
                    cardId: card.id,
                    cardName: userCard.nickname ?? card.name,
                    category: "Selected (\(selectedCategories.map { $0.rawValue }.joined(separator: ", ")))",
                    currentSpend: totalSpend,
                    cap: cap,
                    period: capPeriod,
                    isRotating: false
                ))
            }
        }

        return results.sorted { $0.percentage > $1.percentage }
    }

    private func calculateSpendInPeriod(
        spendings: [Spending],
        cardId: String,
        category: SpendingCategory,
        period: CapPeriod
    ) -> Double {
        let startDate = getStartDate(for: period)

        return spendings
            .filter { $0.cardUsed == cardId && $0.category == category && $0.date >= startDate }
            .reduce(0) { $0 + $1.amount }
    }

    private func getStartDate(for period: CapPeriod) -> Date {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? Date()

        case .quarterly:
            let month = calendar.component(.month, from: now)
            let quarter = (month - 1) / 3 + 1
            let startMonth = (quarter - 1) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = startMonth
            components.day = 1
            return calendar.date(from: components) ?? Date()

        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? Date()
        }
    }

    /// Check if any caps are near limit and send notifications
    func checkAndNotify(
        userCards: [UserCard],
        allCards: [CreditCard],
        spendings: [Spending]
    ) {
        let progress = calculateCapProgress(userCards: userCards, allCards: allCards, spendings: spendings)

        for cap in progress where cap.isNearCap {
            guard let capValue = cap.cap else { continue }
            NotificationService.shared.scheduleSpendingCapAlert(
                cardName: cap.cardName,
                category: cap.category,
                currentSpend: cap.currentSpend,
                cap: capValue
            )
        }
    }
}
