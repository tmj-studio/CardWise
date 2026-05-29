import SwiftUI

struct LaunchScreen: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.4, blue: 0.8),
                    Color(red: 0.2, green: 0.6, blue: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // App icon representation
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }

                // App name
                Text("SmartCard")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Tagline
                Text("Maximize Your Credit Card Rewards")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
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
