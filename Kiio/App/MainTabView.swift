import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack {
                HomeView()
                    .kiioShowsTabBar()
            }
            .tabItem { tabLabel(.home) }
            .tag(MainTab.home)

            NavigationStack {
                ChatView()
                    .kiioShowsTabBar()
            }
            .tabItem { tabLabel(.chat) }
            .tag(MainTab.chat)

            NavigationStack {
                DeviceView()
                    .kiioShowsTabBar()
            }
            .tabItem { tabLabel(.device) }
            .tag(MainTab.device)

            NavigationStack {
                ProfileView()
                    .kiioShowsTabBar()
            }
            .tabItem { tabLabel(.profile) }
            .tag(MainTab.profile)
        }
        .background(KiioTheme.background)
        .background(KiioTabSwitchAnimator().frame(width: 0, height: 0))
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
