import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label(L10n.tr(MainTab.home.localizationKey, locale: appState.locale), systemImage: MainTab.home.systemImage) }
            .tag(MainTab.home)

            NavigationStack {
                ChatView()
            }
            .tabItem { Label(L10n.tr(MainTab.chat.localizationKey, locale: appState.locale), systemImage: MainTab.chat.systemImage) }
            .tag(MainTab.chat)

            NavigationStack {
                DeviceView()
            }
            .tabItem { Label(L10n.tr(MainTab.device.localizationKey, locale: appState.locale), systemImage: MainTab.device.systemImage) }
            .tag(MainTab.device)

            NavigationStack {
                ProfileView()
            }
            .tabItem { Label(L10n.tr(MainTab.profile.localizationKey, locale: appState.locale), systemImage: MainTab.profile.systemImage) }
            .tag(MainTab.profile)
        }
        .background(KiioTheme.background)
    }
}
