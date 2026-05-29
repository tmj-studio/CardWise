import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscription: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

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
                VStack(spacing: 0) {
                    // MARK: Hero header
                    heroHeader

                    // MARK: Scrollable body
                    VStack(spacing: 20) {
                        featureList

                        productSection

                        Button("Restore Purchases") {
                            Task {
                                isPurchasing = true
                                await subscription.restorePurchases()
                                isPurchasing = false
                                if subscription.isPro { dismiss() }
                            }
                        }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(isPurchasing)

                        // App Store-required auto-renewable subscription disclosure.
                        Text("""
                        Payment is charged to your Apple Account at confirmation of purchase. \
                        The subscription automatically renews unless it is canceled at least 24 hours \
                        before the end of the current period. Your account is charged for renewal within \
                        24 hours prior to the end of the current period. You can manage or cancel your \
                        subscription in your Apple Account settings after purchase.
                        """)
                        .font(.app(.caption2))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button("Privacy Policy") { showingPrivacy = true }
                            Button("Terms of Service (EULA)") { showingTerms = true }
                        }
                        .font(.app(.caption))
                        .foregroundStyle(Theme.accent)
                    }
                    .padding(Theme.Metric.pad)
                }
            }
            .screenBackground()
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .sheet(isPresented: $showingPrivacy) { PrivacyPolicyView() }
            .sheet(isPresented: $showingTerms) { TermsOfServiceView() }
        }
    }

    // MARK: - Subviews

    private var heroHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white)

            Text("\(Brand.displayName) Pro")
                .font(.app(.largeTitle, weight: .bold))
                .foregroundStyle(.white)

            Text(Brand.tagline)
                .font(.app(.subheadline))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 72)
        .padding(.bottom, 32)
        .padding(.horizontal, Theme.Metric.pad)
        .frame(maxWidth: .infinity)
        .background(Theme.heroGradient)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28)
                    Text(feature.text)
                        .font(.app(.body))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
            }
        }
        .sectionCard()
    }

    @ViewBuilder
    private var productSection: some View {
        if subscription.loadFailed {
            VStack(spacing: 12) {
                Text("Couldn't load plans. Please try again.")
                    .font(.app(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await subscription.loadProducts() }
                }
                .buttonStyle(SoftButtonStyle())
            }
            .sectionCard()
        } else if subscription.products.isEmpty {
            ProgressView()
                .tint(Theme.accent)
                .padding()
        } else {
            VStack(spacing: 12) {
                ForEach(subscription.products, id: \.id) { product in
                    productCard(for: product)
                }
            }
        }
    }

    private func productCard(for product: Product) -> some View {
        Button {
            Task {
                isPurchasing = true
                let success = await subscription.purchase(product)
                isPurchasing = false
                if success { dismiss() }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.app(.headline, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if product.id == SubscriptionManager.ProductID.yearly {
                        Text("Best value — save ~44%")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.success)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.app(.title3, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
            }
            .padding(Theme.Metric.pad)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 1.5)
            )
            .softShadow()
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

#Preview {
    PaywallView()
        .environmentObject(SubscriptionManager.shared)
}
