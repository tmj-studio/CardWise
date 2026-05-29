import UIKit

enum AppAppearance {
    static func apply() {
        let accent = UIColor(rgb: 0x7C3AED)

        // MARK: Tab Bar
        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.stackedLayoutAppearance.selected.iconColor = accent
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // MARK: Navigation Bar
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        let baseFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        if let desc = baseFont.fontDescriptor.withDesign(.rounded) {
            nav.largeTitleTextAttributes = [.font: UIFont(descriptor: desc, size: 34)]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
    }
}
