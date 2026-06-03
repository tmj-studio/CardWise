import Foundation
import SwiftUI
import os

/// Checks the App Store (via the public iTunes Lookup API) for a newer version and
/// surfaces a gentle, dismissible prompt. Backend-free; safe before the app is on the Store
/// (network failure / no result -> silent no-op).
@MainActor
final class AppUpdateChecker: ObservableObject {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "AppUpdateChecker")

    struct StoreInfo: Equatable {
        let version: String
        let trackViewUrl: String
    }

    /// Set when a newer version is available and not already dismissed; drives the alert.
    @Published var availableVersion: String?
    @Published var appStoreURL: URL?

    private let bundleID: String
    private let country: String
    private let installedVersion: String
    private let session: URLSession
    private let now: () -> Date

    @AppStorage("update.lastCheck") private var lastCheckEpoch: Double = 0
    @AppStorage("update.dismissedVersion") private var dismissedVersion: String = ""

    private let minInterval: TimeInterval = 60 * 60 * 24 // once per day

    init(bundleID: String = Bundle.main.bundleIdentifier ?? "studio.tmj.cardwise",
         country: String = "us",
         installedVersion: String = AppVersion.current,
         session: URLSession = .shared,
         now: @escaping () -> Date = Date.init) {
        self.bundleID = bundleID
        self.country = country
        self.installedVersion = installedVersion
        self.session = session
        self.now = now
    }

    /// Runs a check at most once per `minInterval`. Call on foreground.
    func checkIfDue() async {
        let nowEpoch = now().timeIntervalSince1970
        guard nowEpoch - lastCheckEpoch >= minInterval else { return }
        lastCheckEpoch = nowEpoch
        await check()
    }

    /// Forces a check regardless of the rate limit.
    func check() async {
        guard let url = Self.lookupURL(bundleID: bundleID, country: country) else { return }
        do {
            let (data, _) = try await session.data(from: url)
            guard let info = Self.parse(data) else { return }
            if Self.shouldPrompt(installed: installedVersion, store: info.version, dismissed: dismissedVersion) {
                availableVersion = info.version
                appStoreURL = URL(string: info.trackViewUrl)
            }
        } catch {
            Self.logger.debug("update check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// User chose "Later": stop nagging for this specific version.
    func dismiss() {
        if let v = availableVersion { dismissedVersion = v }
        availableVersion = nil
        appStoreURL = nil
    }

    // MARK: - Pure helpers (unit tested)

    nonisolated static func lookupURL(bundleID: String, country: String) -> URL? {
        var c = URLComponents(string: "https://itunes.apple.com/lookup")
        c?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleID),
            URLQueryItem(name: "country", value: country)
        ]
        return c?.url
    }

    nonisolated static func shouldPrompt(installed: String, store: String, dismissed: String) -> Bool {
        AppVersion.isNewer(store, than: installed) && store != dismissed
    }

    nonisolated static func parse(_ data: Data) -> StoreInfo? {
        struct Response: Decodable {
            struct Result: Decodable { let version: String; let trackViewUrl: String }
            let results: [Result]
        }
        guard let r = try? JSONDecoder().decode(Response.self, from: data),
              let first = r.results.first else { return nil }
        return StoreInfo(version: first.version, trackViewUrl: first.trackViewUrl)
    }
}
