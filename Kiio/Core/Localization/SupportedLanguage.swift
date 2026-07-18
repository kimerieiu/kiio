import Foundation

struct SupportedLanguage: Identifiable, Equatable {
    let code: String
    let displayCode: String
    let badge: String
    let appNameKey: String
    let agentNameKey: String
    let previewKey: String

    var id: String { code }

    var resourceName: String {
        switch code {
        case "zh_CN": return "zh-Hans"
        case "zh_TW": return "zh-Hant"
        case "zh_HK": return "zh-HK"
        case "en_US": return "en"
        case "ja_JP": return "ja"
        case "ko_KR": return "ko"
        case "es_ES": return "es"
        case "id_ID": return "id"
        case "th_TH": return "th"
        case "pt_PT": return "pt-PT"
        case "ro_RO": return "ro"
        case "ru_RU": return "ru"
        case "pl_PL": return "pl"
        case "tr_TR": return "tr"
        case "fr_FR": return "fr"
        case "it_IT": return "it"
        case "de_DE": return "de"
        case "hi_IN": return "hi"
        case "cs_CZ": return "cs"
        case "vi_VN": return "vi"
        case "ar_SA": return "ar"
        case "uk_UA": return "uk"
        default: return "en"
        }
    }

    static let all: [SupportedLanguage] = [
        SupportedLanguage(code: "zh_CN", displayCode: "zh-CN", badge: "CN", appNameKey: "language.zhCn", agentNameKey: "settingsLanguage.agent.zhCn", previewKey: "settingsLanguage.agentPreview.zhCn"),
        SupportedLanguage(code: "zh_TW", displayCode: "zh-TW", badge: "TW", appNameKey: "language.zhTw", agentNameKey: "settingsLanguage.agent.zhTw", previewKey: "settingsLanguage.agentPreview.zhTw"),
        SupportedLanguage(code: "zh_HK", displayCode: "zh-HK", badge: "HK", appNameKey: "language.zhHk", agentNameKey: "settingsLanguage.agent.zhHk", previewKey: "settingsLanguage.agentPreview.zhHk"),
        SupportedLanguage(code: "en_US", displayCode: "en-US", badge: "EN", appNameKey: "language.enUs", agentNameKey: "settingsLanguage.agent.enUs", previewKey: "settingsLanguage.agentPreview.enUs"),
        SupportedLanguage(code: "ja_JP", displayCode: "ja-JP", badge: "JP", appNameKey: "language.jaJp", agentNameKey: "settingsLanguage.agent.jaJp", previewKey: "settingsLanguage.agentPreview.jaJp"),
        SupportedLanguage(code: "ko_KR", displayCode: "ko-KR", badge: "KR", appNameKey: "language.koKr", agentNameKey: "settingsLanguage.agent.koKr", previewKey: "settingsLanguage.agentPreview.koKr"),
        SupportedLanguage(code: "es_ES", displayCode: "es-ES", badge: "ES", appNameKey: "language.esEs", agentNameKey: "settingsLanguage.agent.esEs", previewKey: "settingsLanguage.agentPreview.esEs"),
        SupportedLanguage(code: "id_ID", displayCode: "id-ID", badge: "ID", appNameKey: "language.idId", agentNameKey: "settingsLanguage.agent.idId", previewKey: "settingsLanguage.agentPreview.idId"),
        SupportedLanguage(code: "th_TH", displayCode: "th-TH", badge: "TH", appNameKey: "language.thTh", agentNameKey: "settingsLanguage.agent.thTh", previewKey: "settingsLanguage.agentPreview.thTh"),
        SupportedLanguage(code: "pt_PT", displayCode: "pt-PT", badge: "PT", appNameKey: "language.ptPt", agentNameKey: "settingsLanguage.agent.ptPt", previewKey: "settingsLanguage.agentPreview.ptPt"),
        SupportedLanguage(code: "ro_RO", displayCode: "ro-RO", badge: "RO", appNameKey: "language.roRo", agentNameKey: "settingsLanguage.agent.roRo", previewKey: "settingsLanguage.agentPreview.roRo"),
        SupportedLanguage(code: "ru_RU", displayCode: "ru-RU", badge: "RU", appNameKey: "language.ruRu", agentNameKey: "settingsLanguage.agent.ruRu", previewKey: "settingsLanguage.agentPreview.ruRu"),
        SupportedLanguage(code: "pl_PL", displayCode: "pl-PL", badge: "PL", appNameKey: "language.plPl", agentNameKey: "settingsLanguage.agent.plPl", previewKey: "settingsLanguage.agentPreview.plPl"),
        SupportedLanguage(code: "tr_TR", displayCode: "tr-TR", badge: "TR", appNameKey: "language.trTr", agentNameKey: "settingsLanguage.agent.trTr", previewKey: "settingsLanguage.agentPreview.trTr"),
        SupportedLanguage(code: "fr_FR", displayCode: "fr-FR", badge: "FR", appNameKey: "language.frFr", agentNameKey: "settingsLanguage.agent.frFr", previewKey: "settingsLanguage.agentPreview.frFr"),
        SupportedLanguage(code: "it_IT", displayCode: "it-IT", badge: "IT", appNameKey: "language.itIt", agentNameKey: "settingsLanguage.agent.itIt", previewKey: "settingsLanguage.agentPreview.itIt"),
        SupportedLanguage(code: "de_DE", displayCode: "de-DE", badge: "DE", appNameKey: "language.deDe", agentNameKey: "settingsLanguage.agent.deDe", previewKey: "settingsLanguage.agentPreview.deDe"),
        SupportedLanguage(code: "hi_IN", displayCode: "hi-IN", badge: "IN", appNameKey: "language.hiIn", agentNameKey: "settingsLanguage.agent.hiIn", previewKey: "settingsLanguage.agentPreview.hiIn"),
        SupportedLanguage(code: "cs_CZ", displayCode: "cs-CZ", badge: "CZ", appNameKey: "language.csCz", agentNameKey: "settingsLanguage.agent.csCz", previewKey: "settingsLanguage.agentPreview.csCz"),
        SupportedLanguage(code: "vi_VN", displayCode: "vi-VN", badge: "VN", appNameKey: "language.viVn", agentNameKey: "settingsLanguage.agent.viVn", previewKey: "settingsLanguage.agentPreview.viVn"),
        SupportedLanguage(code: "ar_SA", displayCode: "ar-SA", badge: "AR", appNameKey: "language.arSa", agentNameKey: "settingsLanguage.agent.arSa", previewKey: "settingsLanguage.agentPreview.arSa"),
        SupportedLanguage(code: "uk_UA", displayCode: "uk-UA", badge: "UA", appNameKey: "language.ukUa", agentNameKey: "settingsLanguage.agent.ukUa", previewKey: "settingsLanguage.agentPreview.ukUa")
    ]

    static let defaultLanguage = all.first(where: { $0.code == "en_US" }) ?? all[0]

    static func option(for locale: String) -> SupportedLanguage {
        let code = L10n.backendLocale(locale)
        return all.first(where: { $0.code == code }) ?? defaultLanguage
    }
}
