import SwiftUI
import UIKit

@main
struct KiioApp: App {
    @StateObject private var dependencies = AppDependencies()

    init() {
        configureNavigationAppearance()
    }

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

    private func configureNavigationAppearance() {
        let backImage = UIImage(
            systemName: "chevron.left",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        )
        UINavigationBar.appearance().backIndicatorImage = backImage
        UINavigationBar.appearance().backIndicatorTransitionMaskImage = backImage
    }
}
