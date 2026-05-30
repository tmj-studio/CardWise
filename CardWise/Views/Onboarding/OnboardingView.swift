import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    imageName: "creditcard.fill",
                    title: "Welcome to \(Brand.displayName)",
                    description: "Never miss out on credit card rewards again. We'll tell you which card to use for every purchase.",
                    page: 0
                )
                .tag(0)

                OnboardingPage(
                    imageName: "sparkles",
                    title: "Smart Recommendations",
                    description: "Just tell us what you're buying - we'll instantly show you the best card to maximize your rewards.",
                    page: 1
                )
                .tag(1)

                OnboardingPage(
                    imageName: "arrow.triangle.2.circlepath",
                    title: "Track Rotating Categories",
                    description: "We'll remind you when quarterly bonus categories change and help you activate them on time.",
                    page: 2
                )
                .tag(2)

                OnboardingPage(
                    imageName: "chart.pie.fill",
                    title: "Spending Insights",
                    description: "Track your spending, see rewards earned, and discover opportunities you might have missed.",
                    page: 3
                )
                .tag(3)

                OnboardingGetStartedPage(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(currentPage == index ? Theme.accent : Theme.surfaceAlt)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .font(.app(.body))
                }

                Spacer()

                if currentPage < 4 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .font(.app(.headline, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .screenBackground()
    }
}

struct OnboardingPage: View {
    let imageName: String
    let title: String
    let description: String
    let page: Int

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon in accent soft circle
            ZStack {
                Circle()
                    .fill(Theme.accentSoft())
                    .frame(width: 150, height: 150)

                Image(systemName: imageName)
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 16) {
                Text(title)
                    .font(.app(.title, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.app(.body))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

struct OnboardingGetStartedPage: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var cardViewModel: CardViewModel

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon in accent soft circle
            ZStack {
                Circle()
                    .fill(Theme.accentSoft())
                    .frame(width: 150, height: 150)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.app(.title, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Add your credit cards to get personalized recommendations.")
                    .font(.app(.body))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Get Started")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 30)

                if !cardViewModel.userCards.isEmpty {
                    Text("\(cardViewModel.userCards.count) cards already added")
                        .font(.app(.caption))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(CardViewModel(store: CloudStore.preview()))
}
