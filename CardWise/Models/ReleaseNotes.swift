import Foundation

/// A single version's user-facing release notes, bundled in the app.
struct ReleaseNote: Identifiable, Equatable {
    let version: String
    let highlights: [String]
    var id: String { version }
}

/// Bundled "What's New" content. Edit `all` each release (newest first).
enum ReleaseNotes {
    static let all: [ReleaseNote] = [
        ReleaseNote(version: "1.0.0", highlights: [
            "Welcome to CardWise — find the best card for every purchase.",
            "Add your cards and get instant recommendations by merchant.",
            "Track your spending and the rewards you actually earn."
        ])
    ]

    static func note(for version: String) -> ReleaseNote? {
        all.first { $0.version == version }
    }

    /// The most recent note (used by the Settings "What's New" entry).
    static var latest: ReleaseNote? { all.first }
}

/// Decides which release notes to surface on launch. Pure so it can be unit tested.
enum WhatsNew {
    /// Notes for versions in the half-open-then-closed range `(lastSeen, current]`.
    /// Returns `[]` for fresh installs (empty `lastSeen`) or when the app has not been upgraded.
    static func notesToPresent(lastSeen: String, current: String) -> [ReleaseNote] {
        guard !lastSeen.isEmpty, AppVersion.isNewer(current, than: lastSeen) else { return [] }
        return ReleaseNotes.all.filter {
            AppVersion.isNewer($0.version, than: lastSeen) &&
            AppVersion.compare($0.version, current) != .orderedDescending
        }
    }
}
