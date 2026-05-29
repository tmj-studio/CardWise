import SwiftUI

struct RankBadge: View {
    let rank: Int
    var isTop: Bool { rank == 1 }
    var body: some View {
        Text("\(rank)")
            .font(.app(.headline, weight: .bold))
            .foregroundStyle(isTop ? .white : Theme.textPrimary)
            .frame(width: 32, height: 32)
            .background(isTop ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Theme.surfaceAlt))
            .clipShape(Circle())
    }
}

struct RewardBadge: View {
    let text: String          // "2%" / "3x"
    var emphasized: Bool
    var body: some View {
        Text(text)
            .font(.app(.title2, weight: .bold)).monospacedDigit()
            .foregroundStyle(emphasized ? Theme.success : Theme.textPrimary)
    }
}
