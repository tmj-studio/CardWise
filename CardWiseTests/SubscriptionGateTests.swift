import XCTest
@testable import CardWise

final class SubscriptionGateTests: XCTestCase {

    // MARK: - Card limit

    func testFreeUserCanAddUpToLimit() {
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 0, isPro: false))
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 2, isPro: false))
    }

    func testFreeUserBlockedAtLimit() {
        XCTAssertFalse(SubscriptionGate.canAddCard(currentCount: SubscriptionGate.freeCardLimit, isPro: false))
        XCTAssertFalse(SubscriptionGate.canAddCard(currentCount: 5, isPro: false))
    }

    func testProUserHasUnlimitedCards() {
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: SubscriptionGate.freeCardLimit, isPro: true))
        XCTAssertTrue(SubscriptionGate.canAddCard(currentCount: 99, isPro: true))
    }

    // MARK: - Feature flags

    func testProFeaturesLockedForFreeUser() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(SubscriptionGate.isUnlocked(feature, isPro: false),
                           "\(feature) should be locked for free users")
        }
    }

    func testProFeaturesUnlockedForProUser() {
        for feature in ProFeature.allCases {
            XCTAssertTrue(SubscriptionGate.isUnlocked(feature, isPro: true),
                          "\(feature) should be unlocked for Pro users")
        }
    }
}
