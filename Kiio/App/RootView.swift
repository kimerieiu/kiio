import SwiftUI

struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    var body: some View {
        Group {
            switch appState.rootRoute {
            case .splash:
                SplashView()
                    .task {
                        try? await Task.sleep(nanoseconds: 1_800_000_000)
                        appState.finishSplash(isAuthenticated: authStore.isAuthenticated)
                    }
            case .language:
                LanguageSelectionView()
            case .welcome:
                WelcomeView()
            case .auth:
                AuthView()
            case .invite:
                InviteView()
                    .task {
                        await loadAuthenticatedContext()
                    }
            case .main:
                MainTabView()
                    .task {
                        await loadAuthenticatedContext()
                    }
            }
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .onChange(of: authStore.isAuthenticated) { isAuthenticated in
            if !isAuthenticated {
                dependencies.notifyWebSocketClient.disconnect()
                dependencies.syncStore.reset()
                bootstrapStore.reset()
                if appState.rootRoute == .main || appState.rootRoute == .invite {
                    appState.showAuth()
                }
            }
        }
    }

    private func loadAuthenticatedContext() async {
        await bootstrapStore.ensureLoaded()
        if let language = bootstrapStore.preference?.language {
            appState.setLocale(language)
        }
        authStore.updateUser(bootstrapStore.userInfo)
        await dependencies.syncStore.syncVersions(silent: true)
        dependencies.notifyWebSocketClient.connect()
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let dependencies = AppDependencies()
        return RootView()
            .environmentObject(dependencies)
            .environmentObject(dependencies.appState)
            .environmentObject(dependencies.authStore)
            .environmentObject(dependencies.bootstrapStore)
            .environmentObject(dependencies.deviceStore)
            .environmentObject(dependencies.syncStore)
    }
}
