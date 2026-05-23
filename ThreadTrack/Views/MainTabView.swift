import SwiftUI

// MARK: - MainTabView (Root Navigation)
struct MainTabView: View {
    @State private var selectedTab: Tab = .wardrobe

    enum Tab: Int, CaseIterable {
        case wardrobe = 0
        case today = 1
        case laundry = 2
        case stats = 3
        case settings = 4

        var title: String {
            switch self {
            case .wardrobe: return "Wardrobe"
            case .today: return "Today"
            case .laundry: return "Laundry"
            case .stats: return "Stats"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .wardrobe: return "tshirt"
            case .today: return "person.wear.2"
            case .laundry: return "washer.fill"
            case .stats: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .wardrobe) {
                WardrobeView()
            } label: {
                Label(Tab.wardrobe.title, systemImage: Tab.wardrobe.icon)
            }

            Tab(value: .today) {
                DailyPhotoView()
            } label: {
                Label(Tab.today.title, systemImage: Tab.today.icon)
            }

            Tab(value: .laundry) {
                LaundryView()
            } label: {
                Label(Tab.laundry.title, systemImage: Tab.laundry.icon)
            }

            Tab(value: .stats) {
                StatsView()
            } label: {
                Label(Tab.stats.title, systemImage: Tab.stats.icon)
            }

            Tab(value: .settings) {
                SettingsView()
            } label: {
                Label(Tab.settings.title, systemImage: Tab.settings.icon)
            }
        }
        .tint(TTColorTheme.accent)
    }
}
