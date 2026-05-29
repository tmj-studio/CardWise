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
                Section("SmartCard Pro") {
                    if subscription.isPro {
                        HStack {
                            Label("Pro Active", systemImage: "star.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                        }
                        Button {
                            showingManageSubscriptions = true
                        } label: {
                            Label("Manage Subscription", systemImage: "gearshape")
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Label("Upgrade to Pro", systemImage: "star.circle.fill")
                                    .foregroundStyle(.yellow)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        Task { await subscription.restorePurchases() }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                }

                // Bank Connection
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
                            Label("Link Bank Account", systemImage: "building.columns")
                            Spacer()
                            Text(bankConnectionStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!FirebaseService.hasValidConfiguration)
                } header: {
                    Text("Bank Connection")
                } footer: {
                    if !FirebaseService.hasValidConfiguration {
                        Text("Bank linking requires a production Firebase and Plaid configuration.")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Cards in Database")
                        Spacer()
                        Text("\(cardViewModel.allCards.count)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            if newValue {
                                NotificationService.shared.requestAuthorization { _ in }
                            }
                        }

                    Toggle("Rotating Category Reminders", isOn: $rotatingReminders)
                        .disabled(!notificationsEnabled)

                    if SubscriptionGate.isUnlocked(.capAlerts, isPro: subscription.isPro) {
                        Toggle("Spending Cap Alerts", isOn: $spendingCapAlerts)
                            .disabled(!notificationsEnabled)
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack {
                                Label("Spending Cap Alerts", systemImage: "lock.fill")
                                Spacer()
                                Text("Pro")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Your Data") {
                    HStack {
                        Text("Cards in Wallet")
                        Spacer()
                        Text("\(cardViewModel.userCards.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Spending Records")
                        Spacer()
                        Text("\(spendingViewModel.spendings.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Total Rewards Earned")
                        Spacer()
                        Text(formatCurrency(spendingViewModel.totalRewardsEarned))
                            .foregroundStyle(.green)
                    }
                }

                Section("Data Management") {
                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Text("Clear All Data")
                    }
                }

                Section("Support") {
                    if let appReviewURL {
                        Link(destination: appReviewURL) {
                            HStack {
                                Label("Rate on App Store", systemImage: "star")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Button {
                        showingTermsOfService = true
                    } label: {
                        Label("Terms of Service", systemImage: "doc.text")
                    }

                    Link(destination: URL(string: "mailto:support@smartcardapp.com")!) {
                        HStack {
                            Label("Contact Support", systemImage: "envelope")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    VStack(spacing: 8) {
                        Text("SmartCard")
                            .font(.headline)
                        Text("Maximize your credit card rewards")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
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
