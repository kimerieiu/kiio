import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @State private var startupGateError: String?
    @State private var isRunningStartupGate = false

    var body: some View {
        Group {
            switch appState.rootRoute {
            case .splash:
                SplashView(
                    errorMessage: startupGateError,
                    isRetrying: isRunningStartupGate,
                    retryAction: {
                        Task {
                            await runStartupGate()
                        }
                    }
                )
                    .task {
                        await runStartupGate()
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
                if appState.rootRoute == .main || appState.rootRoute == .invite || appState.rootRoute == .splash {
                    startupGateError = nil
                    appState.showAuth()
                }
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active,
                  appState.rootRoute == .splash,
                  startupGateError != nil else {
                return
            }

            Task {
                await runStartupGate()
            }
        }
    }

    private func runStartupGate() async {
        guard !isRunningStartupGate else {
            return
        }

        isRunningStartupGate = true
        startupGateError = nil
        defer { isRunningStartupGate = false }

        let result = await authStore.validateStartupSession()
        guard appState.rootRoute == .splash else {
            return
        }

        switch result {
        case .noLocalSession:
            appState.finishSplash(isAuthenticated: false)
        case .localSessionExpired, .unauthorized:
            appState.showAuth()
        case .validated(_):
            appState.showMain()
        case .recoverableFailure(let error):
            startupGateError = error.errorDescription ?? AppError.invalidResponse.errorDescription
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
