import SwiftUI
import Charts

// MARK: - Chart Data Models

struct CategorySpendingData: Identifiable {
    let id = UUID()
    let category: SpendingCategory
    let amount: Double
    let color: Color

    static let categoryColors: [SpendingCategory: Color] = [
        .dining: .orange,
        .grocery: .green,
        .gas: .yellow,
        .travel: .blue,
        .streaming: .purple,
        .drugstore: .pink,
        .homeImprovement: .brown,
        .entertainment: .red,
        .onlineShopping: .cyan,
        .transit: .indigo,
        .utilities: .gray,
        .wholesale: .mint,
        .paypal: .blue,
        .amazon: .orange,
        .other: .secondary
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
                .font(.headline)

            if data.isEmpty {
                Text("No spending data")
                    .foregroundStyle(.secondary)
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
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("$\(Int(item.amount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Monthly Trend Chart

struct MonthlyTrendChart: View {
    let data: [MonthlySpendingData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Trend")
                .font(.headline)

            if data.isEmpty {
                Text("No spending data")
                    .foregroundStyle(.secondary)
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
                        .foregroundStyle(.blue.gradient)
                    }

                    ForEach(data) { item in
                        LineMark(
                            x: .value("Month", item.month, unit: .month),
                            y: .value("Rewards", maxRewards > 0 ? item.rewards / maxRewards * maxSpending : 0)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("$\(Int(amount))")
                                    .font(.caption2)
                            }
                        }
                    }
                    AxisMarks(position: .trailing) { value in
                        AxisValueLabel {
                            if let scaled = value.as(Double.self), maxSpending > 0 {
                                let reward = scaled / maxSpending * maxRewards
                                Text("$\(String(format: "%.0f", reward))")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Legend
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.blue)
                            .frame(width: 12, height: 12)
                        Text("Spending")
                            .font(.caption)
                    }
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(.green)
                            .frame(width: 12, height: 3)
                        Text("Rewards")
                            .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Spending Cap Progress Chart

struct SpendingCapChart: View {
    let caps: [SpendingCapProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending Caps")
                .font(.headline)

            if caps.isEmpty {
                Text("No spending caps to track")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(caps.prefix(5)) { cap in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cap.cardName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(cap.formattedProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if cap.isUnlimited {
                            HStack {
                                Text(cap.category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Unlimited")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                            }
                        } else {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray4))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(cap.isAtCap ? .red : (cap.isNearCap ? .orange : .green))
                                        .frame(width: geo.size.width * min(cap.percentage / 100, 1), height: 8)
                                }
                            }
                            .frame(height: 8)

                            Text(cap.category)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Rewards Efficiency Chart

struct RewardsEfficiencyChart: View {
    let earned: Double
    let missed: Double

    var total: Double { earned + missed }
    var efficiency: Double { total > 0 ? (earned / total) * 100 : 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reward Efficiency")
                .font(.headline)

            HStack(spacing: 20) {
                // Gauge
                Gauge(value: efficiency, in: 0...100) {
                    Text("Efficiency")
                } currentValueLabel: {
                    Text("\(Int(efficiency))%")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(efficiency > 80 ? .green : (efficiency > 50 ? .orange : .red))
                .scaleEffect(1.5)
                .frame(width: 80, height: 80)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("Earned")
                        Spacer()
                        Text("$\(String(format: "%.2f", earned))")
                            .fontWeight(.medium)
                    }
                    .font(.caption)

                    HStack {
                        Circle().fill(.red).frame(width: 8, height: 8)
                        Text("Missed")
                        Spacer()
                        Text("$\(String(format: "%.2f", missed))")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                            color: .blue
                        )
                        SummaryCard(
                            title: "Rewards",
                            value: "$\(String(format: "%.2f", spendingViewModel.totalRewardsEarned))",
                            color: .green
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
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    EnhancedAnalyticsView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
