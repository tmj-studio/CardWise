import WidgetKit
import SwiftUI

// MARK: - Widget Data

struct WidgetData {
    let topCategory: String
    let topCategoryIcon: String
    let bestCard: String
    let bestCardColor: String
    let bestCardImageURL: String?
    let rewardRate: String
    let rotatingCategories: [String]
    let rotatingCard: String?
    let spendingThisMonth: Double
    let rewardsThisMonth: Double

    static let placeholder = WidgetData(
        topCategory: "Dining",
        topCategoryIcon: "fork.knife",
        bestCard: "Amex Gold",
        bestCardColor: "#B8860B",
        bestCardImageURL: nil,
        rewardRate: "4x",
        rotatingCategories: ["Gas", "EV Charging"],
        rotatingCard: "Chase Freedom Flex",
        spendingThisMonth: 1250,
        rewardsThisMonth: 45.50
    )

    static func load() -> WidgetData {
        if let payload = WidgetStorageHelper.loadPayload() {
            return WidgetData(
                topCategory: payload.topCategory,
                topCategoryIcon: payload.topCategoryIcon,
                bestCard: payload.bestCard,
                bestCardColor: payload.bestCardColor,
                bestCardImageURL: nil,
                rewardRate: payload.rewardRate,
                rotatingCategories: payload.rotatingCategories,
                rotatingCard: payload.rotatingCard,
                spendingThisMonth: payload.spendingThisMonth,
                rewardsThisMonth: payload.rewardsThisMonth
            )
        }

        return WidgetData(
            topCategory: "Dining",
            topCategoryIcon: "fork.knife",
            bestCard: "Add Cards",
            bestCardColor: "#808080",
            bestCardImageURL: nil,
            rewardRate: "-",
            rotatingCategories: [],
            rotatingCard: nil,
            spendingThisMonth: 0,
            rewardsThisMonth: 0
        )
    }
}

// MARK: - Widget Storage Helper

private struct WidgetPayload: Codable {
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

private enum WidgetStorageHelper {
    static let appGroupID = "group.com.smartcard.app"
    static let widgetDataKey = "widget_data"

    static func loadPayload() -> WidgetPayload? {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard let data = defaults?.data(forKey: widgetDataKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetPayload.self, from: data)
    }
}

// MARK: - Timeline Provider

struct SmartCardProvider: TimelineProvider {
    func placeholder(in context: Context) -> SmartCardEntry {
        SmartCardEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SmartCardEntry) -> Void) {
        let entry = SmartCardEntry(date: Date(), data: WidgetData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SmartCardEntry>) -> Void) {
        let entry = SmartCardEntry(date: Date(), data: WidgetData.load())
        // Update every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SmartCardEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Small Widget View

struct SmartCardWidgetSmallView: View {
    let entry: SmartCardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category & Best Card
            HStack {
                Image(systemName: entry.data.topCategoryIcon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.data.topCategory)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Card recommendation
            HStack(spacing: 8) {
                WidgetCardImage(
                    imageURL: entry.data.bestCardImageURL,
                    fallbackColor: entry.data.bestCardColor,
                    width: 32,
                    height: 20
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.data.bestCard)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(entry.data.rewardRate)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // Rotating reminder (if applicable)
            if entry.data.rotatingCard != nil, !entry.data.rotatingCategories.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("Q\(currentQuarter())")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    func currentQuarter() -> Int {
        let month = Calendar.current.component(.month, from: Date())
        return ((month - 1) / 3) + 1
    }
}

// MARK: - Medium Widget View

struct SmartCardWidgetMediumView: View {
    let entry: SmartCardEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left side - Best card for category
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.data.topCategoryIcon)
                    Text(entry.data.topCategory)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 8) {
                    WidgetCardImage(
                        imageURL: entry.data.bestCardImageURL,
                        fallbackColor: entry.data.bestCardColor,
                        width: 48,
                        height: 30
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.data.bestCard)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(entry.data.rewardRate)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()
            }

            Divider()

            // Right side - This month stats
            VStack(alignment: .leading, spacing: 8) {
                Text("This Month")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Spent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("$\(Int(entry.data.spendingThisMonth))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Rewards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", entry.data.rewardsThisMonth))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }

                Spacer()

                // Rotating categories
                if !entry.data.rotatingCategories.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Q\(currentQuarter()): \(entry.data.rotatingCategories.prefix(2).joined(separator: ", "))")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    func currentQuarter() -> Int {
        let month = Calendar.current.component(.month, from: Date())
        return ((month - 1) / 3) + 1
    }
}

// MARK: - Lock Screen Widget

struct SmartCardLockScreenView: View {
    let entry: SmartCardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.data.topCategory)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(entry.data.bestCard)
                .font(.caption)
                .fontWeight(.semibold)
            Text(entry.data.rewardRate)
                .font(.caption)
                .foregroundStyle(.green)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Widget Configuration

struct SmartCardWidget: Widget {
    let kind: String = "SmartCardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SmartCardProvider()) { entry in
            SmartCardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SmartCard")
        .description("See which card to use for your purchases")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct SmartCardWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SmartCardEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmartCardWidgetSmallView(entry: entry)
        case .systemMedium:
            SmartCardWidgetMediumView(entry: entry)
        case .accessoryRectangular:
            SmartCardLockScreenView(entry: entry)
        default:
            SmartCardWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Card Image Component

struct WidgetCardImage: View {
    let imageURL: String?
    let fallbackColor: String
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        if let urlString = imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    colorFallback
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                case .failure:
                    colorFallback
                @unknown default:
                    colorFallback
                }
            }
        } else {
            colorFallback
        }
    }

    private var colorFallback: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(hex: fallbackColor) ?? .gray)
            .frame(width: width, height: height)
    }
}

// MARK: - Color Extension for Widget

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget Bundle

@main
struct SmartCardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SmartCardWidget()
    }
}

#Preview(as: .systemSmall) {
    SmartCardWidget()
} timeline: {
    SmartCardEntry(date: Date(), data: .placeholder)
}

#Preview(as: .systemMedium) {
    SmartCardWidget()
} timeline: {
    SmartCardEntry(date: Date(), data: .placeholder)
}
