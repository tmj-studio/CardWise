import XCTest
@testable import CardWise

final class RecommendationEngineTests: XCTestCase {

    var userCards: [UserCard]!
    var allCards: [CreditCard]!

    override func setUpWithError() throws {
        allCards = MockData.creditCards
        let csp = allCards.first { $0.id == "chase-sapphire-preferred" }!
        let cff = allCards.first { $0.id == "chase-freedom-flex" }!
        let amexGold = allCards.first { $0.id == "amex-gold" }!
        userCards = [
            UserCard(card: csp),
            UserCard(card: cff),
            UserCard(card: amexGold),
        ]
    }

    override func tearDownWithError() throws {
        userCards = nil
        allCards = nil
    }

    // MARK: - Basic Recommendation Tests

    func testRecommendationsReturnedForCategory() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        XCTAssertFalse(recommendations.isEmpty, "Should return recommendations for dining category")
        XCTAssertEqual(recommendations.count, userCards.count, "Should return one recommendation per user card")
    }

    func testRecommendationsSortedByReward() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        // Verify sorted by estimated reward (descending)
        for i in 0..<(recommendations.count - 1) {
            // Note: Sign-up bonus cards may be prioritized, so check both cases
            if !recommendations[i].hasSignUpBonusInProgress && !recommendations[i + 1].hasSignUpBonusInProgress {
                XCTAssertGreaterThanOrEqual(
                    recommendations[i].estimatedReward,
                    recommendations[i + 1].estimatedReward,
                    "Recommendations should be sorted by estimated reward"
                )
            }
        }
    }

    func testDiningRecommendationPrefersFourPercentCard() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        // Amex Gold has 4x on dining, should be highest
        let topRec = recommendations.first(where: { !$0.hasSignUpBonusInProgress })
        XCTAssertEqual(topRec?.card.id, "amex-gold", "Amex Gold (4x dining) should be top recommendation for dining")
    }

    func testGroceryRecommendation() {
        // Mark the rotating card as activated for the current quarter so its bonus counts
        if let cffIndex = userCards.firstIndex(where: { $0.cardId == "chase-freedom-flex" }) {
            userCards[cffIndex].setRotatingActivated(
                true,
                quarter: RotatingCategory.currentQuarter(),
                year: RotatingCategory.currentYear()
            )
        }

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        let topRec = recommendations.first(where: { !$0.hasSignUpBonusInProgress })

        // In Q1, an ACTIVATED CFF has 5x rotating grocery which beats Amex Gold's 4x
        if RotatingCategory.currentQuarter() == 1 {
            XCTAssertEqual(topRec?.card.id, "chase-freedom-flex", "Activated CFF (5x rotating grocery in Q1) should be top recommendation")
        } else {
            XCTAssertEqual(topRec?.card.id, "amex-gold", "Amex Gold (4x grocery) should be top recommendation for grocery")
        }
    }

    // MARK: - Estimated Reward Calculation

    func testEstimatedRewardCalculation() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        // Find Amex Gold recommendation (4x points)
        let amexRec = recommendations.first { $0.card.id == "amex-gold" }
        XCTAssertNotNil(amexRec)

        // 100 * 4 points = 400 points * 0.01 cpp = $4.00
        XCTAssertEqual(amexRec?.estimatedReward ?? 0, 4.0, accuracy: 0.01, "4x points on $100 should equal ~$4 estimated reward")
    }

    func testCashbackEstimatedReward() {
        // Add Blue Cash Preferred (6% grocery cashback)
        let bcpCard = allCards.first { $0.id == "amex-blue-cash-preferred" }!
        let bcpUserCard = UserCard(card: bcpCard)

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery,
            amount: 100,
            userCards: [bcpUserCard],
            allCards: allCards
        )

        let bcpRec = recommendations.first { $0.card.id == "amex-blue-cash-preferred" }
        XCTAssertNotNil(bcpRec)

        // 6% cashback on $100 = $6.00
        XCTAssertEqual(bcpRec?.estimatedReward ?? 0, 6.0, accuracy: 0.01, "6% cashback on $100 should equal $6")
    }

    // MARK: - Rotating Category Tests

    func testRotatingCategoryDetection() {
        // Chase Freedom Flex has rotating categories
        let freedomCard = allCards.first { $0.id == "chase-freedom-flex" }!
        let freedomUserCard = UserCard(card: freedomCard)

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery, // Q1 2025 rotating category
            amount: 100,
            userCards: [freedomUserCard],
            allCards: allCards
        )

        let rec = recommendations.first { $0.card.id == "chase-freedom-flex" }
        XCTAssertNotNil(rec)

        // Should detect as rotating category (if in Q1)
        if RotatingCategory.currentQuarter() == 1 {
            XCTAssertTrue(rec?.isRotating ?? false, "Should detect Q1 grocery as rotating category")
            XCTAssertTrue(rec?.needsActivation ?? false, "Should indicate activation needed for non-activated card")
        }
    }

    // MARK: - Spending Cap Tests

    /// 1% base cashback card with 6% on grocery, capped at $100/month.
    private func makeCappedCashbackCard() -> CreditCard {
        CreditCard(
            id: "test-capped-card",
            name: "Test Capped Card",
            issuer: "Test Bank",
            network: .visa,
            annualFee: 0,
            rewardType: .cashback,
            baseReward: 1,
            baseIsPercentage: true,
            categoryRewards: [
                CategoryReward(category: .grocery, multiplier: 6, isPercentage: true, cap: 100, capPeriod: .monthly)
            ],
            rotatingCategories: nil,
            selectableConfig: nil,
            signUpBonus: nil,
            imageColor: "#000000",
            imageURL: nil,
            lastUpdated: nil
        )
    }

    func testExhaustedCapFallsBackToBaseReward() {
        let card = makeCappedCashbackCard()
        let userCard = UserCard(card: card)
        // The full $100 monthly grocery cap was already spent this period
        let spent = Spending(amount: 100, merchant: "Costco", category: .grocery, cardUsed: card.id, rewardEarned: 6)

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery,
            amount: 50,
            userCards: [userCard],
            allCards: [card],
            spendings: [spent]
        )

        let rec = recommendations.first { $0.card.id == card.id }
        XCTAssertNotNil(rec)
        XCTAssertEqual(rec?.spendingCapRemaining ?? -1, 0, accuracy: 0.001, "Cap should be fully exhausted")
        // Cap exhausted → the whole $50 earns the 1% base rate ($0.50), not 6% ($3.00)
        XCTAssertEqual(rec?.estimatedReward ?? 0, 0.5, accuracy: 0.001,
                       "Exhausted cap must fall back to base reward for the full amount")
    }

    func testPartiallyRemainingCapProratesReward() {
        let card = makeCappedCashbackCard()
        let userCard = UserCard(card: card)
        // $80 spent → $20 of the cap left
        let spent = Spending(amount: 80, merchant: "Costco", category: .grocery, cardUsed: card.id, rewardEarned: 4.8)

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery,
            amount: 50,
            userCards: [userCard],
            allCards: [card],
            spendings: [spent]
        )

        let rec = recommendations.first { $0.card.id == card.id }
        // $20 at 6% + $30 at 1% = $1.20 + $0.30 = $1.50
        XCTAssertEqual(rec?.estimatedReward ?? 0, 1.5, accuracy: 0.001,
                       "Amount above the remaining cap should earn base rate")
    }

    // MARK: - Rotating Activation Tests

    /// 1% base cashback card with a 5% rotating gas category in the CURRENT quarter, activation required.
    private func makeRotatingCard() -> CreditCard {
        CreditCard(
            id: "test-rotating-card",
            name: "Test Rotating Card",
            issuer: "Test Bank",
            network: .visa,
            annualFee: 0,
            rewardType: .cashback,
            baseReward: 1,
            baseIsPercentage: true,
            categoryRewards: [],
            rotatingCategories: [
                RotatingCategory(
                    quarter: RotatingCategory.currentQuarter(),
                    year: RotatingCategory.currentYear(),
                    categories: [.gas],
                    multiplier: 5,
                    isPercentage: true,
                    cap: nil,
                    activationRequired: true
                )
            ],
            selectableConfig: nil,
            signUpBonus: nil,
            imageColor: "#000000",
            imageURL: nil,
            lastUpdated: nil
        )
    }

    func testUnactivatedRotatingScoresAtBaseRate() {
        let card = makeRotatingCard()
        let userCard = UserCard(card: card) // never activated

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .gas,
            amount: 100,
            userCards: [userCard],
            allCards: [card]
        )

        let rec = recommendations.first { $0.card.id == card.id }
        XCTAssertNotNil(rec)
        XCTAssertTrue(rec?.needsActivation ?? false, "Un-activated rotating bonus should be flagged")
        XCTAssertTrue(rec?.isRotating ?? false)
        // Not activated → earns 1% base, not 5%
        XCTAssertEqual(rec?.effectiveReward ?? 0, 1.0, accuracy: 0.001,
                       "Un-activated rotating category must score at base rate")
        XCTAssertEqual(rec?.estimatedReward ?? 0, 1.0, accuracy: 0.001,
                       "$100 at 1% base = $1, not $5")
    }

    func testActivatedRotatingScoresAtFullMultiplier() {
        let card = makeRotatingCard()
        var userCard = UserCard(card: card)
        userCard.setRotatingActivated(
            true,
            quarter: RotatingCategory.currentQuarter(),
            year: RotatingCategory.currentYear()
        )

        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .gas,
            amount: 100,
            userCards: [userCard],
            allCards: [card]
        )

        let rec = recommendations.first { $0.card.id == card.id }
        XCTAssertNotNil(rec)
        XCTAssertFalse(rec?.needsActivation ?? true, "Activated card no longer needs activation")
        XCTAssertEqual(rec?.effectiveReward ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(rec?.estimatedReward ?? 0, 5.0, accuracy: 0.001, "$100 at 5% = $5 once activated")
    }

    func testUserCardDecodesWithoutActivationField() throws {
        // Backwards compatibility: UserCards persisted before the activation feature
        // must still decode (activatedRotatingQuarters absent → nil).
        let card = makeRotatingCard()
        var legacy = UserCard(card: card)
        legacy.activatedRotatingQuarters = nil
        let data = try JSONEncoder().encode(legacy)
        let decoded = try JSONDecoder().decode(UserCard.self, from: data)
        XCTAssertFalse(decoded.hasActivatedRotating(quarter: 1, year: 2026))
    }

    // MARK: - Empty State Tests

    func testEmptyUserCardsReturnsEmpty() {
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .dining,
            amount: 100,
            userCards: [],
            allCards: allCards
        )

        XCTAssertTrue(recommendations.isEmpty, "Should return empty array when no user cards")
    }

    // MARK: - Merchant Detection Tests

    func testMerchantCategoryDetection() {
        let (recommendations, detectedCategory) = RecommendationEngine.shared.getRecommendations(
            for: "Starbucks",
            amount: 10,
            userCards: userCards,
            allCards: allCards
        )

        XCTAssertEqual(detectedCategory, .dining, "Starbucks should be detected as dining")
        XCTAssertFalse(recommendations.isEmpty)
    }

    func testUnknownMerchantDefaultsToOther() {
        let (_, detectedCategory) = RecommendationEngine.shared.getRecommendations(
            for: "RandomUnknownStore12345",
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        XCTAssertNil(detectedCategory, "Unknown merchant should return nil category")
    }
}
