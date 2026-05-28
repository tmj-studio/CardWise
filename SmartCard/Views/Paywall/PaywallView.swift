import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var subscription: SubscriptionManager
    @Environment(\.dismiss) var dismiss

    @State private var isPurchasing = false
    @State private var showingPrivacy = false
    @State private var showingTerms = false

    // v1 lists only the features actually enforced as Pro.
    private let features: [(icon: String, text: String)] = [
        ("creditcard.fill", "Unlimited cards"),
        ("building.columns.fill", "Auto bank detection"),
        ("chart.bar.fill", "Advanced analytics & yearly summary")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.yellow)
                        Text("SmartCard Pro")
                            .font(.largeTitle.bold())
                        Text("Maximize every swipe.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features, id: \.text) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                Text(feature.text)
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if subscription.loadFailed {
                        VStack(spacing: 8) {
                            Text("Couldn't load plans. Please try again.")
                                .foregroundStyle(.secondary)
                            Button("Retry") {
                                Task { await subscription.loadProducts() }
                            }
                            .buttonStyle(.bordered)
                        }
                    } else if subscription.products.isEmpty {
                        ProgressView().padding()
                    } else {
                        ForEach(subscription.products, id: \.id) { product in
                            Button {
                                Task {
                                    isPurchasing = true
                                    let success = await subscription.purchase(product)
                                    isPurchasing = false
                                    if success { dismiss() }
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName)
                                            .fontWeight(.semibold)
                                        if product.id == SubscriptionManager.ProductID.yearly {
                                            Text("Best value — save ~44%")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    Spacer()
                                    Text(product.displayPrice)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isPurchasing)
                        }
                    }

                    Button("Restore Purchases") {
                        Task {
                            await subscription.restorePurchases()
                            if subscription.isPro { dismiss() }
                        }
                    }
                    .font(.footnote)
                    .disabled(isPurchasing)

                    // App Store-required auto-renewable subscription disclosure.
                    Text("""
                    Payment is charged to your Apple Account at confirmation of purchase. \
                    The subscription automatically renews unless it is canceled at least 24 hours \
                    before the end of the current period. Your account is charged for renewal within \
                    24 hours prior to the end of the current period. You can manage or cancel your \
                    subscription in your Apple Account settings after purchase.
                    """)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Button("Privacy Policy") { showingPrivacy = true }
                        Button("Terms of Service (EULA)") { showingTerms = true }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showingTerms) { TermsOfServiceView() }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
}
