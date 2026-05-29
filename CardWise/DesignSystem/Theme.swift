import SwiftUI

/// Single source of truth for colors, type, spacing, radius, shadow.
/// All colors adapt to light/dark via dynamic UIColor providers.
enum Theme {
    // MARK: Color
    private static func dyn(_ light: UInt, _ dark: UInt) -> Color {
        Color(uiColor: UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }

    static let bg            = dyn(0xFAF8FD, 0x0E0E12)
    static let surface       = dyn(0xFFFFFF, 0x17171D)
    static let surfaceAlt    = dyn(0xF3EEF9, 0x20202A)
    static let accent        = dyn(0x7C3AED, 0x9B6BFF)
    static let accentSoftBG  = dyn(0x7C3AED, 0x9B6BFF) // use with .opacity(0.12/0.20)
    static let success       = dyn(0x16A34A, 0x34D27B)
    static let warning       = dyn(0xF59E0B, 0xFBBF24)
    static let danger        = dyn(0xF43F5E, 0xFB7185)
    static let textPrimary   = dyn(0x221B2B, 0xF2EFF7)
    static let textSecondary = dyn(0x8B7E98, 0x9A93A8)
    static let separator     = Color(uiColor: UIColor { tc in
        tc.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.10)
                                       : UIColor(rgb: 0x221B2B).withAlphaComponent(0.08)
    })

    static var heroGradient: LinearGradient {
        LinearGradient(colors: [Color(rgb: 0x7C3AED), Color(rgb: 0xA855F7)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func accentSoft(_ o: Double = 0.12) -> Color { accent.opacity(o) }

    // MARK: Metric
    enum Metric {
        static let fieldRadius: CGFloat = 14
        static let cardRadius: CGFloat = 20
        static let heroRadius: CGFloat = 24
        static let pad: CGFloat = 16
        static let gap: CGFloat = 16
    }

    // MARK: Shadow modifier
    struct SoftShadow: ViewModifier {
        func body(content: Content) -> some View {
            content.shadow(color: Color(rgb: 0x7C3AED).opacity(0.08), radius: 12, x: 0, y: 4)
        }
    }

    // MARK: Semantic helpers (migrated from HomeView)
    static func utilizationColor(_ pct: Double) -> Color {
        pct > 50 ? danger : (pct > 30 ? warning : success)
    }
    static func capColor(isAtCap: Bool, isNearCap: Bool) -> Color {
        isAtCap ? danger : (isNearCap ? warning : success)
    }
}

// MARK: - Helpers
extension Color {
    init(rgb: UInt) {
        self.init(.sRGB,
                  red:   Double((rgb >> 16) & 0xFF) / 255,
                  green: Double((rgb >> 8) & 0xFF) / 255,
                  blue:  Double(rgb & 0xFF) / 255)
    }
}
extension UIColor {
    convenience init(rgb: UInt) {
        self.init(red:   CGFloat((rgb >> 16) & 0xFF) / 255,
                  green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue:  CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Type (SF Rounded)
extension Font {
    static func app(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

extension View {
    func softShadow() -> some View { modifier(Theme.SoftShadow()) }
    func screenBackground() -> some View {
        background(Theme.bg.ignoresSafeArea())
    }
}
