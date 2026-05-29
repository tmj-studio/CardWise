import SwiftUI

struct StatColumn: View {
    let title: String, value: String, tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.app(.title3, weight: .bold)).monospacedDigit().foregroundStyle(tint)
            Text(title).font(.app(.caption)).foregroundStyle(.white.opacity(0.85))
        }.frame(maxWidth: .infinity)
    }
}

struct HeroStatCard: View {
    let title: String
    let columns: [(title: String, value: String, tint: Color)]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.app(.subheadline, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, c in
                    StatColumn(title: c.title, value: c.value, tint: c.tint)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.heroRadius, style: .continuous))
        .softShadow()
    }
}
