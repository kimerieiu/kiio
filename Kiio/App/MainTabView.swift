import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem { tabLabel(.home) }
            .tag(MainTab.home)

            NavigationStack {
                ChatView()
            }
            .tabItem { tabLabel(.chat) }
            .tag(MainTab.chat)

            NavigationStack {
                DeviceView()
            }
            .tabItem { tabLabel(.device) }
            .tag(MainTab.device)

            NavigationStack {
                ProfileView()
            }
            .tabItem { tabLabel(.profile) }
            .tag(MainTab.profile)
        }
        .background(KiioTheme.background)
    }

    private func tabLabel(_ tab: MainTab) -> some View {
        Label {
            Text(L10n.tr(tab.localizationKey, locale: appState.locale))
        } icon: {
            Image(tab.assetName)
                .renderingMode(.original)
        }
    }
}
