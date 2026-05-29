import Foundation

enum RewardConstants {
    static let defaultPointsValueCPP = 0.01
}

enum CardNetwork: String, Codable, CaseIterable {
    case visa
    case mastercard
    case amex
    case discover

    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "Amex"
        case .discover: return "Discover"
        }
    }
}

enum RewardType: String, Codable, CaseIterable {
    case cashback
    case points
    case miles

    var displayName: String {
        switch self {
        case .cashback: return "Cash Back"
        case .points: return "Points"
        case .miles: return "Miles"
        }
    }
}

struct CategoryReward: Codable, Identifiable, Equatable {
    var id: String { category.rawValue }
    let category: SpendingCategory
    let multiplier: Double  // e.g., 3.0 for 3x or 3%
    let isPercentage: Bool  // true for cashback %, false for points multiplier
    let cap: Double?        // spending cap (e.g., $1,500)
    let capPeriod: CapPeriod?

    var displayMultiplier: String {
        if isPercentage {
            return "\(Int(multiplier))%"
        } else {
            return "\(Int(multiplier))x"
        }
    }
}

struct RotatingCategory: Codable, Identifiable, Equatable {
    var id: String { "\(year)-Q\(quarter)" }
    let quarter: Int
    let year: Int
    let categories: [SpendingCategory]
    let multiplier: Double
    let isPercentage: Bool
    let cap: Double?
    let activationRequired: Bool

    var displayMultiplier: String {
        if isPercentage {
            return "\(Int(multiplier))%"
        } else {
            return "\(Int(multiplier))x"
        }
    }

    static func currentQuarter() -> Int {
        let month = Calendar.current.component(.month, from: Date())
        return ((month - 1) / 3) + 1
    }

    static func currentYear() -> Int {
        Calendar.current.component(.year, from: Date())
    }
}

struct SelectableConfig: Codable, Equatable {
    let maxSelections: Int           // how many categories can be selected
    let availableCategories: [SpendingCategory]
    let multiplier: Double
    let isPercentage: Bool
    let cap: Double?
    let capPeriod: CapPeriod?
}

/// Sign-up bonus configuration
struct SignUpBonus: Codable, Equatable {
    let bonusAmount: Double       // e.g., 60000 points or $200
    let bonusType: RewardType     // points, miles, or cashback
    let spendRequirement: Double  // e.g., $4000
    let timeframeDays: Int        // e.g., 90 days
    let description: String       // e.g., "60,000 points after $4,000 in 3 months"

    var formattedBonus: String {
        switch bonusType {
        case .cashback:
            return "$\(Int(bonusAmount))"
        case .points:
            return "\(Int(bonusAmount).formatted()) points"
        case .miles:
            return "\(Int(bonusAmount).formatted()) miles"
        }
    }
}

struct CreditCard: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let issuer: String
    let network: CardNetwork
    let annualFee: Double
    let rewardType: RewardType
    let baseReward: Double           // base reward rate (e.g., 1.0 for 1%)
    let baseIsPercentage: Bool
    let categoryRewards: [CategoryReward]
    let rotatingCategories: [RotatingCategory]?
    let selectableConfig: SelectableConfig?
    let signUpBonus: SignUpBonus?    // Optional sign-up bonus
    let imageColor: String           // hex color for card display (fallback)
    let imageURL: String?            // URL for card image
    let lastUpdated: Date?           // Optional: set by Firestore on upload

    var displayBaseReward: String {
        if baseIsPercentage {
            return "\(Int(baseReward))%"
        } else {
            return "\(Int(baseReward))x"
        }
    }

    // Get effective reward for a category considering rotating and selectable
    func getReward(for category: SpendingCategory, selectedCategories: [SpendingCategory]? = nil) -> (multiplier: Double, isPercentage: Bool) {
        // Check fixed category rewards first
        if let categoryReward = categoryRewards.first(where: { $0.category == category }) {
            return (categoryReward.multiplier, categoryReward.isPercentage)
        }

        // Check rotating categories for current quarter
        if let rotating = rotatingCategories {
            let currentQ = RotatingCategory.currentQuarter()
            let currentY = RotatingCategory.currentYear()

            if let currentRotating = rotating.first(where: { $0.quarter == currentQ && $0.year == currentY }) {
                if currentRotating.categories.contains(category) {
                    return (currentRotating.multiplier, currentRotating.isPercentage)
                }
            }
        }

        // Check selectable categories
        if let config = selectableConfig, let selected = selectedCategories {
            if selected.contains(category) {
                return (config.multiplier, config.isPercentage)
            }
        }

        return (baseReward, baseIsPercentage)
    }
}

// User's card in wallet with personal settings
struct UserCard: Identifiable, Codable, Equatable {
    let id: String
    let cardId: String
    var nickname: String?
    var selectedCategories: [SpendingCategory]?
    var creditLimit: Double?          // User's credit limit for this card
    var currentBalance: Double?       // Optional: track current balance
    var signUpBonusStartDate: Date?   // When user started tracking sign-up bonus
    var signUpBonusAchieved: Bool     // Whether bonus has been achieved
    let addedDate: Date

    init(card: CreditCard, nickname: String? = nil, creditLimit: Double? = nil, trackSignUpBonus: Bool = false) {
        self.id = UUID().uuidString
        self.cardId = card.id
        self.nickname = nickname
        self.selectedCategories = nil
        self.creditLimit = creditLimit
        self.currentBalance = nil
        self.signUpBonusStartDate = trackSignUpBonus ? Date() : nil
        self.signUpBonusAchieved = false
        self.addedDate = Date()
    }

    // Credit utilization percentage
    var utilization: Double? {
        guard let limit = creditLimit, let balance = currentBalance, limit > 0 else {
            return nil
        }
        return (balance / limit) * 100
    }

    var formattedUtilization: String? {
        guard let util = utilization else { return nil }
        return String(format: "%.0f%%", util)
    }

    // Sign-up bonus tracking
    var isTrackingSignUpBonus: Bool {
        signUpBonusStartDate != nil && !signUpBonusAchieved
    }

    func signUpBonusDeadline(for card: CreditCard) -> Date? {
        guard let startDate = signUpBonusStartDate,
              let bonus = card.signUpBonus else { return nil }
        return Calendar.current.date(byAdding: .day, value: bonus.timeframeDays, to: startDate)
    }

    func daysRemainingForBonus(for card: CreditCard) -> Int? {
        guard let deadline = signUpBonusDeadline(for: card) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return max(0, days)
    }
}
