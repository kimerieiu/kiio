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
        case "zh", "zh_CN", "zh-CN":
            return "zh_CN"
        default:
            return "en_US"
        }
    }

    static func legalLocale(_ locale: String) -> String {
        switch locale {
        case "zh", "zh_CN", "zh-CN":
            return "zh-CN"
        default:
            return "en-US"
        }
    }

    static func backendAgentLocale(_ locale: String) -> String {
        let normalized = locale.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()

        switch normalized {
        case "zh", "zh_cn", "zh_hans":
            return "zh_CN"
        case "zh_tw", "zh_hant":
            return "zh_TW"
        case "zh_hk", "yue", "cantonese":
            return "zh_HK"
        case "en", "en_us":
            return "en_US"
        case "ja", "jp", "ja_jp":
            return "ja_JP"
        case "ko", "kr", "ko_kr":
            return "ko_KR"
        case "es", "es_es":
            return "es_ES"
        case "id", "id_id":
            return "id_ID"
        case "th", "th_th":
            return "th_TH"
        case "pt", "pt_pt":
            return "pt_PT"
        case "ro", "ro_ro":
            return "ro_RO"
        case "ru", "ru_ru":
            return "ru_RU"
        case "pl", "pl_pl":
            return "pl_PL"
        case "tr", "tr_tr":
            return "tr_TR"
        case "fr", "fr_fr":
            return "fr_FR"
        case "it", "it_it":
            return "it_IT"
        case "de", "de_de":
            return "de_DE"
        case "hi", "hi_in":
            return "hi_IN"
        case "cs", "cs_cz":
            return "cs_CZ"
        case "vi", "vi_vn":
            return "vi_VN"
        case "ar", "ar_sa":
            return "ar_SA"
        case "uk", "uk_ua":
            return "uk_UA"
        default:
            return "en_US"
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
        case "zh", "zh_CN", "zh-CN":
            return "zh-Hans"
        default:
            return "en"
        }
    }

    private static func localeIdentifier(for locale: String) -> String {
        switch locale {
        case "en", "en_US", "en-US":
            return "en_US"
        case "zh", "zh_CN", "zh-CN":
            return "zh_CN"
        default:
            return "en_US"
        }
    }
}
