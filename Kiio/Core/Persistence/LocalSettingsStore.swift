import Foundation

final class LocalSettingsStore {
    private enum Key {
        static let locale = "kiio.locale"
        static let languageDone = "kiio.onboarding.languageDone"
        static let welcomeDone = "kiio.onboarding.welcomeDone"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var locale: String {
        get { defaults.string(forKey: Key.locale) ?? "zh_CN" }
        set { defaults.set(normalizeLocale(newValue), forKey: Key.locale) }
    }

    var didChooseLanguage: Bool {
        defaults.bool(forKey: Key.languageDone)
    }

    var didSeeWelcome: Bool {
        defaults.bool(forKey: Key.welcomeDone)
    }

    func markLanguageDone(_ locale: String) {
        self.locale = locale
        defaults.set(true, forKey: Key.languageDone)
    }

    func markWelcomeDone() {
        defaults.set(true, forKey: Key.welcomeDone)
    }

    private func normalizeLocale(_ value: String) -> String {
        switch value {
        case "en", "en_US", "en-US":
            return "en_US"
        default:
            return "zh_CN"
        }
    }
}
