import SwiftUI
import WidgetKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if FirebaseService.hasValidConfiguration {
            FirebaseApp.configure()
        }
        return true
    }

    // Support all interface orientations to comply with App Store guidelines
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .all
    }
}

@main
struct CardWiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var cardViewModel = CardViewModel()
    @StateObject private var spendingViewModel = SpendingViewModel()
    // Hold a strong reference to the singleton so SwiftUI treats it as a StateObject owner.
    @StateObject private var subscription = SubscriptionManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .environmentObject(subscription)
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .background {
                            updateWidgetData()
                        }
                    }
                    .onAppear {
                        CacheManager.shared.clearExpired()
                        updateWidgetData()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .environmentObject(subscription)
            }

            // Uncomment when Firebase Auth is configured:
            // if authService.isAuthenticated {
            //     MainTabView()
            //         .environmentObject(authService)
            //         .environmentObject(cardViewModel)
            //         .environmentObject(spendingViewModel)
            // } else {
            //     AuthView()
            //         .environmentObject(authService)
            // }
        }
    }

    private func updateWidgetData() {
        WidgetDataManager.shared.updateWidgetData(
            cardViewModel: cardViewModel,
            spendingViewModel: spendingViewModel,
            isPro: subscription.isPro
        )
    }
}
