import SwiftUI

struct SpendingListView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showingAddSpending = false
    @State private var showingAnalytics = false
    @State private var showingPaywall = false
    @State private var showingScanReceipt = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary header
                SpendingHeader()

                // Spending list
                if spendingViewModel.spendings.isEmpty {
                    AppEmptyState(
                        icon: "chart.bar",
                        title: "No Spending Records",
                        message: "Track your spending to analyze rewards"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer()
                } else {
                    List {
                        ForEach(spendingViewModel.spendings) { spending in
                            SpendingRow(spending: spending)
                        }
                        .onDelete(perform: deleteSpendings)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .screenBackground()
            .navigationTitle("Spending")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if SubscriptionGate.isUnlocked(.advancedAnalytics, isPro: subscription.isPro) {
                            showingAnalytics = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        Image(systemName: "chart.pie")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingScanReceipt = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                    Button {
                        showingAddSpending = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSpending) {
                AddSpendingView()
            }
            .sheet(isPresented: $showingAnalytics) {
                EnhancedAnalyticsView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingScanReceipt) {
                ScanReceiptView()
            }
        }
    }

    private func deleteSpendings(at offsets: IndexSet) {
        for index in offsets {
            spendingViewModel.deleteSpending(spendingViewModel.spendings[index])
        }
    }
}

struct SpendingHeader: View {
    @EnvironmentObject var spendingViewModel: SpendingViewModel

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading) {
                Text("Total Spent")
                    .font(.app(.caption))
                    .foregroundStyle(Theme.textSecondary)
                Text(formatCurrency(spendingViewModel.totalSpending))
                    .font(.app(.title2, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("Rewards Earned")
                    .font(.app(.caption))
                    .foregroundStyle(Theme.textSecondary)
                Text(formatCurrency(spendingViewModel.totalRewardsEarned))
                    .font(.app(.title2, weight: .bold))
                    .foregroundStyle(Theme.success)
            }
        }
        .padding()
        .background(Theme.surface)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct SpendingRow: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    let spending: Spending

    var card: CreditCard? {
        cardViewModel.getCard(byId: spending.cardUsed)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon in themed circle
            ZStack {
                Circle()
                    .fill(Theme.accentSoft())
                    .frame(width: 36, height: 36)
                Image(systemName: spending.category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(spending.merchant)
                    .font(.app(.subheadline, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                HStack(spacing: 8) {
                    if let card = card {
                        Text(card.name)
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Text(spending.date, style: .date)
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // Missed reward indicator
                if let missed = spending.missedReward, missed > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                        Text("Could have earned \(formatCurrency(missed)) more")
                    }
                    .font(.app(.caption2))
                    .foregroundStyle(Theme.warning)
                }
            }

            Spacer()

            // Amount and reward
            VStack(alignment: .trailing, spacing: 4) {
                Text(spending.formattedAmount)
                    .font(.app(.body))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)

                Text("+\(spending.formattedReward)")
                    .font(.app(.caption))
                    .foregroundStyle(Theme.success)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

struct AddSpendingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @EnvironmentObject private var subscription: SubscriptionManager

    @State private var amount = ""
    @State private var merchant = ""
    @State private var selectedCategory: SpendingCategory = .other
    @State private var selectedCardId: String?
    @State private var date = Date()
    @State private var note = ""
    @State private var showCategoryPicker = false

    var detectedCategory: SpendingCategory? {
        MerchantDatabase.suggestCategory(for: merchant)
    }

    var effectiveCategory: SpendingCategory {
        detectedCategory ?? selectedCategory
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    HStack {
                        Text("$")
                        TextField("Amount", text: $amount)
                            .keyboardType(.decimalPad)
                    }

                    TextField("Merchant", text: $merchant)

                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Label(effectiveCategory.displayName, systemImage: effectiveCategory.icon)
                                .foregroundStyle(.secondary)
                            if detectedCategory != nil {
                                Text("(auto)")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Note (optional)", text: $note)
                }

                Section("Card Used") {
                    if cardViewModel.userCards.isEmpty {
                        Text("Add cards to track spending")
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ForEach(cardViewModel.userCards) { userCard in
                            if let card = cardViewModel.getCard(for: userCard) {
                                HStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: card.imageColor) ?? .gray)
                                        .frame(width: 32, height: 20)

                                    Text(userCard.nickname ?? card.name)

                                    Spacer()

                                    // Show reward rate for this category
                                    if let rec = recommendations.first(where: { $0.userCard.id == userCard.id }) {
                                        Text(rec.displayReward)
                                            .foregroundStyle(Theme.success)
                                    }

                                    if selectedCardId == card.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCardId = card.id
                                }
                            }
                        }
                    }

                    // Recommendation hint
                    if let best = recommendations.first, selectedCardId != best.card.id {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Theme.warning)
                            Text("Best choice: \(best.userCard.nickname ?? best.card.name) (\(best.displayReward))")
                                .font(.app(.caption))
                        }
                    }
                }

                Section {
                    Button("Add Spending") {
                        guard let cardId = selectedCardId,
                              let amountValue = Double(amount) else { return }

                        try? spendingViewModel.addSpending(
                            amount: amountValue,
                            merchant: merchant,
                            category: effectiveCategory,
                            cardUsed: cardId,
                            date: date,
                            note: note.isEmpty ? nil : note,
                            cardViewModel: cardViewModel,
                            notifyCapAlerts: NotificationService.shared.shouldSendSpendingCapAlerts(isPro: subscription.isPro)
                        )
                        dismiss()
                    }
                    .disabled(amount.isEmpty || merchant.isEmpty || selectedCardId == nil)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Spending")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
            .onAppear {
                // Auto-select the best card
                if let best = recommendations.first {
                    selectedCardId = best.card.id
                }
            }
            .onChange(of: merchant) { _, _ in
                // Update card selection when merchant changes
                if let best = recommendations.first {
                    selectedCardId = best.card.id
                }
            }
        }
    }
}

struct AnalyticsRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor)
        }
    }
}

#Preview {
    SpendingListView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
