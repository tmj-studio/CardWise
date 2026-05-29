import SwiftUI
import Charts

// MARK: - Chart Data Models

// Themed chart palette (cycles as needed)
private let chartPalette: [Color] = [
    Theme.accent,
    Theme.success,
    Theme.warning,
    Theme.danger,
    Color(rgb: 0xA855F7),
    Color(rgb: 0x0EA5E9)
]

struct CategorySpendingData: Identifiable {
    let id = UUID()
    let category: SpendingCategory
    let amount: Double
    let color: Color

    static let categoryColors: [SpendingCategory: Color] = [
        .dining: Theme.warning,
        .grocery: Theme.success,
        .gas: Theme.warning,
        .travel: Theme.accent,
        .streaming: Color(rgb: 0xA855F7),
        .drugstore: Theme.danger,
        .homeImprovement: Theme.warning,
        .entertainment: Theme.danger,
        .onlineShopping: Color(rgb: 0x0EA5E9),
        .transit: Theme.accent,
        .utilities: Theme.textSecondary,
        .wholesale: Theme.success,
        .paypal: Theme.accent,
        .amazon: Theme.warning,
        .other: Theme.textSecondary
    ]
}

struct MonthlySpendingData: Identifiable {
    let id = UUID()
    let month: Date
    let amount: Double
    let rewards: Double
}

struct CardSpendingData: Identifiable {
    let id = UUID()
    let cardName: String
    let amount: Double
    let color: Color
}

// MARK: - Category Pie Chart

struct CategoryPieChart: View {
    let data: [CategorySpendingData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if data.isEmpty {
                Text("No spending data")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 200)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Amount", item.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                }
                .frame(height: 200)

                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(data.prefix(6)) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.category.displayName)
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text("$\(Int(item.amount))")
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Monthly Trend Chart

struct MonthlyTrendChart: View {
    let data: [MonthlySpendingData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trend")
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if data.isEmpty {
                Text("No spending data")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(height: 200)
            } else {
                let maxSpending = data.map(\.amount).max() ?? 1
                let maxRewards = data.map(\.rewards).max() ?? 1

                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(Theme.accent.gradient)
                    }

                    ForEach(data) { item in
                        LineMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Rewards", maxRewards > 0 ? item.rewards / maxRewards * maxSpending : 0)
                        )
                        .foregroundStyle(Theme.success)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine().foregroundStyle(Theme.separator)
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(Theme.separator)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(Int(amount))")
                                    .font(.app(.caption2))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let scaled = value.as(Double.self), maxSpending > 0 {
                                let reward = scaled / maxSpending * maxRewards
                                Text("$\(String(format: "%.0f", reward))")
                                    .font(.app(.caption2))
                                    .foregroundStyle(Theme.success)
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 12, height: 12)
                        Text("Spending")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(Theme.success)
                            .frame(width: 12, height: 3)
                        Text("Rewards")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Spending Cap Progress Chart

struct SpendingCapChart: View {
    let caps: [SpendingCapProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Caps")
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            if caps.isEmpty {
                Text("No spending caps to track")
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(caps.prefix(5)) { cap in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cap.cardName)
                                .font(.app(.subheadline, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(cap.formattedProgress)
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if cap.isUnlimited {
                            HStack {
                                Text(cap.category)
                                    .font(.app(.caption2))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text("Unlimited")
                                    .font(.app(.caption2, weight: .medium))
                                    .foregroundStyle(Theme.accent)
                            }
                        } else {
                            AppProgressBar(
                                value: min(cap.percentage / 100, 1),
                                color: Theme.capColor(isAtCap: cap.isAtCap, isNearCap: cap.isNearCap)
                            )

                            Text(cap.category)
                                .font(.app(.caption2))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Rewards Efficiency Chart

struct RewardsEfficiencyChart: View {
    let earned: Double
    let missed: Double

    var total: Double { earned + missed }
    var efficiency: Double { total > 0 ? (earned / total) * 100 : 100 }

    var gaugeColor: Color {
        efficiency > 80 ? Theme.success : (efficiency > 50 ? Theme.warning : Theme.danger)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reward Efficiency")
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            HStack(spacing: 20) {
                // Gauge
                Gauge(value: efficiency, in: 0...100) {
                    Text("Efficiency")
                } currentValueLabel: {
                    Text("\(Int(efficiency))%")
                        .font(.app(.title2, weight: .bold))
                }
                .gaugeStyle(.accessoryCircular)
                .tint(gaugeColor)
                .scaleEffect(1.5)
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(Theme.success).frame(width: 8, height: 8)
                        Text("Earned")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", earned))")
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .font(.app(.caption))

                    HStack {
                        Circle().fill(Theme.danger).frame(width: 8, height: 8)
                        Text("Missed")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("$\(String(format: "%.2f", missed))")
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .font(.app(.caption))
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Enhanced Analytics View

struct EnhancedAnalyticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel

    var categoryData: [CategorySpendingData] {
        spendingViewModel.spendingsByCategory.map { category, amount in
            CategorySpendingData(
                category: category,
                amount: amount,
                color: CategorySpendingData.categoryColors[category] ?? .gray
            )
        }
    }

    var monthlyData: [MonthlySpendingData] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: spendingViewModel.spendings) { spending in
            calendar.date(from: calendar.dateComponents([.year, .month], from: spending.date)) ?? Date()
        }

        return grouped.map { month, spendings in
            MonthlySpendingData(
                month: month,
                amount: spendings.reduce(0) { $0 + $1.amount },
                rewards: spendings.reduce(0) { $0 + $1.rewardEarned }
            )
        }
        .sorted { $0.month < $1.month }
        .suffix(6)
        .map { $0 }
    }

    var capProgress: [SpendingCapProgress] {
        SpendingCapTracker.shared.calculateCapProgress(
            userCards: cardViewModel.userCards,
            allCards: cardViewModel.allCards,
            spendings: spendingViewModel.spendings
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Summary cards
                    HStack(spacing: 12) {
                        SummaryCard(
                            title: "Total Spent",
                            value: "$\(Int(spendingViewModel.totalSpending))",
                            color: Theme.accent
                        )
                        SummaryCard(
                            title: "Rewards",
                            value: "$\(String(format: "%.2f", spendingViewModel.totalRewardsEarned))",
                            color: Theme.success
                        )
                    }

                    // Efficiency gauge
                    RewardsEfficiencyChart(
                        earned: spendingViewModel.totalRewardsEarned,
                        missed: spendingViewModel.totalMissedRewards
                    )

                    // Category breakdown
                    CategoryPieChart(data: categoryData)

                    // Monthly trend
                    MonthlyTrendChart(data: monthlyData)

                    // Spending caps
                    if !capProgress.isEmpty {
                        SpendingCapChart(caps: capProgress)
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.app(.caption))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.app(.title2, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sectionCard()
    }
}

#Preview {
    EnhancedAnalyticsView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
