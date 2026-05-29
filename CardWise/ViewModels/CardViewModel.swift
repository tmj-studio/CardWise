import Foundation
import SwiftUI
import os

@MainActor
class CardViewModel: ObservableObject {
    private static let logger = Logger(subsystem: "com.smartcard.app", category: "CardViewModel")
    @Published var allCards: [CreditCard] = []
    @Published var userCards: [UserCard] = []
    @Published var isLoading = false

    init() {
        loadUserCards()
        Task {
            await loadCardsFromFirebase()
        }
    }

    // MARK: - Firebase

    func loadCardsFromFirebase() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let cards = try await FirebaseService.shared.fetchAllCards()
            if cards.isEmpty {
                // Fallback to MockData if Firebase is empty
                allCards = MockData.creditCards
                #if DEBUG
                Self.logger.info("Firebase empty, using MockData (\(self.allCards.count) cards)")
                #endif
            } else {
                allCards = cards
                #if DEBUG
                Self.logger.info("Loaded \(cards.count) cards from Firebase")
                #endif
            }
        } catch {
            // Fallback to MockData on error
            allCards = MockData.creditCards
            #if DEBUG
            Self.logger.error("Firebase error: \(error.localizedDescription), using MockData")
            #endif
        }
    }

    // MARK: - Persistence (Keychain with UserDefaults migration)

    private static let keychainKey = "userCards"

    private func loadUserCards() {
        // Try Keychain first
        if let cards: [UserCard] = try? KeychainHelper.shared.load(forKey: Self.keychainKey) {
            userCards = cards
            return
        }

        // Fallback: migrate from UserDefaults
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.userCards),
           let cards = try? JSONDecoder().decode([UserCard].self, from: data) {
            userCards = cards
            try? KeychainHelper.shared.save(cards, forKey: Self.keychainKey)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.userCards)
        } else {
            userCards = []
        }
    }

    private func saveUserCards() {
        try? KeychainHelper.shared.save(userCards, forKey: Self.keychainKey)
    }

    func clearAllData() {
        userCards = []
        KeychainHelper.shared.delete(forKey: Self.keychainKey)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.userCards)
    }

    // MARK: - Card Management

    func addCard(_ card: CreditCard, nickname: String? = nil, creditLimit: Double? = nil) {
        // Check if card already exists
        guard !userCards.contains(where: { $0.cardId == card.id }) else { return }

        let newUserCard = UserCard(card: card, nickname: nickname, creditLimit: creditLimit)
        userCards.append(newUserCard)
        saveUserCards()
    }

    func removeCard(_ userCard: UserCard) {
        userCards.removeAll { $0.id == userCard.id }
        saveUserCards()
    }

    func updateNickname(for userCard: UserCard, nickname: String?) {
        if let index = userCards.firstIndex(where: { $0.id == userCard.id }) {
            userCards[index].nickname = nickname
            saveUserCards()
        }
    }

    func updateSelectedCategories(for userCard: UserCard, categories: [SpendingCategory]) {
        if let index = userCards.firstIndex(where: { $0.id == userCard.id }) {
            userCards[index].selectedCategories = categories
            saveUserCards()
        }
    }

    func updateCreditLimit(for userCard: UserCard, limit: Double?) {
        if let index = userCards.firstIndex(where: { $0.id == userCard.id }) {
            userCards[index].creditLimit = limit
            saveUserCards()
        }
    }

    func updateBalance(for userCard: UserCard, balance: Double?) {
        if let index = userCards.firstIndex(where: { $0.id == userCard.id }) {
            userCards[index].currentBalance = balance
            saveUserCards()
        }
    }

    // Calculate total credit utilization across all cards
    var totalCreditUtilization: Double? {
        let cardsWithLimits = userCards.filter { $0.creditLimit != nil && $0.currentBalance != nil }
        guard !cardsWithLimits.isEmpty else { return nil }

        let totalLimit = cardsWithLimits.compactMap { $0.creditLimit }.reduce(0, +)
        let totalBalance = cardsWithLimits.compactMap { $0.currentBalance }.reduce(0, +)

        guard totalLimit > 0 else { return nil }
        return (totalBalance / totalLimit) * 100
    }

    // MARK: - Helpers

    func getCard(for userCard: UserCard) -> CreditCard? {
        allCards.first { $0.id == userCard.cardId }
    }

    func getCard(byId id: String) -> CreditCard? {
        allCards.first { $0.id == id }
    }

    func getUserCard(byCardId cardId: String) -> UserCard? {
        userCards.first { $0.cardId == cardId }
    }

    var availableCardsToAdd: [CreditCard] {
        allCards.filter { card in
            !userCards.contains { $0.cardId == card.id }
        }
    }
}
