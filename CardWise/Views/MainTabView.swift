import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            CardListView()
                .tabItem {
                    Label("My Cards", systemImage: "creditcard.fill")
                }
                .tag(1)

            RecommendView()
                .tabItem {
                    Label("Recommend", systemImage: "star.fill")
                }
                .tag(2)

            SpendingListView()
                .tabItem {
                    Label("Spending", systemImage: "chart.bar.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(CardViewModel())
        .environmentObject(SpendingViewModel())
        .environmentObject(SubscriptionManager.shared)
}
