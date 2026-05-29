import SwiftUI

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Last Updated: February 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        section(title: "Introduction") {
                            """
                            CardWise ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.
                            """
                        }

                        section(title: "Information We Collect") {
                            """
                            We may collect information that you provide directly to us, including:

                            • Account Information: Email address and authentication credentials when you create an account.

                            • Credit Card Information: Card names and reward categories you add to your wallet. We do NOT collect actual card numbers, CVVs, or sensitive financial data.

                            • Spending Records: Transaction amounts, merchants, categories, and dates that you manually enter or scan.

                            • Device Information: Device type, operating system, and app usage statistics.
                            """
                        }

                        section(title: "How We Use Your Information") {
                            """
                            We use the information we collect to:

                            • Provide personalized credit card recommendations
                            • Track your spending and calculate rewards
                            • Send notifications about rotating categories and spending caps
                            • Improve our services and user experience
                            • Respond to your inquiries and support requests
                            """
                        }

                        section(title: "Data Storage and Security") {
                            """
                            Your data is stored securely using Firebase, a Google Cloud service. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.

                            All data transmission is encrypted using industry-standard TLS/SSL protocols.
                            """
                        }
                    }

                    Group {
                        section(title: "Data Sharing") {
                            """
                            We do not sell, trade, or rent your personal information to third parties. We may share information only in the following circumstances:

                            • With service providers who assist in operating our app (e.g., Firebase for data storage)
                            • When required by law or to protect our rights
                            • With your consent
                            """
                        }

                        section(title: "Your Rights") {
                            """
                            You have the right to:

                            • Access your personal data
                            • Correct inaccurate data
                            • Delete your account and associated data
                            • Export your data
                            • Opt-out of marketing communications

                            To exercise these rights, please contact us at support@cardwiseapp.com.
                            """
                        }

                        section(title: "Children's Privacy") {
                            """
                            Our app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13.
                            """
                        }

                        section(title: "Changes to This Policy") {
                            """
                            We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.
                            """
                        }

                        section(title: "Contact Us") {
                            """
                            If you have questions about this Privacy Policy, please contact us at:

                            Email: support@cardwiseapp.com
                            """
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content())
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Terms of Service View

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Last Updated: February 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        section(title: "Acceptance of Terms") {
                            """
                            By downloading, installing, or using CardWise, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.
                            """
                        }

                        section(title: "Description of Service") {
                            """
                            CardWise is a credit card rewards optimization tool that:

                            • Helps you track your credit cards and their reward categories
                            • Recommends which card to use for specific purchases
                            • Tracks your spending and rewards earned
                            • Provides notifications about rotating categories and spending limits

                            CardWise is an informational tool and does not provide financial advice.
                            """
                        }

                        section(title: "User Responsibilities") {
                            """
                            You agree to:

                            • Provide accurate information when using the app
                            • Keep your account credentials secure
                            • Use the app only for lawful purposes
                            • Not attempt to reverse engineer or modify the app
                            • Verify all credit card reward information with your card issuer
                            """
                        }

                        section(title: "Subscriptions and Billing") {
                            """
                            CardWise Pro is an auto-renewable subscription offered as a monthly or yearly plan.

                            • Payment is charged to your Apple Account at confirmation of purchase.
                            • The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period.
                            • Your account is charged for renewal within 24 hours prior to the end of the current period, at the price of the selected plan.
                            • You can manage or cancel your subscription at any time in your Apple Account settings; cancellation takes effect at the end of the current billing period.
                            • Prices may vary by region and are shown in the app before purchase.
                            """
                        }

                        section(title: "Disclaimer of Warranties") {
                            """
                            THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE:

                            • The accuracy of credit card reward information
                            • That the app will be error-free or uninterrupted
                            • That recommendations will result in optimal rewards

                            Credit card terms and rewards can change at any time. Always verify current terms with your card issuer.
                            """
                        }
                    }

                    Group {
                        section(title: "Limitation of Liability") {
                            """
                            TO THE MAXIMUM EXTENT PERMITTED BY LAW, CARDWISE SHALL NOT BE LIABLE FOR:

                            • Any indirect, incidental, or consequential damages
                            • Loss of profits or data
                            • Decisions made based on app recommendations

                            Our total liability shall not exceed the amount you paid for the app (if any).
                            """
                        }

                        section(title: "Intellectual Property") {
                            """
                            All content, features, and functionality of CardWise are owned by us and protected by intellectual property laws. You may not copy, modify, or distribute any part of the app without our permission.
                            """
                        }

                        section(title: "Account Termination") {
                            """
                            We reserve the right to suspend or terminate your account if you violate these terms or engage in fraudulent or harmful activities.
                            """
                        }

                        section(title: "Governing Law") {
                            """
                            These terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles.
                            """
                        }

                        section(title: "Changes to Terms") {
                            """
                            We may modify these terms at any time. Continued use of the app after changes constitutes acceptance of the new terms.
                            """
                        }

                        section(title: "Contact") {
                            """
                            For questions about these Terms of Service, contact us at:

                            Email: support@cardwiseapp.com
                            """
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content())
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}

#Preview("Terms of Service") {
    TermsOfServiceView()
}
