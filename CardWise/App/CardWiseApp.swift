import SwiftUI
import SwiftData
import WidgetKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }

    // Support all interface orientations to comply with App Store guidelines
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .all
    }
}

enum AppContainer {
    /// Local SwiftData store today; CloudKit-synced once the iCloud entitlement is
    /// provisioned in Task 11.
    ///
    /// NOTE: The CloudKit attempt is intentionally skipped here because the iCloud
    /// entitlement (com.apple.developer.icloud-services) does not yet exist.
    /// Enabling it without the entitlement causes the CloudKit daemon to crash the
    /// process with a signal trap before the test runner can connect — the error
    /// is not a Swift throw and therefore cannot be caught with try?.
    ///
    /// TODO(Task 11): uncomment the CloudKit first-attempt block below once the
    /// iCloud entitlement is provisioned in the Apple Developer portal and the
    /// CardWise.entitlements file is updated.
    static let shared: ModelContainer = {
        // TODO(Task 11): uncomment once iCloud entitlement is provisioned:
        // if let cloud = try? ModelContainer(
        //     for: UserCardRecord.self, SpendingRecord.self,
        //     configurations: ModelConfiguration("CardWise", cloudKitDatabase: .private("iCloud.com.cardwise.app"))
        // ) {
        //     return cloud
        // }
        if let local = try? ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self,
            configurations: ModelConfiguration("CardWise", cloudKitDatabase: .none)
        ) {
            return local
        }
        return try! ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }()
}

@main
struct CardWiseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @StateObject private var cardViewModel: CardViewModel
    @StateObject private var spendingViewModel: SpendingViewModel

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppAppearance.apply()
        let store = CloudStore(context: AppContainer.shared.mainContext)
        store.migrateFromKeychainIfNeeded()
        _cardViewModel = StateObject(wrappedValue: CardViewModel(store: store))
        _spendingViewModel = StateObject(wrappedValue: SpendingViewModel(store: store))
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .onChange(of: scenePhase) { _, newPhase in
                        if newPhase == .background {
                            updateWidgetData()
                        }
                    }
                    .onAppear {
                        CacheManager.shared.clearExpired()
                        updateWidgetData()
                    }
                    .modelContainer(AppContainer.shared)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(cardViewModel)
                    .environmentObject(spendingViewModel)
                    .modelContainer(AppContainer.shared)
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
            spendingViewModel: spendingViewModel
        )
    }
}
