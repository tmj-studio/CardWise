import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject var cardViewModel: CardViewModel
    @EnvironmentObject var spendingViewModel: SpendingViewModel
    @EnvironmentObject private var subscription: SubscriptionManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("rotatingReminders") private var rotatingReminders = true
    @AppStorage("spendingCapAlerts") private var spendingCapAlerts = true
    @State private var showingPrivacyPolicy = false
    @State private var showingTermsOfService = false
    @State private var showingLinkBank = false
    @State private var showingClearDataAlert = false
    @State private var showingPaywall = false
    @State private var showingManageSubscriptions = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Pro Section
                Section {
                    if subscription.isPro {
                        HStack {
                            Label("Pro Active", systemImage: "star.circle.fill")
                                .foregroundStyle(Theme.success)
                            Spacer()
                        }
                        Button {
                            showingManageSubscriptions = true
                        } label: {
                            settingsRow(icon: "gearshape", label: "Manage Subscription")
                        }
                    } else {
                        // Gradient Pro upsell banner
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "star.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to \(Brand.displayName) Pro")
                                        .font(.app(.headline, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text("Unlock all features")
                                        .font(.app(.caption))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.app(.subheadline, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            Theme.heroGradient
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        )
                    }

                    Button {
                        Task { await subscription.restorePurchases() }
                    } label: {
                        settingsRow(icon: "arrow.clockwise", label: "Restore Purchases")
                    }
                } header: {
                    Text("\(Brand.displayName) Pro")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }

                // MARK: Bank Connection
                Section {
                    Button {
                        if !FirebaseService.hasValidConfiguration {
                            return
                        } else if SubscriptionGate.isUnlocked(.bankLinking, isPro: subscription.isPro) {
                            showingLinkBank = true
                        } else {
                            showingPaywall = true
                        }
                    } label: {
                        HStack {
                            settingsRow(icon: "building.columns", label: "Link Bank Account")
                            Spacer()
                            Text(bankConnectionStatus)
                                .font(.app(.caption))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .disabled(!FirebaseService.hasValidConfiguration)
                } header: {
                    Text("Bank Connection")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                } footer: {
                    if !FirebaseService.hasValidConfiguration {
                        Text("Bank linking requires a production Firebase and Plaid configuration.")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

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

                    if SubscriptionGate.isUnlocked(.capAlerts, isPro: subscription.isPro) {
                        Toggle("Spending Cap Alerts", isOn: $spendingCapAlerts)
                            .foregroundStyle(Theme.textPrimary)
                            .disabled(!notificationsEnabled)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                settingsRow(icon: "lock.fill", label: "Spending Cap Alerts")
                                Spacer()
                                Text("Pro")
                                    .font(.app(.caption, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
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
            .sheet(isPresented: $showingLinkBank) {
                LinkBankView()
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
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

    private var bankConnectionStatus: String {
        if !FirebaseService.hasValidConfiguration {
            return "Setup required"
        }

        return "\(PlaidService.shared.linkedAccounts.count) linked"
    }

    private var appReviewURL: URL? {
        nil
    }
}

#Preview {
    SettingsView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
