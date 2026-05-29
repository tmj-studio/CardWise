# UI/UX Redesign — "Polished Playful" Design Spec

**Date:** 2026-05-29
**Status:** Draft for review
**Scope:** Full visual overhaul of the iOS app. No business-logic / data-model changes.
**Related:** A separate spec covers the project rename/rebrand. The brand name chosen here feeds that effort.

---

## 1. Goal & Motivation

The current UI is generic and unpolished — system fonts, gray `systemGray6` containers, default blue tint, default tab bar, no visual identity. The user wants a **big overhaul** ("大改版", "現在 uiux 太醜了").

After comparing four directions in the visual companion, the user chose the **playful & friendly** family, specifically a blend of **B1 (soft & polished)** and **B2 (vibrant)**. The agreed direction is named **"Polished Playful"**:

- B1's restraint as the **baseline** — friendly copy, soft shadows, no emoji clutter, grown-up enough for a money app.
- B2's energy reserved for **hero moments** — a gradient "This Month" summary card, a warm greeting header.
- **Violet** primary accent (`#7C3AED`), green for rewards, rose for alerts.
- **SF Rounded** type system (friendly, built-in, full Dynamic Type support — no font bundling required).

## 2. Design Principles

1. **One accent, used with intent.** Violet signals "primary / yours / best." Don't paint everything violet.
2. **Soft, not flat; not skeuomorphic.** Rounded corners (16–22), gentle violet-tinted shadows, generous padding.
3. **Hierarchy through type weight + size,** not boxes-within-boxes. Fewer nested gray containers.
4. **Friendly, human copy.** "Let's find your best card" over "Recommend."
5. **Reward = green, missed/over = rose, neutral = ink.** Consistent semantic color everywhere.
6. **Light & dark both first-class.** All tokens adapt.
7. **Accessibility:** Dynamic Type respected, contrast ≥ WCAG AA, tap targets ≥ 44pt.

## 3. Brand Name (to confirm)

The name should fall out of this identity (friendly, rewards-focused, violet). Candidates, recommendation first:

- **Perk** *(recommended)* — literally means a reward/benefit; short, warm, brandable. App display name "Perk", later rename of repo/targets to match.
- **Plum** — violet fruit + "a plum deal"; friendly (note: a UK fintech uses this — possible confusion).
- **Kudo** — reward/praise, playful.
- **Maxa** — from "maximize your rewards."

**Decision needed from user before the rename task.** The redesign itself does not block on the final name — we use a `Theme`/`Brand` constant for the display name so it changes in one place.

## 4. Design Tokens — `Theme.swift` (new)

A single source of truth under `SmartCard/DesignSystem/`. All adaptive (light/dark) via `UIColor { trait in … }` dynamic providers wrapped as `Color`.

### Color

| Token | Light | Dark | Use |
|---|---|---|---|
| `Theme.bg` | `#FAF8FD` | `#0E0E12` | screen background |
| `Theme.surface` | `#FFFFFF` | `#17171D` | cards, fields |
| `Theme.surfaceAlt` | `#F3EEF9` | `#20202A` | subtle fills, tracks |
| `Theme.accent` | `#7C3AED` | `#9B6BFF` | primary / brand |
| `Theme.accentSoft` | `#7C3AED@12%` | `#9B6BFF@20%` | tints, selected states |
| `Theme.heroGradient` | `#7C3AED → #A855F7` | same | hero stat card, key CTAs |
| `Theme.success` | `#16A34A` | `#34D27B` | rewards earned |
| `Theme.warning` | `#F59E0B` | `#FBBF24` | near cap |
| `Theme.danger` | `#F43F5E` | `#FB7185` | missed / over cap |
| `Theme.textPrimary` | `#221B2B` | `#F2EFF7` | headings/body |
| `Theme.textSecondary` | `#8B7E98` | `#9A93A8` | captions |
| `Theme.separator` | `#221B2B@8%` | `#FFFFFF@10%` | hairlines |

Semantic helpers map existing usage: `.utilizationColor(pct)`, `.capColor(state)` move here.

### Typography — `Theme.Font`

Base design = `.rounded`. Scales off SwiftUI text styles so Dynamic Type works.

| Token | Spec | Use |
|---|---|---|
| `display` | `.largeTitle`, weight `.bold`, rounded | screen greeting/hero numbers |
| `title` | `.title2`, `.bold`, rounded | section/card titles |
| `headline` | `.headline`, `.semibold`, rounded | row primary text |
| `body` | `.body`, rounded | body |
| `caption` | `.caption`, rounded | secondary |
| `mono` | `.body`, `.semibold`, rounded, monospacedDigit | currency figures |

(Plus Jakarta Sans is a possible future swap for headings; out of scope now to avoid font bundling.)

### Spacing, Radius, Shadow — `Theme.Metric`

- Spacing scale: `4, 8, 12, 16, 20, 24, 32`.
- Radius: `field = 14`, `card = 20`, `hero = 24`, `pill = capsule`.
- Shadow: `Theme.softShadow` = violet `#7C3AED@8%`, radius 12, y 4. Dark mode: black @ 30%.

## 5. Component Library — `SmartCard/DesignSystem/Components/` (new)

Reusable so screens shrink and stay consistent:

1. **`SectionCard`** — white `surface`, radius 20, padding 16, `softShadow`. Replaces every `.background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))`.
2. **`HeroStatCard`** — `heroGradient` background, white text, 3 stat columns. Used for "This Month."
3. **`StatColumn`** — label + monospaced value, semantic color.
4. **`AppSearchField`** — rounded `surface` field, leading magnifier, trailing slot, soft shadow. Replaces the 3 duplicated search bars (Home/Recommend/QuickRecommend).
5. **`PrimaryButton`** / **`SoftButton`** — gradient pill primary; tinted (`accentSoft`) secondary. Replaces ad-hoc `Color.blue.opacity(0.1)` buttons.
6. **`ProgressBar`** — rounded track + fill, semantic color, animatable. Replaces the repeated `GeometryReader` bars.
7. **`RankBadge`** — circular rank number; `#1` uses `heroGradient`.
8. **`RewardBadge`** — large reward multiplier ("2%", "3x") with success/accent emphasis.
9. **`CategoryChip`** — pill for categories (picker + detected-category banner).
10. **`AppEmptyState`** — wraps `ContentUnavailableView` with themed icon in `accentSoft` circle.
11. **`CardArt`** — refines existing `CardImageView` (consistent corner radius, subtle shadow, gloss).

A `View` extension `.sectionCard()` / `.screenBackground()` keeps call sites terse.

## 6. Navigation / Tab Bar

- Keep 5 tabs (Home, Cards, Recommend, Spending, Settings) — labels reworded where friendlier ("Best" for Recommend is optional; keep "Recommend" for clarity).
- `MainTabView` tint → `Theme.accent`. Apply themed `UITabBarAppearance` (translucent, hairline top, violet selected item) in an app-start appearance configurator.
- Themed `UINavigationBarAppearance`: rounded bold large titles, `Theme.bg` background, no harsh shadow line.

## 7. Per-Screen Redesign

Logic untouched; only presentation. Screens:

- **Home (`HomeView`)** — Add greeting header ("Good evening" + "Let's find your best card") replacing the plain "Dashboard" nav title content. `QuickSearchBar` → `AppSearchField`. All four cards → `SectionCard`. `MonthlySummaryCard` → `HeroStatCard` (gradient). Progress bars → `ProgressBar`. Collapsible chevrons restyled.
- **My Cards (`CardListView`)** — Card rows become richer `CardArt` + `SectionCard` list; add/empty states themed. (Read file during planning.)
- **Recommend (`RecommendView`)** — `AppSearchField`, themed autocomplete dropdown, detected-category → `CategoryChip` banner, results list rows → `SectionCard` with `RankBadge` + `RewardBadge`; top result highlighted with `accentSoft` + gradient rank. `CategoryPickerView` grid → `CategoryChip`s with violet selection.
- **Spending (`SpendingListView`, `SpendingChartsView`, `ScanReceiptView`)** — themed list rows, charts recolored to violet/green/rose palette, segmented controls tinted.
- **Settings (`SettingsView`, `LinkBankView`, `LegalView`)** — themed grouped sections, violet accents, Pro/upsell row uses gradient.
- **Paywall (`PaywallView`)** — strongest hero moment: `heroGradient` header, feature checklist with violet checks, `PrimaryButton` CTA.
- **Auth (`AuthView`)**, **Onboarding (`OnboardingView`)**, **LaunchScreen** — themed: violet brand mark, rounded type, gradient accents. Launch screen shows brand name/logo.

Each screen is its own implementation step; planning will read each file before editing.

## 8. Out of Scope (Non-Goals)

- No changes to models, view models, services, recommendation logic, Firebase, StoreKit behavior.
- No new features or screens.
- The repo/target/bundle-id **rename** is a separate spec + plan (this one only picks the name and routes the display name through `Brand`).
- Custom font bundling (Plus Jakarta) — deferred; SF Rounded now.
- Reordering or adding tabs.

## 9. Risks & Mitigations

- **Scope creep across ~13 screens.** → Build tokens + components first; refactor screens one-by-one, each independently buildable.
- **Dark mode regressions.** → All tokens adaptive from day one; verify both appearances per screen.
- **Hard-coded colors missed.** → Grep sweep for `systemGray`, `.blue`, `Color.green/red/orange`, `cornerRadius:` after refactor; none should remain in Views.
- **Dynamic Type / layout breakage.** → Use text styles (not fixed sizes); test at XL.

## 10. Verification

- App builds for iOS simulator (`xcodebuild`/Xcode), no warnings introduced by new files.
- Existing tests still pass (`SmartCardTests` — logic untouched).
- Manual: launch in simulator, walk every tab in light + dark, confirm: violet tint, gradient hero card, themed cards/search/buttons, no leftover gray `systemGray6` blocks, no clipped text at large Dynamic Type.
- Before/after screenshots of Home, Recommend, Cards, Spending.

## 11. Build Order (feeds the implementation plan)

1. `Theme.swift` (tokens) + appearance configurator.
2. Component library (`SectionCard`, `AppSearchField`, `HeroStatCard`, `ProgressBar`, `PrimaryButton`, `RankBadge`, `RewardBadge`, `CategoryChip`, `AppEmptyState`).
3. `MainTabView` + nav/tab appearance.
4. Home.
5. Recommend (+ CategoryPicker).
6. My Cards.
7. Spending (list, charts, scan).
8. Settings (+ LinkBank, Legal).
9. Paywall.
10. Auth, Onboarding, LaunchScreen.
11. Grep sweep + dark-mode pass + screenshots.
