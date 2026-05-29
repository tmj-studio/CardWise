import SwiftUI

struct CategoryChip: View {
    let icon: String, title: String
    var selected: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.app(.subheadline, weight: .medium))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .foregroundStyle(selected ? Theme.accent : Theme.textPrimary)
        .background(selected ? Theme.accentSoft() : Theme.surfaceAlt)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Theme.accent : .clear, lineWidth: 1.5))
    }
}
