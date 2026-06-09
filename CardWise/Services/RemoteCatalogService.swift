import Foundation
import os

/// Fetches the latest card catalog from GitHub and caches it on-device.
/// Backend-free and silent on failure: network/parse errors leave the existing
/// cache (and bundled fallback) untouched.
final class RemoteCatalogService {
    static let logger = Logger(subsystem: "com.cardwise.app", category: "RemoteCatalog")

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
}
