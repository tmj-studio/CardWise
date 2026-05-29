import Foundation
import LinkKit
import FirebaseAuth

class PlaidService: ObservableObject {
    static let shared = PlaidService()

    @Published var isLinking = false
    @Published var linkedAccounts: [PlaidAccount] = []
    @Published var error: String?

    private static let keychainKey = "plaidLinkedAccounts"

    // Firebase Cloud Functions URL — reads from a real GoogleService-Info.plist.
    private let cloudFunctionsBaseURL: String? = {
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: plistPath),
              let projectID = plist["PROJECT_ID"] as? String else {
            return nil
        }

        guard FirebaseService.hasValidConfiguration else {
            return nil
        }

        return "https://us-central1-\(projectID).cloudfunctions.net"
    }()

    private init() {
        loadLinkedAccounts()
    }

    // MARK: - Auth Token

    /// Get Firebase Auth ID token for authenticated backend requests.
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw PlaidError.notLinked
        }
        if user.isAnonymous {
            throw PlaidError.accountUpgradeRequired
        }
        return try await user.getIDToken()
    }

    /// Create an authenticated URLRequest with Bearer token.
    private func authenticatedRequest(url: URL) async throws -> URLRequest {
        let token = try await getAuthToken()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    // MARK: - Link Token

    /// Get a link token from your backend (Firebase Cloud Functions)
    func getLinkToken() async throws -> String {
        guard let cloudFunctionsBaseURL,
              let url = URL(string: "\(cloudFunctionsBaseURL)/createLinkToken") else {
            throw PlaidError.configurationMissing
        }

        var request = try await authenticatedRequest(url: url)

        // Body is now empty — backend uses uid from the verified token
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (data, response) = try await PinnedURLSession.shared.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.linkTokenFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let linkToken = json?["link_token"] as? String else {
            throw PlaidError.invalidResponse
        }

        return linkToken
    }

    // MARK: - Exchange Public Token

    /// Exchange public token for access token (happens on backend)
    func exchangePublicToken(_ publicToken: String, institutionName: String) async throws {
        guard let cloudFunctionsBaseURL,
              let url = URL(string: "\(cloudFunctionsBaseURL)/exchangePublicToken") else {
            throw PlaidError.configurationMissing
        }

        var request = try await authenticatedRequest(url: url)

        let body: [String: Any] = [
            "public_token": publicToken,
            "institution_name": institutionName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await PinnedURLSession.shared.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.exchangeFailed
        }

        // Parse the response to get account info
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let accountsData = json["accounts"] as? [[String: Any]] {

            let accounts = accountsData.compactMap { accountDict -> PlaidAccount? in
                guard let id = accountDict["account_id"] as? String,
                      let name = accountDict["name"] as? String else {
                    return nil
                }
                return PlaidAccount(
                    id: id,
                    name: name,
                    institutionName: institutionName,
                    mask: accountDict["mask"] as? String,
                    type: accountDict["type"] as? String ?? "credit"
                )
            }

            await MainActor.run {
                self.linkedAccounts.append(contentsOf: accounts)
                self.saveLinkedAccounts()
            }
        }
    }

    // MARK: - Fetch Transactions

    /// Fetch transactions from Plaid (through backend)
    func fetchTransactions(accountId: String, startDate: Date, endDate: Date) async throws -> [PlaidTransaction] {
        guard let cloudFunctionsBaseURL,
              let url = URL(string: "\(cloudFunctionsBaseURL)/getTransactions") else {
            throw PlaidError.configurationMissing
        }

        var request = try await authenticatedRequest(url: url)

        let dateFormatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "account_id": accountId,
            "start_date": dateFormatter.string(from: startDate),
            "end_date": dateFormatter.string(from: endDate)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await PinnedURLSession.shared.session.data(for: request)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(TransactionsResponse.self, from: data)
        return response.transactions
    }

    // MARK: - Persistence (Keychain with UserDefaults migration)

    private func loadLinkedAccounts() {
        // Try Keychain first
        if let accounts: [PlaidAccount] = try? KeychainHelper.shared.load(forKey: Self.keychainKey) {
            linkedAccounts = accounts
            return
        }

        // Fallback: migrate from UserDefaults
        if let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.plaidLinkedAccounts),
           let accounts = try? JSONDecoder().decode([PlaidAccount].self, from: data) {
            linkedAccounts = accounts
            // Migrate to Keychain and clean up UserDefaults
            try? KeychainHelper.shared.save(accounts, forKey: Self.keychainKey)
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.plaidLinkedAccounts)
        }
    }

    private func saveLinkedAccounts() {
        try? KeychainHelper.shared.save(linkedAccounts, forKey: Self.keychainKey)
    }

    func unlinkAccount(_ account: PlaidAccount) {
        linkedAccounts.removeAll { $0.id == account.id }
        saveLinkedAccounts()

        // Revoke access token on backend
        Task {
            try? await revokeAccessToken()
        }
    }

    private func revokeAccessToken() async throws {
        guard let cloudFunctionsBaseURL,
              let url = URL(string: "\(cloudFunctionsBaseURL)/unlinkAccount") else {
            throw PlaidError.configurationMissing
        }

        var request = try await authenticatedRequest(url: url)

        // Body is empty — backend uses uid from the verified token
        request.httpBody = try JSONSerialization.data(withJSONObject: [:])

        let (_, response) = try await PinnedURLSession.shared.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.exchangeFailed
        }
    }
}

// MARK: - Models

struct PlaidAccount: Identifiable, Codable {
    let id: String
    let name: String
    let institutionName: String
    let mask: String?
    let type: String

    var displayName: String {
        if let mask = mask {
            return "\(name) ••••\(mask)"
        }
        return name
    }
}

struct PlaidTransaction: Identifiable, Codable {
    let id: String
    let accountId: String
    let amount: Double
    let date: Date
    let name: String
    let merchantName: String?
    let category: [String]?
    let pending: Bool

    enum CodingKeys: String, CodingKey {
        case id = "transaction_id"
        case accountId = "account_id"
        case amount, date, name
        case merchantName = "merchant_name"
        case category, pending
    }
}

struct TransactionsResponse: Codable {
    let transactions: [PlaidTransaction]
}

enum PlaidError: Error, LocalizedError {
    case linkTokenFailed
    case exchangeFailed
    case invalidResponse
    case notLinked
    case accountUpgradeRequired
    case configurationMissing

    var errorDescription: String? {
        switch self {
        case .linkTokenFailed:
            return "Failed to create link token"
        case .exchangeFailed:
            return "Failed to exchange token"
        case .invalidResponse:
            return "Invalid response from server"
        case .notLinked:
            return "No bank account linked"
        case .accountUpgradeRequired:
            return "Please sign in with an account to link your bank"
        case .configurationMissing:
            return "Bank linking is not configured for this build"
        }
    }
}
