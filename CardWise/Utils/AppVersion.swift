import Foundation

/// Small helper around the app's marketing version and semantic-version comparison.
/// Pure and side-effect free so it can be unit tested.
enum AppVersion {
    /// Current marketing version (CFBundleShortVersionString), e.g. "1.0.0".
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Compares two dotted version strings numerically, component by component.
    /// Missing components are treated as 0 ("1.2" == "1.2.0"); non-numeric junk in a
    /// component is truncated ("1.2-beta" -> 1.2).
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let l = parts(lhs), r = parts(rhs)
        for i in 0..<max(l.count, r.count) {
            let a = i < l.count ? l[i] : 0
            let b = i < r.count ? r[i] : 0
            if a != b { return a < b ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }

    /// True when `candidate` is a strictly higher version than `reference`.
    static func isNewer(_ candidate: String, than reference: String) -> Bool {
        compare(candidate, reference) == .orderedDescending
    }

    private static func parts(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0.prefix { $0.isNumber }) ?? 0 }
    }
}
