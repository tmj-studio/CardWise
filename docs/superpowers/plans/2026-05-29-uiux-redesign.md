# UI/UX Redesign ("Polished Playful") — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the entire app onto a cohesive "Polished Playful" design system (violet accent, SF Rounded, soft cards, gradient hero moments, full light/dark) without changing any business logic.

**Architecture:** Introduce a `DesignSystem/` layer — `Theme` tokens + `Brand` + a reusable component library + app-wide nav/tab appearance — then refactor each screen onto it. Logic, models, view models, and services are untouched; only `View` presentation changes.

**Tech Stack:** SwiftUI, iOS 17, SF Rounded system font, `UIColor` dynamic providers for adaptive color.

**Assumes:** the rename plan has run, so paths are `CardWise/...` and `Brand.displayName == "CardWise"`. If running this BEFORE the rename, substitute `SmartCard/` for `CardWise/` in every path below.

**Verification model:** This is visual work — "tests" are *build succeeds* + *visual confirmation in the simulator in light AND dark*. There are no XCTest assertions for appearance. Existing logic tests must keep passing.

---

### Task 0: Branch

- [ ] **Step 1:** `git checkout -b feature/uiux-redesign`
- [ ] **Step 2:** Confirm clean build:
`xcodebuild -project CardWise.xcodeproj -scheme CardWise -destination 'generic/platform=iOS Simulator' -quiet build CODE_SIGNING_ALLOWED=NO 2>&1 | tail -3` → `** BUILD SUCCEEDED **`

---

### Task 1: Theme tokens + Brand

**Files:** Create `CardWise/DesignSystem/Theme.swift`, `CardWise/DesignSystem/Brand.swift`

- [ ] **Step 1: Create `Brand.swift`**

```swift
import Foundation

enum Brand {
    static let displayName = "CardWise"
    static let tagline = "Find your best card."
}
```

- [ ] **Step 2: Create `Theme.swift`**

```swift
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
```

- [ ] **Step 3: Build** (the project auto-includes new files in `CardWise/` via XcodeGen path globs — regenerate if needed: `xcodegen generate`).
Run build command from Task 0 Step 2. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit** `git add -A && git commit -m "feat(design): add Theme tokens and Brand constants"`

---

### Task 2: Core components — SectionCard, AppSearchField, ProgressBar

**Files:** Create `CardWise/DesignSystem/Components/SectionCard.swift`, `AppSearchField.swift`, `AppProgressBar.swift`

- [ ] **Step 1: `SectionCard.swift`**

```swift
import SwiftUI

struct SectionCard<Content: View>: View {
    var padding: CGFloat = Theme.Metric.pad
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
            .softShadow()
    }
}

extension View {
    func sectionCard(padding: CGFloat = Theme.Metric.pad) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.cardRadius, style: .continuous))
            .softShadow()
    }
}
```

- [ ] **Step 2: `AppSearchField.swift`** — a tappable/edit field with leading magnifier and optional trailing slot. Provide BOTH a button variant (Home) and a TextField variant (Recommend).

```swift
import SwiftUI

/// Tappable search bar that opens a sheet (Home dashboard).
struct SearchBarButton: View {
    let placeholder: String
    var text: String = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                Text(text.isEmpty ? placeholder : text)
                    .foregroundStyle(text.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                Spacer()
                Image(systemName: "creditcard.fill").foregroundStyle(Theme.accent)
            }
            .font(.app(.body))
            .padding(14)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
            .softShadow()
        }
        .buttonStyle(.plain)
    }
}

/// Editable search field (Recommend / QuickRecommend).
struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .focused(focused)
                .autocorrectionDisabled()
                .font(.app(.body))
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.fieldRadius, style: .continuous))
        .softShadow()
    }
}
```

- [ ] **Step 3: `AppProgressBar.swift`**

```swift
import SwiftUI

struct AppProgressBar: View {
    var value: Double          // 0...1
    var color: Color
    var height: CGFloat = 8
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
    }
}
```

- [ ] **Step 4: Build + commit** `git commit -am "feat(design): SectionCard, search fields, progress bar"`

---

### Task 3: Hero, buttons, badges, chips, empty state

**Files:** Create `CardWise/DesignSystem/Components/HeroStatCard.swift`, `AppButtons.swift`, `Badges.swift`, `CategoryChip.swift`, `AppEmptyState.swift`

- [ ] **Step 1: `HeroStatCard.swift`**

```swift
import SwiftUI

struct StatColumn: View {
    let title: String, value: String, tint: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.app(.title3, weight: .bold)).monospacedDigit().foregroundStyle(tint)
            Text(title).font(.app(.caption)).foregroundStyle(.white.opacity(0.85))
        }.frame(maxWidth: .infinity)
    }
}

struct HeroStatCard: View {
    let title: String
    let columns: [(title: String, value: String, tint: Color)]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.app(.subheadline, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, c in
                    StatColumn(title: c.title, value: c.value, tint: c.tint)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metric.heroRadius, style: .continuous))
        .softShadow()
    }
}
```
(For "This Month": rewards column tint `.white`, others `.white`; emphasize via value only — keep contrast on gradient. Spent=white, Rewards=`Color(rgb:0xBBF7D0)`, Missed=`Color(rgb:0xFECDD3)`.)

- [ ] **Step 2: `AppButtons.swift`** — gradient primary + soft secondary as `ButtonStyle`s.

```swift
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.heroGradient)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(.headline, weight: .semibold))
            .foregroundStyle(Theme.accent)
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Theme.accentSoft())
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
```

- [ ] **Step 3: `Badges.swift`** — `RankBadge` (circular, #1 = gradient) and `RewardBadge` (big multiplier).

```swift
import SwiftUI

struct RankBadge: View {
    let rank: Int
    var isTop: Bool { rank == 1 }
    var body: some View {
        Text("\(rank)")
            .font(.app(.headline, weight: .bold))
            .foregroundStyle(isTop ? .white : Theme.textPrimary)
            .frame(width: 32, height: 32)
            .background(isTop ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Theme.surfaceAlt))
            .clipShape(Circle())
    }
}

struct RewardBadge: View {
    let text: String          // "2%" / "3x"
    var emphasized: Bool
    var body: some View {
        Text(text)
            .font(.app(.title2, weight: .bold)).monospacedDigit()
            .foregroundStyle(emphasized ? Theme.success : Theme.textPrimary)
    }
}
```

- [ ] **Step 4: `CategoryChip.swift`**

```swift
import SwiftUI

struct CategoryChip: View {
    let icon: String, title: String
    var selected: Bool = false
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.app(.subheadline, weight: .medium))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .foregroundStyle(selected ? Theme.accent : Theme.textPrimary)
        .background(selected ? Theme.accentSoft() : Theme.surfaceAlt)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(selected ? Theme.accent : .clear, lineWidth: 1.5))
    }
}
```

- [ ] **Step 5: `AppEmptyState.swift`**

```swift
import SwiftUI

struct AppEmptyState: View {
    let icon: String, title: String, message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 30))
                .foregroundStyle(Theme.accent)
                .frame(width: 72, height: 72)
                .background(Theme.accentSoft()).clipShape(Circle())
            Text(title).font(.app(.title3, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text(message).font(.app(.subheadline)).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }.padding(32)
    }
}
```

- [ ] **Step 6: Build + commit** `git commit -am "feat(design): hero card, buttons, badges, chip, empty state"`

---

### Task 4: App-wide appearance (tab bar + nav bar)

**Files:** Modify `CardWise/Views/MainTabView.swift`; create `CardWise/DesignSystem/AppAppearance.swift`

- [ ] **Step 1: `AppAppearance.swift`** — configure `UITabBarAppearance` / `UINavigationBarAppearance` with `Theme.accent` selected color, `Theme.bg`, rounded large-title font, subtle separators. Call from app init.

```swift
import UIKit

enum AppAppearance {
    static func apply() {
        let accent = UIColor(rgb: 0x7C3AED)

        let tab = UITabBarAppearance(); tab.configureWithDefaultBackground()
        tab.stackedLayoutAppearance.selected.iconColor = accent
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance(); nav.configureWithDefaultBackground()
        if let rounded = UIFont(descriptor: UIFont.systemFont(ofSize: 34, weight: .bold)
            .fontDescriptor.withDesign(.rounded)!, size: 34) {
            nav.largeTitleTextAttributes = [.font: rounded]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}
```

- [ ] **Step 2: Call `AppAppearance.apply()`** in `CardWiseApp.init()`.
- [ ] **Step 3: `MainTabView`** — change `.tint(.blue)` → `.tint(Theme.accent)`.
- [ ] **Step 4: Build, run simulator, confirm violet tab tint in light+dark. Commit** `git commit -am "feat(design): themed tab/nav bar appearance"`

---

### Task 5: Home redesign

**Files:** Modify `CardWise/Views/Home/HomeView.swift`

- [ ] **Step 1:** Wrap `ScrollView` content in `.screenBackground()`. Replace the plain `.navigationTitle("Dashboard")` presentation with a greeting header view at top of the stack: `Text(greeting).font(.app(.largeTitle, weight: .bold))` + `Text("Let's find your best card").font(.app(.subheadline)).foregroundStyle(Theme.textSecondary)` where `greeting` is time-of-day based. Keep a `.navigationBarTitleDisplayMode(.inline)` empty title or hide.
- [ ] **Step 2:** `QuickSearchBar` → use `SearchBarButton(placeholder: "What are you buying?", text: searchText) { showingQuickRecommend = true }`.
- [ ] **Step 3:** `CreditUtilizationCard`, `SpendingCapsCard`, `RecentTransactionsCard`: replace `.padding().background(Color(.systemGray6)).clipShape(...)` with `.sectionCard()`. Replace inline progress `GeometryReader` bars with `AppProgressBar(value: pct/100, color: Theme.capColor(...))`. Replace `.secondary`/`.blue`/`.green`/`.red` with `Theme.textSecondary`/`accent`/`success`/`danger`. Fonts → `.app(...)`.
- [ ] **Step 4:** `MonthlySummaryCard` → render with `HeroStatCard(title: "This Month", columns: [("Spent", spent, .white), ("Rewards", rewards, Color(rgb:0xBBF7D0)), ("Missed", missed, Color(rgb:0xFECDD3))])`.
- [ ] **Step 5:** `CollapsibleHeader` chevron tint → `Theme.textSecondary`; title font `.app(.headline, weight: .semibold)`.
- [ ] **Step 6: Build, run, visually confirm Home in light+dark.** Commit `git commit -am "feat(design): redesign Home dashboard"`

---

### Task 6: Recommend redesign (+ CategoryPicker)

**Files:** Modify `CardWise/Views/Recommend/RecommendView.swift`

- [ ] **Step 1:** Top input section: `.screenBackground()`; search → `AppSearchField`. Themed autocomplete/history dropdowns: `Theme.surface` bg, `.softShadow()`, `Theme.separator` dividers, `.app(...)` fonts.
- [ ] **Step 2:** Detected-category banner → `CategoryChip(icon:title:selected:true)` inside a row with a `checkmark.circle.fill` in `Theme.success`. Manual-pick button → `CategoryChip` styled control.
- [ ] **Step 3:** Amount row → themed: label `.app(.body)`, field background `Theme.surfaceAlt`, radius `fieldRadius`.
- [ ] **Step 4:** `RecommendationDetailRow` → `RankBadge(rank:)`, `CardArt`, name `.app(.headline)`, issuer `.app(.caption)` secondary, reason secondary, reward via `RewardBadge(text: displayReward, emphasized: isTop)`. Top row container tint `Theme.accentSoft()` (replace `Color.green.opacity(0.1)` list row bg). Use `.listRowBackground` + `.listRowSeparatorTint(Theme.separator)`; or move to `ScrollView` of `.sectionCard()` rows for full control.
- [ ] **Step 5:** Empty states → `AppEmptyState`.
- [ ] **Step 6:** `CategoryPickerView` grid → `CategoryChip`s (selected = violet) on `.screenBackground()`.
- [ ] **Step 7: Build, run, confirm light+dark.** Commit `git commit -am "feat(design): redesign Recommend + category picker"`

---

### Task 7: QuickRecommend sheet (Home sheet)

**Files:** Modify `CardWise/Views/Home/HomeView.swift` (`QuickRecommendSheet`, `QuickRecommendRow`)

- [ ] **Step 1:** Search → `AppSearchField`; dropdowns themed as Task 6.1; detected-category → `CategoryChip`.
- [ ] **Step 2:** `QuickRecommendRow` → `CardArt`, `RewardBadge`, top highlight `Theme.accentSoft()`; "Add this spending" button → `.buttonStyle(SoftButtonStyle())`.
- [ ] **Step 3: Build, run sheet, confirm.** Commit `git commit -am "feat(design): redesign QuickRecommend sheet"`

---

### Task 8: My Cards redesign

**Files:** Read then modify `CardWise/Views/Cards/CardListView.swift` (read fully before editing — not yet inspected).

- [ ] **Step 1:** Read the file; inventory every `systemGray*`, `.blue/.green/.red`, `cornerRadius:`, font usage.
- [ ] **Step 2:** Screen bg → `.screenBackground()`. Card rows → `.sectionCard()` with `CardArt`, `.app(...)` type, `Theme` colors. Add/empty states → `PrimaryButton`/`AppEmptyState`. Reward/category detail rows use `RewardBadge`/`CategoryChip` where shown.
- [ ] **Step 3: Build, run, confirm light+dark.** Commit `git commit -am "feat(design): redesign My Cards"`

---

### Task 9: Spending redesign (list, charts, scan)

**Files:** Read then modify `CardWise/Views/Spending/SpendingListView.swift`, `SpendingChartsView.swift`, `ScanReceiptView.swift`

- [ ] **Step 1:** Read all three; inventory color/spacing usage.
- [ ] **Step 2:** List rows → themed (category icon in `Theme.accentSoft()` circle, amount `.app` mono, reward in `Theme.success`). Screen bg `.screenBackground()`. Segmented controls/pickers `.tint(Theme.accent)`.
- [ ] **Step 3:** Charts: recolor series to `[Theme.accent, Theme.success, Theme.warning, Theme.danger, ...]` palette; axis/labels `Theme.textSecondary`.
- [ ] **Step 4:** ScanReceipt: themed capture/confirm UI, `PrimaryButton` actions, `AppEmptyState` for no-image.
- [ ] **Step 5: Build, run, confirm light+dark.** Commit `git commit -am "feat(design): redesign Spending list, charts, scan"`

---

### Task 10: Settings redesign (+ LinkBank, Legal)

**Files:** Read then modify `CardWise/Views/Settings/SettingsView.swift`, `LinkBankView.swift`, `LegalView.swift`

- [ ] **Step 1:** Read all three.
- [ ] **Step 2:** Grouped sections themed; row icons in `Theme.accentSoft()` tiles; `.tint(Theme.accent)`. The Pro/upsell row → gradient (`Theme.heroGradient`) banner linking to Paywall. LinkBank CTA → `PrimaryButton`. Legal text uses `.app(.body)` + `Theme.textPrimary`.
- [ ] **Step 3:** Replace user-facing "SmartCard" strings already handled by rename — verify they read `Brand.displayName`.
- [ ] **Step 4: Build, run, confirm.** Commit `git commit -am "feat(design): redesign Settings, LinkBank, Legal"`

---

### Task 11: Paywall redesign (signature moment)

**Files:** Modify `CardWise/Views/Paywall/PaywallView.swift`

- [ ] **Step 1:** Hero header on `Theme.heroGradient` with `Brand.displayName` + value prop. Feature list rows: `checkmark.seal.fill` in `Theme.accent`, `.app(.body)`. Price/CTA → `PrimaryButton`; secondary ("Restore") → `SoftButtonStyle` or plain. Background `.screenBackground()`.
- [ ] **Step 2: Build, run, confirm light+dark + Dynamic Type XL.** Commit `git commit -am "feat(design): redesign Paywall"`

---

### Task 12: Auth, Onboarding, LaunchScreen

**Files:** Read then modify `CardWise/Views/Auth/AuthView.swift`, `CardWise/Views/Onboarding/OnboardingView.swift`, `CardWise/Views/LaunchScreen.swift`

- [ ] **Step 1:** Read all three.
- [ ] **Step 2:** LaunchScreen: centered `Brand.displayName` wordmark in `.app(.largeTitle, weight: .bold)`, `Theme.accent`, on `Theme.bg`; optional gradient mark. Onboarding: page indicators `Theme.accent`, `PrimaryButton` next/finish, illustrations tinted violet. Auth: `PrimaryButton` sign-in, themed fields, `Brand.displayName` heading.
- [ ] **Step 3: Build, run flows, confirm.** Commit `git commit -am "feat(design): redesign Auth, Onboarding, LaunchScreen"`

---

### Task 13: Sweep, dark-mode pass, screenshots

- [ ] **Step 1: Grep sweep for leftover hard-coded styling in Views**

Run:
```bash
grep -rn "systemGray\|Color(.system\|\.tint(.blue)\|Color.blue\|Color.green\|Color.red\|Color.orange\|cornerRadius: 12" CardWise/Views
```
Expected: no styling leftovers (semantic uses must route through `Theme`). Fix any remaining; allow intentional exceptions only with a comment.

- [ ] **Step 2: Full build + tests**
`xcodebuild ... build` and `... test` → both green.

- [ ] **Step 3: Dark-mode walkthrough** — run simulator, toggle Appearance, walk every tab + Paywall + Onboarding; confirm contrast and no white-on-white / black-on-black.

- [ ] **Step 4: Regenerate marketing screenshots** — run `Scripts/take_screenshots*.sh` (or capture Home/Recommend/Cards/Spending) and replace files in `Screenshots/`.

- [ ] **Step 5: Commit + open PR**
```bash
git add -A && git commit -m "chore(design): style sweep, dark-mode fixes, refreshed screenshots"
gh pr create --title "UI/UX redesign: Polished Playful" --fill
```

---

## Self-Review

- **Spec coverage:** tokens (T1) ✓, components (T2–T3) ✓ map to spec §5 list, appearance (T4) ✓ §6, all screens in spec §7 covered T5–T12 ✓, sweep/verify (T13) ✓ §9–§10.
- **Type consistency:** `Theme.accent`, `Theme.heroGradient`, `.app(_:weight:)`, `.sectionCard()`, `SearchBarButton`/`AppSearchField`, `AppProgressBar`, `HeroStatCard`, `RankBadge`/`RewardBadge`, `CategoryChip`, `AppEmptyState`, `PrimaryButtonStyle`/`SoftButtonStyle`, `Brand.displayName` — names used identically across tasks.
- **No fabricated tests:** visual work verified by build + simulator per task; logic tests must stay green (T13.2).
- **Unread files flagged:** CardList, Spending×3, Settings×3, Auth, Onboarding, LaunchScreen tasks begin with an explicit "read the file" step.
- **Placeholder scan:** foundation tasks (T1–T4) carry complete code; screen tasks specify exact substitutions against known current code, with read-first steps for uninspected files.
```
