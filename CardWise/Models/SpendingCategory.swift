import Foundation

enum SpendingCategory: String, CaseIterable, Codable, Identifiable {
    case dining
    case grocery
    case gas
    case travel
    case streaming
    case drugstore
    case homeImprovement
    case entertainment
    case onlineShopping
    case transit
    case utilities
    case wholesale
    case paypal
    case amazon
    case fitness
    case phone
    case internet
    case shipping
    case advertising
    case officeSupplies
    case evCharging
    case apple
    case wholeFoods
    case target
    case walmart
    case macys
    case kohls
    case gap
    case nordstrom
    case electronics
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dining: return "Dining"
        case .grocery: return "Grocery"
        case .gas: return "Gas"
        case .travel: return "Travel"
        case .streaming: return "Streaming"
        case .drugstore: return "Drugstore"
        case .homeImprovement: return "Home Improvement"
        case .entertainment: return "Entertainment"
        case .onlineShopping: return "Online Shopping"
        case .transit: return "Transit"
        case .utilities: return "Utilities"
        case .wholesale: return "Wholesale Clubs"
        case .paypal: return "PayPal"
        case .amazon: return "Amazon"
        case .fitness: return "Fitness"
        case .phone: return "Phone/Internet"
        case .internet: return "Internet/Cable"
        case .shipping: return "Shipping"
        case .advertising: return "Advertising"
        case .officeSupplies: return "Office Supplies"
        case .evCharging: return "EV Charging"
        case .apple: return "Apple"
        case .wholeFoods: return "Whole Foods"
        case .target: return "Target"
        case .walmart: return "Walmart"
        case .macys: return "Macys"
        case .kohls: return "Kohls"
        case .gap: return "Gap"
        case .nordstrom: return "Nordstrom"
        case .electronics: return "Electronics"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .dining: return "fork.knife"
        case .grocery: return "cart.fill"
        case .gas: return "fuelpump.fill"
        case .travel: return "airplane"
        case .streaming: return "play.tv.fill"
        case .drugstore: return "pills.fill"
        case .homeImprovement: return "hammer.fill"
        case .entertainment: return "film.fill"
        case .onlineShopping: return "bag.fill"
        case .transit: return "bus.fill"
        case .utilities: return "bolt.fill"
        case .wholesale: return "building.2.fill"
        case .paypal: return "creditcard.fill"
        case .amazon: return "shippingbox.fill"
        case .fitness: return "figure.run"
        case .phone: return "iphone"
        case .internet: return "wifi"
        case .shipping: return "shippingbox"
        case .advertising: return "megaphone.fill"
        case .officeSupplies: return "pencil.and.ruler.fill"
        case .evCharging: return "bolt.car.fill"
        case .apple: return "apple.logo"
        case .wholeFoods: return "leaf.fill"
        case .target: return "target"
        case .walmart: return "cart.fill"
        case .macys: return "building.2.fill"
        case .kohls: return "building.2.fill"
        case .gap: return "tshirt.fill"
        case .nordstrom: return "bag.fill"
        case .electronics: return "desktopcomputer"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum CapPeriod: String, Codable {
    case monthly
    case quarterly
    case yearly

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .yearly: return "Yearly"
        }
    }

    /// Returns the start date of the current period
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .monthly:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        case .quarterly:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            return calendar.date(from: components) ?? now
        case .yearly:
            return calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
        }
    }
}
