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

    var summaryKey: String {
        switch self {
        case .termsOfService:
            return "legal.document.terms.summary"
        case .privacyPolicy:
            return "legal.document.privacy.summary"
        case .personalInformationCollection:
            return "legal.document.collection.summary"
        case .thirdPartySharing:
            return "legal.document.thirdParty.summary"
        case .sensitivePersonalInformationConsent:
            return "legal.document.sensitive.summary"
        case .aiDataAuthorization:
            return "legal.document.ai.summary"
        case .accountDeletion:
            return "legal.document.deletion.summary"
        case .membershipTerms:
            return "legal.document.membership.summary"
        case .mailAccountAuthorization:
            return "legal.document.mail.summary"
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
                introductionCard
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

    private var introductionCard: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                KiioIconBadge(systemImage: "checkmark.shield", size: 48, iconSize: 20)

                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.tr("legal.center.heading", locale: appState.locale))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr("legal.center.description", locale: appState.locale))
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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

    let document: LegalDocument

    init(document: LegalDocument) {
        self.document = document
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                draftNotice
                informationCard
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr(document.titleKey, locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .kiioHidesTabBar()
        .background(KiioTheme.background.ignoresSafeArea())
    }

    private var headerCard: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                KiioIconBadge(systemImage: document.icon, size: 50, iconSize: 20)

                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.tr(document.titleKey, locale: appState.locale))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr(document.summaryKey, locale: appState.locale))
                        .font(.system(size: 14))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var draftNotice: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KiioTheme.info)

            Text(L10n.tr("legal.document.draftNotice", locale: appState.locale))
                .font(.system(size: 13))
                .foregroundStyle(KiioTheme.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.info.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.info.opacity(0.2), lineWidth: 1)
        )
    }

    private var informationCard: some View {
        KiioCard {
            KiioSectionTitle(
                title: L10n.tr("legal.document.information", locale: appState.locale),
                icon: "clock"
            )

            KiioDetailField(
                title: L10n.tr("legal.document.status", locale: appState.locale),
                value: L10n.tr("legal.status.draft", locale: appState.locale)
            )
            Divider()
            KiioDetailField(
                title: L10n.tr("legal.document.version", locale: appState.locale),
                value: L10n.tr("legal.document.unpublished", locale: appState.locale)
            )
        }
    }
}

struct LegalDocumentSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let document: LegalDocument

    init(document: LegalDocument) {
        self.document = document
    }

    var body: some View {
        NavigationStack {
            LegalDocumentView(document: document)
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
    var showsStatus = true

    init(document: LegalDocument, showsStatus: Bool = true) {
        self.document = document
        self.showsStatus = showsStatus
    }

    var body: some View {
        HStack(spacing: 12) {
            KiioIconBadge(systemImage: document.icon, size: 38, iconSize: 15)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr(document.titleKey, locale: appState.locale))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.tr(document.summaryKey, locale: appState.locale))
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if showsStatus {
                KiioStatusBadge(
                    text: L10n.tr("legal.status.draft", locale: appState.locale),
                    tone: .muted
                )
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}
