import Foundation
import Combine

enum RootRoute {
    case splash
    case language
    case welcome
    case auth
    case invite
    case main
}

enum MainTab: Hashable {
    case home
    case chat
    case device
    case profile

    var localizationKey: String {
        switch self {
        case .home: return "tab.home"
        case .chat: return "tab.chat"
        case .device: return "tab.device"
        case .profile: return "tab.profile"
        }
    }

    var assetName: String {
        switch self {
        case .home: return "TabHome"
        case .chat: return "TabChat"
        case .device: return "TabDevice"
        case .profile: return "TabProfile"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var rootRoute: RootRoute = .splash
    @Published var selectedTab: MainTab = .home
    @Published var locale: String
    @Published private(set) var systemTimeZone: TimeZone

    private let settings: LocalSettingsStore

    init(settings: LocalSettingsStore) {
        self.settings = settings
        self.locale = settings.locale
        self.systemTimeZone = .current
    }

    func finishSplash(isAuthenticated: Bool) {
        if !settings.didChooseLanguage {
            rootRoute = .language
        } else if !settings.didSeeWelcome {
            rootRoute = .welcome
        } else {
            rootRoute = isAuthenticated ? .main : .auth
        }
    }

    func completeLanguage(_ locale: String) {
        settings.markLanguageDone(locale)
        self.locale = settings.locale
        rootRoute = .welcome
    }

    func setLocale(_ locale: String) {
        settings.locale = locale
        self.locale = settings.locale
    }

    func refreshSystemTimeZone() {
        systemTimeZone = .current
    }

    func completeWelcome(isAuthenticated: Bool) {
        settings.markWelcomeDone()
        rootRoute = isAuthenticated ? .main : .auth
    }

    func showAuth() {
        rootRoute = .auth
    }

    func showInvite() {
        rootRoute = .invite
    }

    func showMain(selectedTab: MainTab? = nil) {
        if let selectedTab {
            self.selectedTab = selectedTab
        }
        rootRoute = .main
    }
}
