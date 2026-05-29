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
                // MARK: Linked Accounts Section
                if !plaidService.linkedAccounts.isEmpty {
                    Section {
                        ForEach(plaidService.linkedAccounts) { account in
                            HStack {
                                Image(systemName: "building.columns")
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.accentSoft())
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                                VStack(alignment: .leading) {
                                    Text(account.displayName)
                                        .font(.app(.subheadline))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(account.institutionName)
                                        .font(.app(.caption))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    plaidService.unlinkAccount(account)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Theme.danger)
                                }
                            }
                        }
                    } header: {
                        Text("Linked Accounts")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else {
                    // Empty state when no accounts linked
                    Section {
                        AppEmptyState(
                            icon: "building.columns",
                            title: "No Accounts Linked",
                            message: "Connect your credit card accounts to automatically import transactions."
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }
                }

                // MARK: Add Account Section
                Section {
                    Button {
                        Task {
                            await startLinking()
                        }
                    } label: {
                        HStack {
                            Text(isLoading ? "Connecting…" : "Link Bank Account")
                                .font(.app(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                            if isLoading {
                                Spacer()
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isLoading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } footer: {
                    Text("Connect your credit card accounts to automatically import transactions.")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Error Message
                if let error = errorMessage {
                    Section {
                        AppEmptyState(
                            icon: "exclamationmark.triangle.fill",
                            title: "Connection Error",
                            message: error
                        )
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                    }
                }

                // MARK: Info Section
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28, height: 28)
                            .background(Theme.accentSoft())
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secure Connection")
                                .font(.app(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)

                            Text("\(Brand.displayName) uses Plaid to securely connect to your bank. Your login credentials are never stored on our servers.")
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.accent)
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
