import SwiftUI

struct RootTabView: View {
    @AppStorage(GLPStorageKey.appearance.rawValue, store: GLPAppGroup.userDefaults) private var appearanceRaw = AppAppearance.system.rawValue

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("One Tap", systemImage: "syringe.fill") }

            NavigationStack { LogHubView() }
                .tabItem { Label("Optional", systemImage: "plus.circle") }

            NavigationStack { HistoryView() }
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NavigationStack { InsightsView() }
                .tabItem { Label("Patterns", systemImage: "chart.bar.xaxis") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(AppTheme.brand)
        .preferredColorScheme(AppAppearance.from(storageValue: appearanceRaw).preferredColorScheme)
    }
}
