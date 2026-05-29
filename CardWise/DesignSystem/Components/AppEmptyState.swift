import SwiftUI

struct AppEmptyState: View {
    let icon: String, title: String, message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accentSoft()).clipShape(Circle())
            Text(title).font(.app(.title3, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text(message).font(.app(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }.padding(32)
    }
}
