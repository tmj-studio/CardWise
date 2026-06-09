import SwiftUI

// Legal copy is authored as long multi-line string literals; hard-wrapping would
// alter the rendered text, so the line-length rule is disabled for this file.
// swiftlint:disable line_length

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Last Updated: 2026-05-31")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)

                        section(title: "Introduction") {
                            """
                            CardWise ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we handle your information when you use our mobile application. CardWise is a free app with no backend servers. Your personal data never leaves your device or your own iCloud account.
                            """
                        }

                        section(title: "Information We Do NOT Collect") {
                            """
                            CardWise does not collect, transmit, or store any personal data on our servers because we have no servers. Specifically, we do not:

                            • Collect your name, email address, or account credentials.
                            • Link to or access your bank accounts or credit card accounts.
                            • Transmit your spending records, card details, or any other personal data to us or any third party.
                            • Use analytics services, advertising networks, or tracking technologies.
                            • Share any information with third parties.
                            """
                        }

                        section(title: "Information Stored On Your Device") {
                            """
                            All data you enter into CardWise — including your card names, reward configurations, and spending records — is stored exclusively on your device using Apple's standard local storage. This data is only accessible to you.

                            CardWise does not collect actual card numbers, CVVs, account passwords, or any sensitive financial credentials. You add card names and reward categories for recommendation purposes only.
                            """
                        }

                        section(title: "iCloud Sync") {
                            """
                            If you choose to enable iCloud on your device, your CardWise data may sync across your personal Apple devices through Apple's CloudKit private database. This sync occurs entirely within your own iCloud account and is governed by Apple's iCloud terms and privacy policy. We — the CardWise developer — have no access to your iCloud data at any time.
                            """
                        }

                        section(title: "Camera and Photo Library") {
                            """
                            CardWise may request access to your camera or photo library solely to scan receipts using on-device OCR (Apple's Vision framework). Receipt images are processed entirely on your device and are never uploaded, stored beyond the scan session, or shared with anyone.

                            You can revoke camera or photo access at any time in your device's Settings app.
                            """
                        }

                        section(title: "Card Reward Database") {
                            """
                            The credit card reward information displayed in CardWise (bonus categories, earn rates, etc.) is bundled directly in the app as reference data. It is not personal information and does not originate from your accounts. Always verify current reward terms directly with your card issuer, as terms can change.
                            """
                        }
                    }

                    Group {
                        section(title: "No Tracking or Advertising") {
                            """
                            CardWise contains no advertising, no behavioral tracking, and no analytics. We do not use any third-party SDKs that collect personal information.
                            """
                        }

                        section(title: "Children's Privacy") {
                            """
                            CardWise is not directed to children under the age of 13. Because we do not collect any personal information, there is no risk of inadvertently collecting children's data.
                            """
                        }

                        section(title: "Your Rights") {
                            """
                            Because we do not collect or store your personal data on any server, there is nothing for us to access, correct, export, or delete on your behalf. All your CardWise data resides on your own device and iCloud account, where you have full control. You can delete your data at any time from within the app (Settings → Clear All Data) or by deleting the app.
                            """
                        }

                        section(title: "Changes to This Policy") {
                            """
                            We may update this Privacy Policy from time to time to reflect changes in the app. We will update the "Last Updated" date at the top of this policy when changes are made.
                            """
                        }

                        section(title: "Contact Us") {
                            """
                            If you have questions about this Privacy Policy, please contact us at:

                            Email: contact@tailormyjob.com
                            """
                        }
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(content())
                .font(.app(.body))
                .foregroundStyle(Theme.textPrimary)
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
                        Text("Last Updated: 2026-05-31")
                            .font(.app(.caption))
                            .foregroundStyle(Theme.textSecondary)

                        section(title: "Acceptance of Terms") {
                            """
                            By downloading, installing, or using CardWise, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.
                            """
                        }

                        section(title: "Description of Service") {
                            """
                            CardWise is a free credit card rewards optimization tool that:

                            • Helps you track your credit cards and their reward categories
                            • Recommends which card to use for specific purchases or merchant categories
                            • Tracks your spending and estimated rewards earned
                            • Provides notifications about rotating categories and spending caps

                            CardWise is an informational tool and does not provide financial, legal, or tax advice. The app has no backend servers, does not link to your financial accounts, and does not transmit your personal data anywhere.
                            """
                        }

                        section(title: "Free Service — No Subscriptions") {
                            """
                            CardWise is completely free. There are no in-app purchases, no subscription plans, no Pro tiers, and no charges of any kind. You will never be billed through the app.
                            """
                        }

                        section(title: "User Responsibilities") {
                            """
                            You agree to:

                            • Provide accurate information when using the app
                            • Use the app only for lawful purposes
                            • Not attempt to reverse engineer or modify the app
                            • Verify all credit card reward information with your card issuer, as terms can change at any time
                            """
                        }

                        section(title: "Disclaimer of Warranties") {
                            """
                            THE APP IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND. WE DO NOT GUARANTEE:

                            • The accuracy or completeness of credit card reward information in the database
                            • That the app will be error-free or uninterrupted
                            • That recommendations will result in optimal rewards for your situation

                            Credit card terms and rewards can change at any time. Always verify current terms directly with your card issuer before making financial decisions.
                            """
                        }
                    }

                    Group {
                        section(title: "Limitation of Liability") {
                            """
                            TO THE MAXIMUM EXTENT PERMITTED BY LAW, CARDWISE SHALL NOT BE LIABLE FOR:

                            • Any indirect, incidental, or consequential damages
                            • Loss of data
                            • Financial decisions made based on app recommendations

                            CardWise is a free reference tool. Our total liability to you for any claim arising from your use of the app shall not exceed zero dollars ($0.00), as no payment is ever charged.
                            """
                        }

                        section(title: "Intellectual Property") {
                            """
                            All content, features, and functionality of CardWise — including but not limited to the app's design, code, and bundled card reward database — are owned by us and protected by applicable intellectual property laws. You may not copy, modify, or distribute any part of the app without our written permission.
                            """
                        }

                        section(title: "Governing Law") {
                            """
                            These terms shall be governed by and construed in accordance with the laws of the United States, without regard to conflict of law principles.
                            """
                        }

                        section(title: "Changes to Terms") {
                            """
                            We may modify these terms at any time. We will update the "Last Updated" date at the top of this document when changes are made. Continued use of the app after changes constitutes your acceptance of the new terms.
                            """
                        }

                        section(title: "Contact") {
                            """
                            For questions about these Terms of Service, contact us at:

                            Email: contact@tailormyjob.com
                            """
                        }
                    }
                }
                .padding()
            }
            .screenBackground()
            .navigationTitle("Terms of Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private func section(title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.app(.headline, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(content())
                .font(.app(.body))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

#Preview("Privacy Policy") {
    PrivacyPolicyView()
}

#Preview("Terms of Service") {
    TermsOfServiceView()
}
