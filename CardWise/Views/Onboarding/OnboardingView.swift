import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    imageName: "creditcard.fill",
                    imageColor: .blue,
                    title: "Welcome to SmartCard",
                    description: "Never miss out on credit card rewards again. We'll tell you which card to use for every purchase.",
                    page: 0
                )
                .tag(0)

                OnboardingPage(
                    imageName: "sparkles",
                    imageColor: .yellow,
                    title: "Smart Recommendations",
                    description: "Just tell us what you're buying - we'll instantly show you the best card to maximize your rewards.",
                    page: 1
                )
                .tag(1)

                OnboardingPage(
                    imageName: "arrow.triangle.2.circlepath",
                    imageColor: .orange,
                    title: "Track Rotating Categories",
                    description: "We'll remind you when quarterly bonus categories change and help you activate them on time.",
                    page: 2
                )
                .tag(2)

                OnboardingPage(
                    imageName: "chart.pie.fill",
                    imageColor: .green,
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
                        .fill(currentPage == index ? Color.blue : Color(.systemGray4))
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
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if currentPage < 4 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
    }
}

struct OnboardingPage: View {
    let imageName: String
    let imageColor: Color
    let title: String
    let description: String
    let page: Int

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(imageColor.opacity(0.15))
                    .frame(width: 150, height: 150)

                Image(systemName: imageName)
                    .font(.system(size: 60))
                    .foregroundStyle(imageColor)
            }

            VStack(spacing: 16) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
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

            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 150, height: 150)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Add your credit cards to get personalized recommendations.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                if !cardViewModel.userCards.isEmpty {
                    Text("\(cardViewModel.userCards.count) cards already added")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(CardViewModel())
}
