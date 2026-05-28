import Foundation

/// Features reserved for SmartCard Pro subscribers.
enum ProFeature: CaseIterable {
    case unlimitedCards
    case bankLinking
    case advancedAnalytics
    case capAlerts
    case widget
}

/// Pure, dependency-free entitlement logic. Kept separate from StoreKit so it
/// can be unit-tested without a StoreKit environment.
enum SubscriptionGate {
    /// Maximum number of cards a free (non-Pro) user may add.
    static let freeCardLimit: Int = 3

    /// Whether a user with `currentCount` cards may add one more.
    static func canAddCard(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freeCardLimit
    }

    /// Whether a Pro-gated feature is available to the user.
    /// All Pro features currently share the same gate; the `feature` parameter is
    /// accepted so per-feature gating can be added later without changing call sites.
    static func isUnlocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        isPro
    }
}
