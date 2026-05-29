import SwiftUI
import LinkKit

struct LinkBankView: View {
    @SwiftUI.Environment(\.dismiss) var dismiss: DismissAction
    @StateObject private var plaidService = PlaidService.shared
    @State private var isLinkPresented = false
    @State private var linkToken: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                // Linked Accounts Section
                if !plaidService.linkedAccounts.isEmpty {
                    Section("Linked Accounts") {
                        ForEach(plaidService.linkedAccounts) { account in
                            HStack {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(.blue)

                                VStack(alignment: .leading) {
                                    Text(account.displayName)
                                        .font(.subheadline)
                                    Text(account.institutionName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    plaidService.unlinkAccount(account)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }

                // Add Account Section
                Section {
                    Button {
                        Task {
                            await startLinking()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Link Bank Account")

                            Spacer()

                            if isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isLoading)
                } footer: {
                    Text("Connect your credit card accounts to automatically import transactions.")
                }

                // Error Message
                if let error = errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Info Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Secure Connection", systemImage: "lock.shield")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("SmartCard uses Plaid to securely connect to your bank. Your login credentials are never stored on our servers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Link Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $isLinkPresented) {
                if let token = linkToken {
                    PlaidLinkController(
                        linkToken: token,
                        onSuccess: { publicToken, institutionName in
                            Task {
                                do {
                                    try await plaidService.exchangePublicToken(publicToken, institutionName: institutionName)
                                } catch {
                                    await MainActor.run {
                                        errorMessage = error.localizedDescription
                                    }
                                }
                            }
                            isLinkPresented = false
                        },
                        onExit: {
                            isLinkPresented = false
                        }
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }

    private func startLinking() async {
        isLoading = true
        errorMessage = nil

        do {
            linkToken = try await plaidService.getLinkToken()
            await MainActor.run {
                isLinkPresented = true
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Plaid Link Handler

struct PlaidLinkController: UIViewControllerRepresentable {
    let linkToken: String
    let onSuccess: (String, String) -> Void  // publicToken, institutionName
    let onExit: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = PlaidHostingViewController()
        vc.linkToken = linkToken
        vc.onSuccess = onSuccess
        vc.onExit = onExit
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

class PlaidHostingViewController: UIViewController {
    var linkToken: String = ""
    var onSuccess: ((String, String) -> Void)?
    var onExit: (() -> Void)?
    private var handler: Handler?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Only open Plaid Link once
        guard handler == nil else { return }

        var config = LinkTokenConfiguration(token: linkToken) { [weak self] success in
            self?.onSuccess?(success.publicToken, success.metadata.institution.name)
        }

        config.onExit = { [weak self] _ in
            self?.onExit?()
        }

        let result = Plaid.create(config)
        switch result {
        case .success(let handler):
            self.handler = handler
            handler.open(presentUsing: .viewController(self))
        case .failure:
            onExit?()
        }
    }
}

#Preview {
    LinkBankView()
}
