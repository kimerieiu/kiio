import Foundation

struct LegalDocumentVersionDTO: Codable, Equatable {
    let id: String
    let slug: String
    let version: String
    let locale: String
    let title: String
    let updatedAt: String?
    let effectiveAt: String?
    let contentHash: String
    let changeType: String?
    let requiresReconsent: Bool?
    let changeSummary: String?
    let pageUrl: String

    var consentSelection: LegalConsentSelection {
        LegalConsentSelection(slug: slug, version: version, locale: locale)
    }
}

struct LegalConsentSelection: Codable, Equatable {
    let slug: String
    let version: String
    let locale: String
}

struct LegalConsentContext: Codable, Equatable {
    let requestId: String
    let appVersion: String
    let platform: String
    let source: String
    let clientLocale: String
    let consentTextVersion: String

    static func ios(locale: String, source: String, requestId: String = UUID().uuidString) -> Self {
        Self(
            requestId: requestId,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            platform: "IOS",
            source: source,
            clientLocale: L10n.legalLocale(locale),
            consentTextVersion: "1"
        )
    }
}

struct LegalConsentEventRequest: Encodable {
    let document: LegalConsentSelection
    let scenario: String
    let action: String
    let context: LegalConsentContext
}

struct CachedLegalDocument {
    let metadata: LegalDocumentVersionDTO
    let html: String
}
