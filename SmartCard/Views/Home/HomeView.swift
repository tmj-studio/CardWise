import SwiftUI

struct HomeView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @State private var searchText = ""
    @State private var showingQuickRecommend = false

    // Collapse state - auto-collapse when many items
    @AppStorage("dashboard.utilizationExpanded") private var utilizationExpanded = true
    @AppStorage("dashboard.capsExpanded") private var capsExpanded = true
    @AppStorage("dashboard.transactionsExpanded") private var transactionsExpanded = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Search Bar
                    QuickSearchBar(searchText: $searchText, showingSheet: $showingQuickRecommend)

                    // Credit Utilization Overview
                    if hasAnyUtilizationData {
                        CreditUtilizationCard(isExpanded: $utilizationExpanded)
                    }

                    // Spending Caps Progress
                    let caps = SpendingCapTracker.shared.calculateCapProgress(
                        userCards: cardViewModel.userCards,
                        allCards: cardViewModel.allCards,
                        spendings: spendingViewModel.spendings
                    )
                    if !caps.isEmpty {
                        SpendingCapsCard(caps: caps, isExpanded: $capsExpanded)
                    }

                    // Monthly Summary - always visible, compact
                    MonthlySummaryCard()

                    // Recent Transactions
                    if !spendingViewModel.spendings.isEmpty {
                        RecentTransactionsCard(isExpanded: $transactionsExpanded)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                utilizationExpanded = true
                                capsExpanded = true
                                transactionsExpanded = true
                            }
                        } label: {
                            Label("Expand All", systemImage: "arrow.up.left.and.arrow.down.right")
                        }

                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                utilizationExpanded = false
                                capsExpanded = false
                                transactionsExpanded = false
                            }
                        } label: {
                            Label("Collapse All", systemImage: "arrow.down.right.and.arrow.up.left")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingQuickRecommend) {
                QuickRecommendSheet(initialSearch: searchText)
            }
        }
    }

    var hasAnyUtilizationData: Bool {
        cardViewModel.userCards.contains { $0.creditLimit != nil }
    }
}

// MARK: - Quick Search Bar

struct QuickSearchBar: View {
    @Binding var searchText: String
    @Binding var showingSheet: Bool

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text(searchText.isEmpty ? "What are you buying?" : searchText)
                    .foregroundStyle(searchText.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Collapsible Header

struct CollapsibleHeader: View {
    let title: String
    let subtitle: String?
    let subtitleColor: Color
    @Binding var isExpanded: Bool

    init(title: String, subtitle: String? = nil, subtitleColor: Color = .secondary, isExpanded: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self._isExpanded = isExpanded
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(subtitleColor)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Credit Utilization Card

struct CreditUtilizationCard: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @Binding var isExpanded: Bool

    var cardsWithLimits: [(UserCard, CreditCard)] {
        cardViewModel.userCards.compactMap { userCard in
            guard userCard.creditLimit != nil,
                  let card = cardViewModel.getCard(for: userCard) else { return nil }
            return (userCard, card)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CollapsibleHeader(
                title: "Credit Line Usage",
                subtitle: cardViewModel.totalCreditUtilization.map { String(format: "%.0f%% total", $0) },
                subtitleColor: cardViewModel.totalCreditUtilization.map { utilizationColor($0) } ?? .secondary,
                isExpanded: $isExpanded
            )

            if isExpanded {
                ForEach(cardsWithLimits, id: \.0.id) { userCard, card in
                    UtilizationRow(userCard: userCard, card: card)
                }

                if cardsWithLimits.isEmpty {
                    Text("Tap a card to set credit limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func utilizationColor(_ percentage: Double) -> Color {
        if percentage > 50 { return .red }
        if percentage > 30 { return .orange }
        return .green
    }
}

struct UtilizationRow: View {
    let userCard: UserCard
    let card: CreditCard

    var utilization: Double {
        guard let limit = userCard.creditLimit, let balance = userCard.currentBalance, limit > 0 else {
            return 0
        }
        return (balance / limit) * 100
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                CardImageView(
                    imageURL: card.imageURL,
                    fallbackColor: card.imageColor,
                    width: 24,
                    height: 16,
                    cornerRadius: 3
                )

                Text(userCard.nickname ?? card.name)
                    .font(.subheadline)

                Spacer()

                if let balance = userCard.currentBalance, let limit = userCard.creditLimit {
                    Text("$\(Int(balance)) / $\(Int(limit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if userCard.currentBalance != nil {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray4))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(utilizationColor)
                            .frame(width: geo.size.width * min(utilization / 100, 1), height: 6)
                    }
                }
                .frame(height: 6)
            } else {
                Text("No balance set")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var utilizationColor: Color {
        if utilization > 50 { return .red }
        if utilization > 30 { return .orange }
        return .green
    }
}

// MARK: - Spending Caps Card

struct SpendingCapsCard: View {
    let caps: [SpendingCapProgress]
    @Binding var isExpanded: Bool

    var summaryText: String {
        let nearCap = caps.filter { $0.isNearCap || $0.isAtCap }.count
        if nearCap > 0 {
            return "\(nearCap) near limit"
        }
        return "\(caps.count) tracked"
    }

    var summaryColor: Color {
        caps.contains { $0.isAtCap } ? .red : (caps.contains { $0.isNearCap } ? .orange : .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CollapsibleHeader(
                title: "Spending Caps",
                subtitle: summaryText,
                subtitleColor: summaryColor,
                isExpanded: $isExpanded
            )

            if isExpanded {
                ForEach(caps.prefix(5)) { cap in
                    VStack(spacing: 4) {
                        HStack {
                            Text(cap.cardName)
                                .font(.subheadline)
                            Spacer()
                            Text(cap.formattedProgress)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if cap.isUnlimited {
                            // No progress bar for unlimited
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
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.systemGray4))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(cap.isAtCap ? .red : (cap.isNearCap ? .orange : .green))
                                        .frame(width: geo.size.width * min(cap.percentage / 100, 1), height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text(cap.category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(cap.formattedRemaining)
                                    .font(.caption2)
                                    .foregroundStyle(cap.isNearCap ? .orange : .green)
                            }
                        }
                    }
                }

                if caps.count > 5 {
                    Text("+\(caps.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Monthly Summary Card

struct MonthlySummaryCard: View {
    @EnvironmentObject var spendingViewModel: SpendingViewModel

    var thisMonthSpendings: [Spending] {
        spendingViewModel.spendingsThisMonth()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.headline)

            HStack(spacing: 0) {
                SummaryStatItem(
                    title: "Spent",
                    value: formatCurrency(thisMonthSpendings.reduce(0) { $0 + $1.amount }),
                    color: .primary
                )

                Divider().frame(height: 40)

                SummaryStatItem(
                    title: "Rewards",
                    value: formatCurrency(thisMonthSpendings.reduce(0) { $0 + $1.rewardEarned }),
                    color: .green
                )

                Divider().frame(height: 40)

                SummaryStatItem(
                    title: "Missed",
                    value: formatCurrency(thisMonthSpendings.compactMap { $0.missedReward }.reduce(0, +)),
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct SummaryStatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent Transactions Card

struct RecentTransactionsCard: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @Binding var isExpanded: Bool

    var recentSpendings: [Spending] {
        Array(spendingViewModel.spendings.sorted { $0.date > $1.date }.prefix(5))
    }

    var summaryText: String {
        let count = spendingViewModel.spendings.count
        return "\(count) total"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CollapsibleHeader(
                title: "Recent Transactions",
                subtitle: summaryText,
                isExpanded: $isExpanded
            )

            if isExpanded {
                ForEach(recentSpendings) { spending in
                    HStack(spacing: 12) {
                        Image(systemName: spending.category.icon)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(spending.merchant)
                                .font(.subheadline)
                            Text(spending.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(spending.formattedAmount)
                                .font(.subheadline)
                            Text("+\(spending.formattedReward)")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }

                if spendingViewModel.spendings.count > 5 {
                    HStack {
                        Spacer()
                        Text("View all in Spending tab")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Quick Recommend Sheet

struct QuickRecommendSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @EnvironmentObject private var subscription: SubscriptionManager
    @State var initialSearch: String
    @State private var searchText = ""
    @State private var amount: String = "100"
    @State private var showingAddConfirmation = false
    @State private var selectedRecommendation: CardRecommendation?
    @State private var showingHistory = false
    @FocusState private var isSearchFocused: Bool

    var detectedCategory: SpendingCategory? {
        MerchantDatabase.suggestCategory(for: searchText)
    }

    var effectiveCategory: SpendingCategory {
        detectedCategory ?? .other
    }

    var recommendations: [CardRecommendation] {
        let amountValue = Double(amount) ?? 100
        return RecommendationEngine.shared.getRecommendations(
            for: effectiveCategory,
            amount: amountValue,
            userCards: cardViewModel.userCards,
            allCards: cardViewModel.allCards
        )
    }

    var recentSearches: [SearchHistoryManager.SearchItem] {
        SearchHistoryManager.shared.recentSearches(limit: 5)
    }

    var matchingMerchants: [Merchant] {
        MerchantDatabase.searchMerchants(query: searchText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search input
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Store name (e.g., Costco, Starbucks)", text: $searchText)
                                .focused($isSearchFocused)
                                .autocorrectionDisabled()
                                .onChange(of: searchText) { _, newValue in
                                    showingHistory = newValue.isEmpty && isSearchFocused
                                }
                                .onChange(of: isSearchFocused) { _, focused in
                                    showingHistory = focused && searchText.isEmpty
                                }

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    showingHistory = isSearchFocused
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Search history
                        if showingHistory && !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Recent")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                                ForEach(recentSearches) { item in
                                    Button {
                                        searchText = item.query
                                        showingHistory = false
                                        isSearchFocused = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)
                                            Text(item.query)
                                            if let category = item.spendingCategory {
                                                Text("(\(category.displayName))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }

                        // Autocomplete suggestions
                        if !searchText.isEmpty && !matchingMerchants.isEmpty && isSearchFocused {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matchingMerchants.prefix(3)) { merchant in
                                    Button {
                                        searchText = merchant.name
                                        isSearchFocused = false
                                        SearchHistoryManager.shared.addSearch(merchant.name, category: merchant.category)
                                    } label: {
                                        HStack {
                                            Image(systemName: merchant.category.icon)
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)
                                            Text(merchant.name)
                                            Spacer()
                                            Text(merchant.category.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }

                    // Detected category
                    if let category = detectedCategory {
                        HStack {
                            Image(systemName: category.icon)
                            Text("Category: \(category.displayName)")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if !searchText.isEmpty {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Category: Other (type more to detect)")
                            Spacer()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Amount
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                        TextField("100", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .padding()

                Divider()

                // Recommendations
                if cardViewModel.userCards.isEmpty {
                    ContentUnavailableView(
                        "No Cards",
                        systemImage: "creditcard",
                        description: Text("Add cards to your wallet to get recommendations")
                    )
                } else if recommendations.isEmpty {
                    ContentUnavailableView(
                        "No Match",
                        systemImage: "magnifyingglass",
                        description: Text("Try searching for a different merchant")
                    )
                } else {
                    List {
                        ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                            QuickRecommendRow(recommendation: rec, isTop: index == 0) {
                                selectedRecommendation = rec
                                showingAddConfirmation = true
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Which Card?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                searchText = initialSearch
            }
            .alert("Add Spending", isPresented: $showingAddConfirmation) {
                Button("Add") {
                    if let rec = selectedRecommendation, let amountValue = Double(amount) {
                        try? spendingViewModel.addSpending(
                            amount: amountValue,
                            merchant: searchText.isEmpty ? effectiveCategory.displayName : searchText,
                            category: effectiveCategory,
                            cardUsed: rec.card.id,
                            date: Date(),
                            note: nil,
                            cardViewModel: cardViewModel,
                            notifyCapAlerts: NotificationService.shared.shouldSendSpendingCapAlerts(isPro: subscription.isPro)
                        )
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let rec = selectedRecommendation {
                    Text("Add $\(amount) spending at \(searchText.isEmpty ? effectiveCategory.displayName : searchText) using \(rec.userCard.nickname ?? rec.card.name)?")
                }
            }
        }
    }
}

struct QuickRecommendRow: View {
    let recommendation: CardRecommendation
    let isTop: Bool
    let onAddSpending: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    CardImageView(
                        imageURL: recommendation.card.imageURL,
                        fallbackColor: recommendation.card.imageColor,
                        width: 50,
                        height: 32,
                        cornerRadius: 6
                    )
                    if isTop {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.userCard.nickname ?? recommendation.card.name)
                        .font(.subheadline)
                        .fontWeight(isTop ? .bold : .regular)
                    Text(recommendation.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if recommendation.needsActivation {
                        Label("Needs activation", systemImage: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(recommendation.displayReward)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(isTop ? .green : .primary)
                    Text(recommendation.formattedEstimatedReward)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Quick add spending button (only for top recommendation)
            if isTop {
                Button {
                    onAddSpending()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add this spending")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isTop ? Color.green.opacity(0.1) : Color.clear)
    }
}

#Preview {
    HomeView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
