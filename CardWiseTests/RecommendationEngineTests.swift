import XCTest
@testable import SmartCard

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
        let recommendations = RecommendationEngine.shared.getRecommendations(
            for: .grocery,
            amount: 100,
            userCards: userCards,
            allCards: allCards
        )

        let topRec = recommendations.first(where: { !$0.hasSignUpBonusInProgress })

        // In Q1, CFF has 5x rotating grocery which beats Amex Gold's 4x
        if RotatingCategory.currentQuarter() == 1 {
            XCTAssertEqual(topRec?.card.id, "chase-freedom-flex", "CFF (5x rotating grocery in Q1) should be top recommendation")
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
