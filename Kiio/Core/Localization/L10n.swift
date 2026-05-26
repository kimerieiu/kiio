import Foundation

enum L10n {
    static func tr(_ key: String, locale: String, _ arguments: CVarArg...) -> String {
        let table = bundle(for: locale)
        let format = NSLocalizedString(key, bundle: table, comment: "")

        if arguments.isEmpty {
            return format
        }

        return String(format: format, locale: Locale(identifier: localeIdentifier(for: locale)), arguments: arguments)
    }

    static func backendLocale(_ locale: String) -> String {
        switch locale {
        case "en", "en_US", "en-US":
            return "en_US"
        default:
            return "zh_CN"
        }
    }

    private static func bundle(for locale: String) -> Bundle {
        let resource = lprojName(for: locale)
        guard let path = Bundle.main.path(forResource: resource, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    private static func lprojName(for locale: String) -> String {
        switch locale {
        case "en", "en_US", "en-US":
            return "en"
        default:
            return "zh-Hans"
        }
    }

    private static func localeIdentifier(for locale: String) -> String {
        switch locale {
        case "en", "en_US", "en-US":
            return "en_US"
        default:
            return "zh_CN"
        }
    }
}
