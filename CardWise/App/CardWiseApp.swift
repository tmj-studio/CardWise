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
    /// NOTE: The CloudKit code path is intentionally kept commented out.
    /// CardWise.entitlements now carries the iCloud/CloudKit entitlements, but the
    /// iCloud container "iCloud.com.cardwise.app" must first be created in the Apple
    /// Developer account and the app's provisioning profile must include the iCloud
    /// capability. Without that, activating CloudKit causes an uncatchable SIGTRAP on
    /// launch (the CloudKit daemon crashes the process before Swift can handle it).
    ///
    /// TODO: CloudKit sync is entitlement-ready (see CardWise.entitlements). To enable:
    ///   1. In the Apple Developer account, create the CloudKit container "iCloud.com.cardwise.app"
    ///      and ensure the app's provisioning profile includes the iCloud capability.
    ///   2. Uncomment the .private(...) attempt below; it becomes the first choice with local fallback.
    static let shared: ModelContainer = {
        // TODO: Uncomment once the CloudKit container is provisioned in the Apple Developer account:
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
        // swiftlint:disable:next force_try - last-resort in-memory store; if even this fails the app cannot run
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
    @AppStorage("lastSeenVersion") private var lastSeenVersion = ""
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @StateObject private var updateChecker = AppUpdateChecker()
    @State private var whatsNewNotes: [ReleaseNote] = []

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
                    .task {
                        let notes = WhatsNew.notesToPresent(lastSeen: lastSeenVersion,
                                                            current: AppVersion.current)
                        if !notes.isEmpty { whatsNewNotes = notes }
                        lastSeenVersion = AppVersion.current
                        await updateChecker.checkIfDue()
                    }
                    .sheet(isPresented: Binding(
                        get: { !whatsNewNotes.isEmpty },
                        set: { if !$0 { whatsNewNotes = [] } }
                    )) {
                        WhatsNewView(notes: whatsNewNotes) { whatsNewNotes = [] }
                    }
                    .alert("Update Available", isPresented: Binding(
                        get: { updateChecker.availableVersion != nil },
                        set: { if !$0 { updateChecker.dismiss() } }
                    )) {
                        Button("Update") {
                            if let url = updateChecker.appStoreURL { openURL(url) }
                            updateChecker.dismiss()
                        }
                        Button("Later", role: .cancel) { updateChecker.dismiss() }
                    } message: {
                        if let v = updateChecker.availableVersion {
                            Text("Version \(v) is available on the App Store.")
                        }
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
