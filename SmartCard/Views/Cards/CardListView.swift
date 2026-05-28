import SwiftUI

struct CardListView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject private var subscription: SubscriptionManager
    @State private var showingAddCard = false
    @State private var showingPaywall = false
    @State private var selectedCard: UserCard?

    var body: some View {
        NavigationStack {
            List {
                ForEach(cardViewModel.userCards) { userCard in
                    if let card = cardViewModel.getCard(for: userCard) {
                        CardRow(userCard: userCard, card: card)
                            .onTapGesture {
                                selectedCard = userCard
                            }
                    }
                }
                .onDelete(perform: deleteCards)
            }
            .navigationTitle("My Cards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        attemptAddCard()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCardView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(item: $selectedCard) { userCard in
                if let card = cardViewModel.getCard(for: userCard) {
                    CardDetailView(userCard: userCard, card: card)
                }
            }
            .overlay {
                if cardViewModel.userCards.isEmpty {
                    ContentUnavailableView {
                        Label("No Cards", systemImage: "creditcard")
                    } description: {
                        Text("Add your credit cards to get started")
                    } actions: {
                        Button("Add Card") {
                            attemptAddCard()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func attemptAddCard() {
        if SubscriptionGate.canAddCard(currentCount: cardViewModel.userCards.count, isPro: subscription.isPro) {
            showingAddCard = true
        } else {
            showingPaywall = true
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            cardViewModel.removeCard(cardViewModel.userCards[index])
        }
    }
}

struct CardRow: View {
    let userCard: UserCard
    let card: CreditCard

    var body: some View {
        HStack(spacing: 16) {
            // Card visual
            CardImageView(
                imageURL: card.imageURL,
                fallbackColor: card.imageColor,
                width: 60,
                height: 40,
                cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(userCard.nickname ?? card.name)
                    .font(.headline)
                Text(card.issuer)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Show key benefits
                HStack(spacing: 8) {
                    if !card.categoryRewards.isEmpty {
                        let topReward = card.categoryRewards.max(by: { $0.multiplier < $1.multiplier })
                        if let reward = topReward {
                            Text("\(reward.displayMultiplier) \(reward.category.displayName)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    if card.rotatingCategories != nil {
                        Text("Rotating")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    if card.selectableConfig != nil {
                        Text("Selectable")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AddCardView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    @State private var searchText = ""
    @State private var nickname = ""
    @State private var creditLimitText = ""
    @State private var selectedCard: CreditCard?

    var filteredCards: [CreditCard] {
        let available = cardViewModel.availableCardsToAdd
        if searchText.isEmpty {
            return available
        }

        // Common issuer abbreviations
        let issuerAliases: [String: [String]] = [
            "American Express": ["amex", "ae"],
            "Bank of America": ["bofa", "boa"],
            "Capital One": ["cap1", "c1"],
            "Wells Fargo": ["wf"],
            "US Bank": ["usb"]
        ]

        // Common card name abbreviations
        let cardAliases: [String: [String]] = [
            // Chase
            "Chase Freedom Flex": ["cff", "freedom flex"],
            "Chase Freedom Unlimited": ["cfu", "freedom unlimited"],
            "Chase Freedom Rise": ["cfr", "freedom rise"],
            "Chase Sapphire Preferred": ["csp", "sapphire preferred"],
            "Chase Sapphire Reserve": ["csr", "sapphire reserve"],
            "Ink Business Preferred": ["cip", "ink preferred"],
            "Ink Business Unlimited": ["ciu", "ink unlimited"],
            "Ink Business Cash": ["cic", "ink cash"],
            // Amex
            "American Express Gold Card": ["amex gold", "gold card"],
            "American Express Platinum Card": ["amex platinum", "amex plat", "platinum card"],
            "Blue Cash Preferred": ["bcp"],
            "Blue Cash Everyday": ["bce"],
            "American Express Green Card": ["amex green", "green card"],
            // Citi
            "Citi Double Cash": ["cdc", "double cash"],
            "Citi Custom Cash": ["ccc", "custom cash"],
            "Citi Premier": ["citi premier"],
            // Capital One
            "Capital One Venture X": ["venture x", "vx"],
            "Capital One Venture": ["venture"],
            "Capital One Savor": ["savor"],
            "Capital One SavorOne": ["savorone"],
            // Discover
            "Discover it Cash Back": ["discover it", "dit"],
            // Wells Fargo
            "Wells Fargo Active Cash": ["wf active cash", "active cash"],
            "Wells Fargo Autograph": ["wf autograph", "autograph"],
            // US Bank
            "US Bank Altitude Go": ["altitude go"],
            "US Bank Altitude Reserve": ["altitude reserve", "uar"],
            "US Bank Cash+": ["cash plus", "cash+"]
        ]

        return available.filter { card in
            let searchLower = searchText.lowercased().trimmingCharacters(in: .whitespaces)

            // Check name and issuer
            if card.name.localizedCaseInsensitiveContains(searchText) ||
               card.issuer.localizedCaseInsensitiveContains(searchText) {
                return true
            }

            // Check issuer aliases
            if let aliases = issuerAliases[card.issuer] {
                for alias in aliases where searchLower.contains(alias) {
                    return true
                }
            }

            // Check card name aliases
            if let aliases = cardAliases[card.name] {
                for alias in aliases where searchLower == alias || searchLower.contains(alias) {
                    return true
                }
            }

            return false
        }
    }

    var creditLimit: Double? {
        Double(creditLimitText)
    }

    var body: some View {
        NavigationStack {
            VStack {
                if selectedCard == nil {
                    // Card selection
                    List(filteredCards) { card in
                        Button {
                            selectedCard = card
                        } label: {
                            CardSelectionRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                    .searchable(text: $searchText, prompt: "Search cards")
                } else if let card = selectedCard {
                    // Card settings input
                    Form {
                        Section {
                            CardSelectionRow(card: card)
                        }

                        Section("Nickname (Optional)") {
                            TextField("e.g., Travel Card", text: $nickname)
                        }

                        Section {
                            HStack {
                                Text("$")
                                TextField("Credit Limit", text: $creditLimitText)
                                    .keyboardType(.numberPad)
                            }
                        } header: {
                            Text("Credit Limit (Optional)")
                        } footer: {
                            Text("Enter your credit limit to track utilization on the dashboard")
                        }

                        Section {
                            Button("Add Card") {
                                cardViewModel.addCard(
                                    card,
                                    nickname: nickname.isEmpty ? nil : nickname,
                                    creditLimit: creditLimit
                                )
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(selectedCard == nil ? "Add Card" : "Card Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if selectedCard != nil {
                        Button("Back") {
                            selectedCard = nil
                            nickname = ""
                            creditLimitText = ""
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CardSelectionRow: View {
    let card: CreditCard

    var body: some View {
        HStack(spacing: 12) {
            CardImageView(
                imageURL: card.imageURL,
                fallbackColor: card.imageColor,
                width: 50,
                height: 32,
                cornerRadius: 6
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(card.issuer) | \(card.annualFee == 0 ? "No AF" : "$\(Int(card.annualFee)) AF")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(card.displayBaseReward)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CardDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cardViewModel: CardViewModel
    let userCard: UserCard
    let card: CreditCard
    @State private var nickname: String = ""
    @State private var creditLimitText: String = ""
    @State private var currentBalanceText: String = ""
    @State private var selectedCategories: Set<SpendingCategory> = []

    var body: some View {
        NavigationStack {
            Form {
                // Card Info
                Section {
                    HStack {
                        CardImageView(
                            imageURL: card.imageURL,
                            fallbackColor: card.imageColor,
                            width: 100,
                            height: 64,
                            cornerRadius: 12
                        )

                        VStack(alignment: .leading) {
                            Text(card.name)
                                .font(.headline)
                            Text("$\(Int(card.annualFee)) annual fee")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Nickname
                Section("Nickname") {
                    TextField("Nickname", text: $nickname)
                }

                // Credit Limit & Balance
                Section {
                    HStack {
                        Text("Credit Limit")
                        Spacer()
                        Text("$")
                        TextField("0", text: $creditLimitText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    HStack {
                        Text("Current Balance")
                        Spacer()
                        Text("$")
                        TextField("0", text: $currentBalanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }

                    if let limit = Double(creditLimitText), let balance = Double(currentBalanceText), limit > 0 {
                        let utilization = (balance / limit) * 100
                        HStack {
                            Text("Utilization")
                            Spacer()
                            Text(String(format: "%.0f%%", utilization))
                                .foregroundStyle(utilization > 30 ? (utilization > 50 ? .red : .orange) : .green)
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Credit Utilization")
                } footer: {
                    Text("Keep utilization under 30% for best credit score impact")
                }

                // Rewards
                Section("Reward Structure") {
                    HStack {
                        Text("Base Reward")
                        Spacer()
                        Text(card.displayBaseReward)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(card.categoryRewards) { reward in
                        HStack {
                            Label(reward.category.displayName, systemImage: reward.category.icon)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(reward.displayMultiplier)
                                    .foregroundStyle(.green)
                                if let cap = reward.cap {
                                    Text("Cap: $\(Int(cap))/\(reward.capPeriod?.displayName ?? "")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Rotating Categories
                if let rotating = card.rotatingCategories {
                    Section("Rotating Categories") {
                        ForEach(rotating) { rot in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Q\(rot.quarter) \(rot.year)")
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(rot.displayMultiplier)
                                        .foregroundStyle(.green)
                                }
                                Text(rot.categories.map { $0.displayName }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Selectable Categories
                if let config = card.selectableConfig {
                    Section("Select Your Category (\(config.maxSelections) max)") {
                        ForEach(config.availableCategories, id: \.self) { category in
                            HStack {
                                Label(category.displayName, systemImage: category.icon)

                                Spacer()

                                if selectedCategories.contains(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedCategories.contains(category) {
                                    selectedCategories.remove(category)
                                } else if selectedCategories.count < config.maxSelections {
                                    selectedCategories.insert(category)
                                }
                            }
                        }

                        HStack {
                            Text("Selected category reward")
                            Spacer()
                            Text("\(Int(config.multiplier))\(config.isPercentage ? "%" : "x")")
                                .foregroundStyle(.green)
                        }

                        if let cap = config.cap {
                            HStack {
                                Text("Spending cap")
                                Spacer()
                                Text("$\(Int(cap))/\(config.capPeriod?.displayName ?? "")")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        cardViewModel.removeCard(userCard)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Remove Card")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if nickname != (userCard.nickname ?? "") {
                            cardViewModel.updateNickname(for: userCard, nickname: nickname.isEmpty ? nil : nickname)
                        }
                        if !selectedCategories.isEmpty {
                            cardViewModel.updateSelectedCategories(for: userCard, categories: Array(selectedCategories))
                        }
                        // Save credit limit and balance
                        let newLimit = Double(creditLimitText)
                        let newBalance = Double(currentBalanceText)
                        cardViewModel.updateCreditLimit(for: userCard, limit: newLimit)
                        cardViewModel.updateBalance(for: userCard, balance: newBalance)
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = userCard.nickname ?? ""
                if let limit = userCard.creditLimit {
                    creditLimitText = String(Int(limit))
                }
                if let balance = userCard.currentBalance {
                    currentBalanceText = String(format: "%.2f", balance)
                }
                if let selected = userCard.selectedCategories {
                    selectedCategories = Set(selected)
                }
            }
        }
    }
}

#Preview {
    CardListView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
