import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("rotatingReminders") private var rotatingReminders = true
    @AppStorage("spendingCapAlerts") private var spendingCapAlerts = true
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingClearDataAlert = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: About
                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack {
                        Text("Cards in Database")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(cardViewModel.allCards.count)")
                            .foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text("About")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Notifications
                Section {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .foregroundStyle(Theme.textPrimary)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            if newValue {
                                NotificationService.shared.requestAuthorization { _ in }
                            }
                        }

                    Toggle("Rotating Category Reminders", isOn: $rotatingReminders)
                        .foregroundStyle(Theme.textPrimary)
                        .disabled(!notificationsEnabled)

                    Toggle("Spending Cap Alerts", isOn: $spendingCapAlerts)
                        .foregroundStyle(Theme.textPrimary)
                        .disabled(!notificationsEnabled)
                } header: {
                    Text("Notifications")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Your Data
                Section {
                    HStack {
                        Text("Cards in Wallet")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(cardViewModel.userCards.count)")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack {
                        Text("Spending Records")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(spendingViewModel.spendings.count)")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack {
                        Text("Total Rewards Earned")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(formatCurrency(spendingViewModel.totalRewardsEarned))
                            .foregroundStyle(Theme.success)
                    }
                } header: {
                    Text("Your Data")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Data Management
                Section {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Text("Clear All Data")
                            .foregroundStyle(Theme.danger)
                    }
                } header: {
                    Text("Data Management")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Support
                Section {
                    if let appReviewURL {
                        Link(destination: appReviewURL) {
                            HStack {
                                settingsRow(icon: "star", label: "Rate on App Store")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.app(.caption))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        settingsRow(icon: "hand.raised", label: "Privacy Policy")
                    }

                    Button {
                        showingTermsOfService = true
                    } label: {
                        settingsRow(icon: "doc.text", label: "Terms of Service")
                    }

                    Link(destination: URL(string: "mailto:support@cardwiseapp.com")!) {
                        HStack {
                            settingsRow(icon: "envelope", label: "Contact Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                } header: {
                    Text("Support")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Footer branding
                Section {
                    VStack(spacing: 8) {
                        Text(Brand.displayName)
                            .font(.app(.headline, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Maximize your credit card rewards")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .tint(Theme.accent)
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showingTermsOfService) {
                TermsOfServiceView()
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    cardViewModel.clearAllData()
                    spendingViewModel.clearAllData()
                }
            } message: {
                Text("This will delete all your cards, spending records, and preferences. This action cannot be undone.")
            }
        }
    }

    // MARK: - Row helper: icon in accentSoft tile + label
    @ViewBuilder
    private func settingsRow(icon: String, label: String) -> some View {
        Label {
            Text(label)
                .foregroundStyle(Theme.textPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accentSoft())
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }

    private var appReviewURL: URL? {
        nil
    }
}

#Preview {
    SettingsView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
}
