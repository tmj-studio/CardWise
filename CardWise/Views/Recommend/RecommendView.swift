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
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search merchant (e.g., Costco, Starbucks)", text: $searchText)
                                .focused($isSearchFocused)
                                .autocorrectionDisabled()
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

                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    showingSuggestions = false
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

                        // Search history (when empty)
                        if showingHistory && !recentSearches.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack {
                                    Text("Recent")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button {
                                        SearchHistoryManager.shared.clearHistory()
                                        showingHistory = false
                                    } label: {
                                        Text("Clear")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
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
                                                .foregroundStyle(.secondary)
                                                .frame(width: 24)
                                            Text(merchant.name)
                                            Spacer()
                                            Text(merchant.category.displayName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)

                                    if merchant.id != matchingMerchants.prefix(5).last?.id {
                                        Divider().padding(.leading, 48)
                                    }
                                }
                            }
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }

                    // Detected category or manual selection
                    if let detected = detectedCategory {
                        HStack {
                            Image(systemName: detected.icon)
                                .foregroundStyle(.green)
                            Text("Category: \(detected.displayName)")
                                .font(.subheadline)
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        // Manual category selection
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack {
                                Image(systemName: selectedCategory.icon)
                                Text(selectedCategory.displayName)
                                Spacer()
                                Text("Tap to change")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Amount input
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                        TextField("100", text: $amount)
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
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

                // Recommendations
                if cardViewModel.userCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Cards", systemImage: "creditcard")
                    } description: {
                        Text("Add cards to your wallet to get recommendations")
                    }
                } else if recommendations.isEmpty {
                    ContentUnavailableView {
                        Label("No Recommendations", systemImage: "questionmark.circle")
                    } description: {
                        Text("No cards match this category")
                    }
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
            ZStack {
                Circle()
                    .fill(isTop ? Color.green : Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(isTop ? .white : .primary)
            }

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
                            .font(.headline)
                        Text(recommendation.card.issuer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if recommendation.needsActivation {
                    Label("Needs activation", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Reward info
            VStack(alignment: .trailing, spacing: 4) {
                Text(recommendation.displayReward)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(isTop ? .green : .primary)

                Text(recommendation.formattedEstimatedReward)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("estimated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(isTop ? Color.green.opacity(0.1) : Color.clear)
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
                            VStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .font(.title2)
                                Text(category.displayName)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                selectedCategory == category ?
                                Color.blue.opacity(0.2) : Color(.systemGray6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCategory == category ? Color.blue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
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
