import SwiftUI

struct RecommendView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @State private var searchText = ""
    @State private var selectedCategory: SpendingCategory = .other
    @State private var amount: String = "100"
    @State private var showCategoryPicker = false
    @State private var showingSuggestions = false
    @State private var showingHistory = false
    @FocusState private var isSearchFocused: Bool
    @FocusState private var isAmountFocused: Bool

    var matchingMerchants: [Merchant] {
        MerchantDatabase.searchMerchants(query: searchText)
    }

    var detectedCategory: SpendingCategory? {
        MerchantDatabase.suggestCategory(for: searchText)
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

    var recentSearches: [SearchHistoryManager.SearchItem] {
        SearchHistoryManager.shared.recentSearches(limit: 5)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input Section
                VStack(spacing: 12) {
                    // Merchant search with autocomplete
                    VStack(alignment: .leading, spacing: 0) {
                        AppSearchField(
                            placeholder: "Search merchant (e.g., Costco, Starbucks)",
                            text: $searchText,
                            focused: $isSearchFocused
                        )
                        .onChange(of: searchText) { _, newValue in
                            showingSuggestions = !newValue.isEmpty && isSearchFocused
                            showingHistory = newValue.isEmpty && isSearchFocused
                        }
                        .onChange(of: isSearchFocused) { _, focused in
                            showingHistory = focused && searchText.isEmpty
                            showingSuggestions = focused && !searchText.isEmpty
                        }
                        .onSubmit {
                            // Save search to history when user submits
                            if !searchText.isEmpty {
                                SearchHistoryManager.shared.addSearch(searchText, category: detectedCategory)
                            }
                        }

                        // Search history (when empty)
                        if showingHistory && !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Recent")
                                        .font(.app(.caption, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                    Spacer()
                                    Button {
                                        SearchHistoryManager.shared.clearHistory()
                                        showingHistory = false
                                    } label: {
                                        Text("Clear")
                                            .font(.app(.caption))
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)

                                ForEach(recentSearches) { item in
                                    Button {
                                        searchText = item.query
                                        showingHistory = false
                                        showingSuggestions = false
                                        isSearchFocused = false
                                    } label: {
                                        HStack {
                                            Image(systemName: "clock.arrow.circlepath")
                                                .foregroundStyle(Theme.textSecondary)
                                                .frame(width: 24)
                                            Text(item.query)
                                                .foregroundStyle(Theme.textPrimary)
                                            if let category = item.spendingCategory {
                                                Text("(\(category.displayName))")
                                                    .font(.app(.caption))
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .font(.app(.body))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .softShadow()
                        }

                        // Autocomplete suggestions
                        if showingSuggestions && !matchingMerchants.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matchingMerchants.prefix(5)) { merchant in
                                    Button {
                                        searchText = merchant.name
                                        showingSuggestions = false
                                        isSearchFocused = false
                                        SearchHistoryManager.shared.addSearch(merchant.name, category: merchant.category)
                                    } label: {
                                        HStack {
                                            Image(systemName: merchant.category.icon)
                                                .foregroundStyle(Theme.textSecondary)
                                                .frame(width: 24)
                                            Text(merchant.name)
                                                .foregroundStyle(Theme.textPrimary)
                                            Spacer()
                                            Text(merchant.category.displayName)
                                                .font(.app(.caption))
                                                .foregroundStyle(Theme.textSecondary)
                                        }
                                        .font(.app(.body))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if merchant.id != matchingMerchants.prefix(5).last?.id {
                                        Divider()
                                            .overlay(Theme.separator)
                                            .padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .softShadow()
                        }
                    }

                    // Detected category or manual selection
                    if let detected = detectedCategory {
                        HStack(spacing: 10) {
                            CategoryChip(icon: detected.icon, title: detected.displayName, selected: true)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                            Spacer()
                        }
                    } else {
                        // Manual category selection
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                CategoryChip(icon: selectedCategory.icon, title: selectedCategory.displayName)
                                Spacer()
                                Text("Tap to change")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                                Image(systemName: "chevron.right")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Amount input
                    HStack {
                        Text("Amount")
                            .font(.app(.body))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("$")
                            .foregroundStyle(Theme.textPrimary)
                        TextField("100", text: $amount)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(8)
                            .background(Theme.surfaceAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .padding()
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isAmountFocused = false
                            isSearchFocused = false
                        }
                    }
                }

                Divider()
                    .overlay(Theme.separator)

                // Recommendations
                if cardViewModel.userCards.isEmpty {
                    AppEmptyState(
                        icon: "creditcard",
                        title: "No Cards",
                        message: "Add cards to your wallet to get recommendations"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recommendations.isEmpty {
                    AppEmptyState(
                        icon: "questionmark.circle",
                        title: "No Recommendations",
                        message: "No cards match this category"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, rec in
                            RecommendationDetailRow(
                                recommendation: rec,
                                rank: index + 1,
                                isTop: index == 0
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .screenBackground()
            .navigationTitle("Recommend")
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
            .onTapGesture {
                // Dismiss keyboard and suggestions when tapping outside
                isSearchFocused = false
                showingSuggestions = false
            }
        }
    }
}

struct RecommendationDetailRow: View {
    let recommendation: CardRecommendation
    let rank: Int
    let isTop: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Rank
            RankBadge(rank: rank)

            // Card info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CardImageView(
                        imageURL: recommendation.card.imageURL,
                        fallbackColor: recommendation.card.imageColor,
                        width: 40,
                        height: 26,
                        cornerRadius: 4
                    )

                    VStack(alignment: .leading) {
                        Text(recommendation.userCard.nickname ?? recommendation.card.name)
                            .font(.app(.headline))
                            .foregroundStyle(Theme.textPrimary)
                        Text(recommendation.card.issuer)
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Text(recommendation.reason)
                    .font(.app(.caption))
                    .foregroundStyle(Theme.textSecondary)

                if recommendation.needsActivation {
                    Label("Needs activation", systemImage: "exclamationmark.triangle.fill")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.warning)
                }
            }

            Spacer()

            // Reward info
            VStack(alignment: .trailing, spacing: 4) {
                RewardBadge(text: recommendation.displayReward, emphasized: isTop)

                Text(recommendation.formattedEstimatedReward)
                    .font(.app(.subheadline))
                    .foregroundStyle(Theme.textSecondary)

                Text("estimated")
                    .font(.app(.caption2))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(isTop ? Theme.accentSoft() : Color.clear)
        .listRowSeparatorTint(Theme.separator)
    }
}

struct CategoryPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedCategory: SpendingCategory

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(SpendingCategory.allCases) { category in
                        Button {
                            selectedCategory = category
                            dismiss()
                        } label: {
                            CategoryChip(
                                icon: category.icon,
                                title: category.displayName,
                                selected: selectedCategory == category
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    RecommendView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
