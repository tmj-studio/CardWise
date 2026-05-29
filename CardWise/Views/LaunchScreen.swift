import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                // Gradient app icon mark
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Theme.heroGradient)
                        .frame(width: 100, height: 100)
                        .softShadow()

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }

                // App name wordmark
                Text(Brand.displayName)
                    .font(.app(.largeTitle, weight: .bold))
                    .foregroundStyle(Theme.accent)

                // Tagline
                Text(Brand.tagline)
                    .font(.app(.subheadline))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    LaunchScreen()
}
