import SwiftUI

/// A sheet presenting one or more versions' release notes. Brand-styled to match onboarding.
struct WhatsNewView: View {
    let notes: [ReleaseNote]
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var allHighlights: [String] {
        notes.flatMap { $0.highlights }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metric.gap) {
                    ForEach(Array(allHighlights.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.app(.title3, weight: .bold))
                                .foregroundStyle(Theme.accent)
                            Text(line)
                                .font(.app(.body))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(Theme.Metric.pad)
            }

            Button {
                onDismiss()
                dismiss()
            } label: {
                Text("Continue")
                    .font(.app(.headline, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.heroGradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius))
            }
            .padding(Theme.Metric.pad)
        }
        .background(Theme.bg.ignoresSafeArea())
        .interactiveDismissDisabled(false)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(.white)
            Text("What's New")
                .font(.app(.largeTitle, weight: .bold))
                .foregroundStyle(.white)
            if let v = notes.first?.version {
                Text("Version \(v)")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 28)
        .background(Theme.heroGradient)
    }
}
