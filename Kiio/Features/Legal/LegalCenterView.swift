import SwiftUI

enum LegalDocument: String, CaseIterable, Identifiable {
    case termsOfService
    case privacyPolicy
    case personalInformationCollection
    case thirdPartySharing
    case sensitivePersonalInformationConsent
    case aiDataAuthorization
    case accountDeletion
    case membershipTerms
    case mailAccountAuthorization

    var id: String { rawValue }

    var slug: String {
        switch self {
        case .termsOfService: return "terms"
        case .privacyPolicy: return "privacy"
        case .personalInformationCollection: return "collection"
        case .thirdPartySharing: return "third-party"
        case .sensitivePersonalInformationConsent: return "sensitive"
        case .aiDataAuthorization: return "ai"
        case .accountDeletion: return "deletion"
        case .membershipTerms: return "membership"
        case .mailAccountAuthorization: return "mail"
        }
    }

    var titleKey: String {
        switch self {
        case .termsOfService:
            return "legal.document.terms.title"
        case .privacyPolicy:
            return "legal.document.privacy.title"
        case .personalInformationCollection:
            return "legal.document.collection.title"
        case .thirdPartySharing:
            return "legal.document.thirdParty.title"
        case .sensitivePersonalInformationConsent:
            return "legal.document.sensitive.title"
        case .aiDataAuthorization:
            return "legal.document.ai.title"
        case .accountDeletion:
            return "legal.document.deletion.title"
        case .membershipTerms:
            return "legal.document.membership.title"
        case .mailAccountAuthorization:
            return "legal.document.mail.title"
        }
    }

    var icon: String {
        switch self {
        case .termsOfService:
            return "doc.text"
        case .privacyPolicy:
            return "hand.raised"
        case .personalInformationCollection:
            return "list.bullet.clipboard"
        case .thirdPartySharing:
            return "square.stack.3d.up"
        case .sensitivePersonalInformationConsent:
            return "lock.shield"
        case .aiDataAuthorization:
            return "brain.head.profile"
        case .accountDeletion:
            return "person.crop.circle.badge.minus"
        case .membershipTerms:
            return "crown"
        case .mailAccountAuthorization:
            return "envelope.badge"
        }
    }
}

struct LegalCenterView: View {
    @EnvironmentObject private var appState: AppState

    private let coreDocuments: [LegalDocument] = [
        .termsOfService,
        .privacyPolicy
    ]

    private let privacyDocuments: [LegalDocument] = [
        .personalInformationCollection,
        .thirdPartySharing,
        .sensitivePersonalInformationConsent,
        .aiDataAuthorization,
        .accountDeletion
    ]

    private let featureDocuments: [LegalDocument] = [
        .membershipTerms,
        .mailAccountAuthorization
    ]

    init() {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                documentSection(
                    title: L10n.tr("legal.section.core", locale: appState.locale),
                    documents: coreDocuments
                )
                documentSection(
                    title: L10n.tr("legal.section.privacy", locale: appState.locale),
                    documents: privacyDocuments
                )
                documentSection(
                    title: L10n.tr("legal.section.features", locale: appState.locale),
                    documents: featureDocuments
                )
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("legal.center.title", locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .kiioHidesTabBar()
        .background(KiioTheme.background.ignoresSafeArea())
    }

    private func documentSection(title: String, documents: [LegalDocument]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: title)

            KiioCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(documents.indices, id: \.self) { index in
                        let document = documents[index]

                        NavigationLink {
                            LegalDocumentView(document: document)
                        } label: {
                            LegalDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)

                        if index != documents.count - 1 {
                            Divider()
                                .padding(.leading, 64)
                        }
                    }
                }
            }
        }
    }
}

struct LegalDocumentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = LegalDocumentViewModel()

    let document: LegalDocument
    let requestedVersion: LegalDocumentVersionDTO?

    init(document: LegalDocument, requestedVersion: LegalDocumentVersionDTO? = nil) {
        self.document = document
        self.requestedVersion = requestedVersion
    }

    var body: some View {
        Group {
            if let html = viewModel.html {
                VStack(spacing: 0) {
                    if viewModel.isUsingCache {
                        cachedNotice
                    }
                    LegalWebView(
                        html: html,
                        baseURL: viewModel.metadata.flatMap { URL(string: $0.pageUrl) },
                        onExternalURL: { openURL($0) }
                    )
                    versionFooter
                }
            } else if viewModel.isLoading || viewModel.errorMessage == nil {
                KiioLoadingCard(message: L10n.tr("legal.document.loading", locale: appState.locale))
                    .padding(20)
            } else {
                loadError
                    .padding(20)
            }
        }
        .navigationTitle(L10n.tr(document.titleKey, locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .kiioHidesTabBar()
        .background(KiioTheme.background.ignoresSafeArea())
        .task(id: "\(document.slug)-\(legalLocale)-\(requestedVersion?.version ?? "latest")") {
            await load()
        }
    }

    private var cachedNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text(L10n.tr("legal.document.cached", locale: appState.locale))
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(KiioTheme.secondaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.info.opacity(0.08))
    }

    private var versionFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
            Text(L10n.tr("legal.document.versionValue", locale: appState.locale, viewModel.metadata?.version ?? "--"))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(KiioTheme.mutedText)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
    }

    private var loadError: some View {
        VStack(spacing: 16) {
            KiioEmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: L10n.tr("legal.document.loadFailed", locale: appState.locale),
                message: viewModel.errorMessage ?? L10n.tr("legal.document.loadFailedMessage", locale: appState.locale)
            )
            KiioPrimaryButton(title: L10n.tr("legal.document.retry", locale: appState.locale)) {
                Task { await load(force: true) }
            }
        }
    }

    private var legalLocale: String {
        L10n.legalLocale(appState.locale)
    }

    private func load(force: Bool = false) async {
        await viewModel.load(
            document: document,
            locale: legalLocale,
            requestedVersion: requestedVersion,
            service: dependencies.legalDocumentService,
            cache: dependencies.legalDocumentCache,
            force: force
        )
    }
}

struct LegalDocumentSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let document: LegalDocument
    let requestedVersion: LegalDocumentVersionDTO?

    init(document: LegalDocument, requestedVersion: LegalDocumentVersionDTO? = nil) {
        self.document = document
        self.requestedVersion = requestedVersion
    }

    var body: some View {
        NavigationStack {
            LegalDocumentView(document: document, requestedVersion: requestedVersion)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.tr("common.done", locale: appState.locale)) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct LegalDocumentRow: View {
    @EnvironmentObject private var appState: AppState

    let document: LegalDocument

    init(document: LegalDocument) {
        self.document = document
    }

    var body: some View {
        HStack(spacing: 12) {
            KiioIconBadge(systemImage: document.icon, size: 38, iconSize: 15)

            Text(L10n.tr(document.titleKey, locale: appState.locale))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.88)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
