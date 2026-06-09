import Foundation
import os

/// Fetches the latest card catalog from GitHub and caches it on-device.
/// Backend-free and silent on failure: network/parse errors leave the existing
/// cache (and bundled fallback) untouched.
final class RemoteCatalogService {
    private static let logger = Logger(subsystem: "com.cardwise.app", category: "RemoteCatalog")

    static let remoteURL = URL(string:
        "https://raw.githubusercontent.com/tmj-studio/CardWise/main/CardWise/Resources/cards.json")!

    /// Cached remote catalog location (Application Support).
    static var defaultCacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("cards-remote.json")
    }

    enum RefreshDecision: Equatable {
        case write(version: Int)
        case skip
    }

    private let url: URL
    private let session: URLSession
    private let cacheURL: URL

    init(url: URL = RemoteCatalogService.remoteURL,
         session: URLSession = .shared,
         cacheURL: URL = RemoteCatalogService.defaultCacheURL) {
        self.url = url
        self.session = session
        self.cacheURL = cacheURL
    }

    // MARK: - Pure helpers (unit tested)

    static func isValid(_ file: CardCatalogFile) -> Bool {
        !file.cards.isEmpty && file.cards.allSatisfy { !$0.id.isEmpty && !$0.name.isEmpty }
    }

    static func decide(fetched: Data, currentVersion: Int) -> RefreshDecision {
        guard let file = CardCatalog.decodeFile(from: fetched),
              isValid(file),
              file.version > currentVersion else { return .skip }
        return .write(version: file.version)
    }

    // MARK: - Side-effecting methods

    /// Writes the fetched bytes to the cache only if `decide` approves them.
    func writeIfNeeded(fetched: Data, currentVersion: Int) {
        guard case .write = Self.decide(fetched: fetched, currentVersion: currentVersion) else { return }
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fetched.write(to: cacheURL, options: .atomic)
        } catch {
            Self.logger.debug("catalog cache write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Fetches the latest catalog and updates the cache for the next launch.
    /// Silent on any failure.
    func refresh() async {
        do {
            let (data, response) = try await session.data(from: url)
            // Accept only a confirmed 200; anything else (3xx/4xx/5xx or a non-HTTP
            // response) is treated as "no fresh data" and leaves the cache untouched.
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode.description ?? "non-HTTP"
                Self.logger.debug("catalog refresh skipped: HTTP \(code, privacy: .public)")
                return
            }
            writeIfNeeded(fetched: data, currentVersion: CardCatalog.currentVersion(cacheURL: cacheURL))
        } catch {
            Self.logger.debug("catalog refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
