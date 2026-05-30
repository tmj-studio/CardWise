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

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Greeting header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.app(.largeTitle, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Let's find your best card")
                            .font(.app(.subheadline))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Quick Search Bar
                    SearchBarButton(
                        placeholder: "What are you buying?",
                        text: searchText
                    ) {
                        showingQuickRecommend = true
                    }

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
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("").font(.app(.headline, weight: .semibold))
                }
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

// MARK: - Collapsible Header

struct CollapsibleHeader: View {
    let title: String
    let subtitle: String?
    let subtitleColor: Color
    @Binding var isExpanded: Bool

    init(title: String, subtitle: String? = nil, subtitleColor: Color = Theme.textSecondary, isExpanded: Binding<Bool>) {
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
                    .font(.app(.headline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.app(.caption))
                        .foregroundStyle(subtitleColor)
                }

                Image(systemName: "chevron.right")
                    .font(.app(.caption))
                    .foregroundStyle(Theme.textSecondary)
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
                subtitleColor: cardViewModel.totalCreditUtilization.map { Theme.utilizationColor($0) } ?? Theme.textSecondary,
                isExpanded: $isExpanded
            )

            if isExpanded {
                ForEach(cardsWithLimits, id: \.0.id) { userCard, card in
                    UtilizationRow(userCard: userCard, card: card)
                }

                if cardsWithLimits.isEmpty {
                    Text("Tap a card to set credit limit")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sectionCard()
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
                    .font(.app(.subheadline))

                Spacer()

                if let balance = userCard.currentBalance, let limit = userCard.creditLimit {
                    Text("$\(Int(balance)) / $\(Int(limit))")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            if userCard.currentBalance != nil {
                AppProgressBar(
                    value: utilization / 100,
                    color: Theme.utilizationColor(utilization)
                )
            } else {
                Text("No balance set")
                    .font(.app(.caption2))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
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
        caps.contains { $0.isAtCap } ? Theme.danger : (caps.contains { $0.isNearCap } ? Theme.warning : Theme.success)
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
                                .font(.app(.subheadline))
                            Spacer()
                            Text(cap.formattedProgress)
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if cap.isUnlimited {
                            // No progress bar for unlimited
                            HStack {
                                Text(cap.category)
                                    .font(.app(.caption2))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text("Unlimited")
                                    .font(.app(.caption2))
                                    .fontWeight(.medium)
                                    .foregroundStyle(Theme.accent)
                            }
                        } else {
                            AppProgressBar(
                                value: cap.percentage / 100,
                                color: Theme.capColor(isAtCap: cap.isAtCap, isNearCap: cap.isNearCap)
                            )

                            HStack {
                                Text(cap.category)
                                    .font(.app(.caption2))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(cap.formattedRemaining)
                                    .font(.app(.caption2))
                                    .foregroundStyle(cap.isNearCap ? Theme.warning : Theme.success)
                            }
                        }
                    }
                }

                if caps.count > 5 {
                    Text("+\(caps.count - 5) more")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Monthly Summary Card

struct MonthlySummaryCard: View {
    @EnvironmentObject var spendingViewModel: SpendingViewModel

    var thisMonthSpendings: [Spending] {
        spendingViewModel.spendingsThisMonth()
    }

    var body: some View {
        HeroStatCard(
            title: "This Month",
            columns: [
                (
                    title: "Spent",
                    value: formatCurrency(thisMonthSpendings.reduce(0) { $0 + $1.amount }),
                    tint: .white
                ),
                (
                    title: "Rewards",
                    value: formatCurrency(thisMonthSpendings.reduce(0) { $0 + $1.rewardEarned }),
                    tint: Color(rgb: 0xBBF7D0)
                ),
                (
                    title: "Missed",
                    value: formatCurrency(thisMonthSpendings.compactMap { $0.missedReward }.reduce(0, +)),
                    tint: Color(rgb: 0xFECDD3)
                )
            ]
        )
    }

    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
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
                            .font(.app(.title3))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(spending.merchant)
                                .font(.app(.subheadline))
                            Text(spending.date, style: .date)
                                .font(.app(.caption2))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(spending.formattedAmount)
                                .font(.app(.subheadline))
                            Text("+\(spending.formattedReward)")
                                .font(.app(.caption2))
                                .foregroundStyle(Theme.success)
                        }
                    }
                }

                if spendingViewModel.spendings.count > 5 {
                    HStack {
                        Spacer()
                        Text("View all in Spending tab")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                    }
                }
            }
        }
        .sectionCard()
    }
}

// MARK: - Quick Recommend Sheet

struct QuickRecommendSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
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
                        AppSearchField(
                            placeholder: "Store name (e.g., Costco, Starbucks)",
                            text: $searchText,
                            focused: $isSearchFocused
                        )
                        .onChange(of: searchText) { _, newValue in
                            showingHistory = newValue.isEmpty && isSearchFocused
                        }
                        .onChange(of: isSearchFocused) { _, focused in
                            showingHistory = focused && searchText.isEmpty
                        }

                        // Search history
                        if showingHistory && !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Recent")
                                        .font(.app(.caption, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
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
                                                .foregroundStyle(Theme.textSecondary)
                                                .frame(width: 24)
                                            Text(item.query)
                                                .font(.app(.body))
                                                .foregroundStyle(Theme.textPrimary)
                                            if let category = item.spendingCategory {
                                                Text("(\(category.displayName))")
                                                    .font(.app(.caption))
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                        .background(Theme.separator)
                                }
                            }
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .softShadow()
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
                                                .foregroundStyle(Theme.textSecondary)
                                                .frame(width: 24)
                                            Text(merchant.name)
                                                .font(.app(.body))
                                                .foregroundStyle(Theme.textPrimary)
                                            Spacer()
                                            Text(merchant.category.displayName)
                                                .font(.app(.caption))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)

                                    Divider()
                                        .background(Theme.separator)
                                }
                            }
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .softShadow()
                        }
                    }

                    // Detected category
                    if let category = detectedCategory {
                        HStack(spacing: 8) {
                            CategoryChip(icon: category.icon, title: category.displayName, selected: true)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        }
                    } else if !searchText.isEmpty {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Category: Other (type more to detect)")
                            Spacer()
                        }
                        .font(.app(.subheadline))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    // Amount
                    HStack {
                        Text("Amount")
                            .font(.app(.body))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("$")
                            .foregroundStyle(Theme.textSecondary)
                        TextField("100", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .font(.app(.body))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .padding()

                Divider()
                    .background(Theme.separator)

                // Recommendations
                if cardViewModel.userCards.isEmpty {
                    AppEmptyState(
                        icon: "creditcard",
                        title: "No Cards",
                        message: "Add cards to your wallet to get recommendations"
                    )
                } else if recommendations.isEmpty {
                    AppEmptyState(
                        icon: "magnifyingglass",
                        title: "No Match",
                        message: "Try searching for a different merchant"
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
                            notifyCapAlerts: NotificationService.shared.shouldSendSpendingCapAlerts()
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
                        .font(.app(.subheadline, weight: isTop ? .bold : .regular))
                    Text(recommendation.reason)
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)

                    if recommendation.needsActivation {
                        Label("Needs activation", systemImage: "exclamationmark.triangle")
                            .font(.app(.caption2))
                            .foregroundStyle(Theme.warning)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    RewardBadge(text: recommendation.displayReward, emphasized: isTop)
                    Text(recommendation.formattedEstimatedReward)
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
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
                }
                .buttonStyle(SoftButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(isTop ? Theme.accentSoft() : Color.clear)
    }
}

#Preview {
    HomeView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
