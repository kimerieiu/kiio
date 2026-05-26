import SwiftUI

@main
struct KiioApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
                .environmentObject(dependencies.appState)
                .environmentObject(dependencies.authStore)
                .environmentObject(dependencies.bootstrapStore)
                .environmentObject(dependencies.deviceStore)
                .environmentObject(dependencies.syncStore)
                .tint(KiioTheme.accent)
        }
    }
}
