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
    /// CloudKit-synced SwiftData store (user's private database), falling back to a
    /// plain local store when CloudKit is unavailable — e.g. unsigned test/simulator
    /// runs, or no iCloud capability at runtime. The container
    /// "iCloud.com.cardwise.app" and the App ID's iCloud capability are provisioned
    /// (release profiles have carried these entitlements since v1.0.2).
    ///
    /// Sync in TestFlight/App Store builds additionally requires the CloudKit schema
    /// to be deployed to the Production environment (CloudKit Console → Deploy Schema
    /// Changes); until then, cloud-signed builds run happily but only store locally.
    static let shared: ModelContainer = {
        // Unsigned test runs (CODE_SIGNING_ALLOWED=NO) carry no CloudKit entitlement and
        // CKContainer SIGTRAPs the process before Swift can catch anything — `try?` does
        // not help. Only attempt CloudKit outside XCTest.
        let isHostedByXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if !isHostedByXCTest,
           let cloud = try? ModelContainer(
               for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
               configurations: ModelConfiguration("CardWise", cloudKitDatabase: .private("iCloud.com.cardwise.app"))
           ) {
            return cloud
        }
        if let local = try? ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
            configurations: ModelConfiguration("CardWise", cloudKitDatabase: .none)
        ) {
            return local
        }
        // swiftlint:disable:next force_try - last-resort in-memory store; if even this fails the app cannot run
        return try! ModelContainer(
            for: UserCardRecord.self, SpendingRecord.self, CreditUsageRecord.self,
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
                        updateWidgetData()
                        NotificationService.shared.refreshRotatingReminders(
                            hasRotatingCards: cardViewModel.hasRotatingCards
                        )
                    }
                    .task {
                        let notes = WhatsNew.notesToPresent(lastSeen: lastSeenVersion,
                                                            current: AppVersion.current)
                        if !notes.isEmpty { whatsNewNotes = notes }
                        lastSeenVersion = AppVersion.current
                        await updateChecker.checkIfDue()
                        await RemoteCatalogService().refresh()
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
