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
        canonicalLocale(locale)
    }

    static func legalLocale(_ locale: String) -> String {
        switch canonicalLocale(locale) {
        case "zh_CN", "zh_TW", "zh_HK":
            return "zh-CN"
        default:
            return "en-US"
        }
    }

    static func backendAgentLocale(_ locale: String) -> String {
        canonicalLocale(locale)
    }

    static func languageTag(_ locale: String) -> String {
        SupportedLanguage.option(for: locale).displayCode
    }

    static func isRightToLeft(_ locale: String) -> Bool {
        canonicalLocale(locale) == "ar_SA"
    }

    static func preferredLocale(_ preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        preferredLanguages.lazy.compactMap(canonicalLocaleIfSupported).first ?? "en_US"
    }

    private static func canonicalLocale(_ locale: String) -> String {
        canonicalLocaleIfSupported(locale) ?? "en_US"
    }

    private static func canonicalLocaleIfSupported(_ locale: String) -> String? {
        let normalized = locale.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()

        if normalized == "cantonese" || normalized.hasPrefix("yue") {
            return "zh_HK"
        }

        if normalized == "zh" || normalized.hasPrefix("zh_") {
            if normalized.contains("_hk") {
                return "zh_HK"
            }
            if normalized.contains("_tw") || normalized.contains("_hant") {
                return "zh_TW"
            }
            return "zh_CN"
        }

        if normalized == "en" || normalized.hasPrefix("en_") {
            return "en_US"
        }

        let languageCode = normalized.split(separator: "_").first.map(String.init) ?? normalized
        switch normalized {
        case "jp":
            return "ja_JP"
        case "kr":
            return "ko_KR"
        default:
            break
        }

        switch languageCode {
        case "ja":
            return "ja_JP"
        case "ko":
            return "ko_KR"
        case "es":
            return "es_ES"
        case "id":
            return "id_ID"
        case "th":
            return "th_TH"
        case "pt":
            return "pt_PT"
        case "ro":
            return "ro_RO"
        case "ru":
            return "ru_RU"
        case "pl":
            return "pl_PL"
        case "tr":
            return "tr_TR"
        case "fr":
            return "fr_FR"
        case "it":
            return "it_IT"
        case "de":
            return "de_DE"
        case "hi":
            return "hi_IN"
        case "cs":
            return "cs_CZ"
        case "vi":
            return "vi_VN"
        case "ar":
            return "ar_SA"
        case "uk":
            return "uk_UA"
        default:
            return nil
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
        SupportedLanguage.option(for: locale).resourceName
    }

    private static func localeIdentifier(for locale: String) -> String {
        canonicalLocale(locale)
    }
}
