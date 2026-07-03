import SwiftUI

struct AgentLanguagePreferenceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected = "en_US"
    @State private var isSaving = false
    @State private var alertMessage: String?

    private let languages: [AgentLanguageOption] = [
        AgentLanguageOption(code: "zh_CN", displayCode: "zh-CN", flag: "CN", nameKey: "settingsLanguage.agent.zhCn", previewKey: "settingsLanguage.agentPreview.zhCn"),
        AgentLanguageOption(code: "zh_HK", displayCode: "zh-HK", flag: "HK", nameKey: "settingsLanguage.agent.zhHk", previewKey: "settingsLanguage.agentPreview.zhHk"),
        AgentLanguageOption(code: "en_US", displayCode: "en-US", flag: "EN", nameKey: "settingsLanguage.agent.enUs", previewKey: "settingsLanguage.agentPreview.enUs"),
        AgentLanguageOption(code: "ja_JP", displayCode: "ja-JP", flag: "JP", nameKey: "settingsLanguage.agent.jaJp", previewKey: "settingsLanguage.agentPreview.jaJp"),
        AgentLanguageOption(code: "ko_KR", displayCode: "ko-KR", flag: "KR", nameKey: "settingsLanguage.agent.koKr", previewKey: "settingsLanguage.agentPreview.koKr"),
        AgentLanguageOption(code: "es_ES", displayCode: "es-ES", flag: "ES", nameKey: "settingsLanguage.agent.esEs", previewKey: "settingsLanguage.agentPreview.esEs"),
        AgentLanguageOption(code: "id_ID", displayCode: "id-ID", flag: "ID", nameKey: "settingsLanguage.agent.idId", previewKey: "settingsLanguage.agentPreview.idId"),
        AgentLanguageOption(code: "th_TH", displayCode: "th-TH", flag: "TH", nameKey: "settingsLanguage.agent.thTh", previewKey: "settingsLanguage.agentPreview.thTh"),
        AgentLanguageOption(code: "pt_PT", displayCode: "pt-PT", flag: "PT", nameKey: "settingsLanguage.agent.ptPt", previewKey: "settingsLanguage.agentPreview.ptPt"),
        AgentLanguageOption(code: "ro_RO", displayCode: "ro-RO", flag: "RO", nameKey: "settingsLanguage.agent.roRo", previewKey: "settingsLanguage.agentPreview.roRo"),
        AgentLanguageOption(code: "ru_RU", displayCode: "ru-RU", flag: "RU", nameKey: "settingsLanguage.agent.ruRu", previewKey: "settingsLanguage.agentPreview.ruRu"),
        AgentLanguageOption(code: "pl_PL", displayCode: "pl-PL", flag: "PL", nameKey: "settingsLanguage.agent.plPl", previewKey: "settingsLanguage.agentPreview.plPl"),
        AgentLanguageOption(code: "tr_TR", displayCode: "tr-TR", flag: "TR", nameKey: "settingsLanguage.agent.trTr", previewKey: "settingsLanguage.agentPreview.trTr"),
        AgentLanguageOption(code: "fr_FR", displayCode: "fr-FR", flag: "FR", nameKey: "settingsLanguage.agent.frFr", previewKey: "settingsLanguage.agentPreview.frFr"),
        AgentLanguageOption(code: "it_IT", displayCode: "it-IT", flag: "IT", nameKey: "settingsLanguage.agent.itIt", previewKey: "settingsLanguage.agentPreview.itIt"),
        AgentLanguageOption(code: "de_DE", displayCode: "de-DE", flag: "DE", nameKey: "settingsLanguage.agent.deDe", previewKey: "settingsLanguage.agentPreview.deDe"),
        AgentLanguageOption(code: "hi_IN", displayCode: "hi-IN", flag: "IN", nameKey: "settingsLanguage.agent.hiIn", previewKey: "settingsLanguage.agentPreview.hiIn"),
        AgentLanguageOption(code: "cs_CZ", displayCode: "cs-CZ", flag: "CZ", nameKey: "settingsLanguage.agent.csCz", previewKey: "settingsLanguage.agentPreview.csCz"),
        AgentLanguageOption(code: "vi_VN", displayCode: "vi-VN", flag: "VN", nameKey: "settingsLanguage.agent.viVn", previewKey: "settingsLanguage.agentPreview.viVn"),
        AgentLanguageOption(code: "ar_SA", displayCode: "ar-SA", flag: "AR", nameKey: "settingsLanguage.agent.arSa", previewKey: "settingsLanguage.agentPreview.arSa"),
        AgentLanguageOption(code: "uk_UA", displayCode: "uk-UA", flag: "UA", nameKey: "settingsLanguage.agent.ukUa", previewKey: "settingsLanguage.agentPreview.ukUa")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                previewCard
                scopeBadge
                hintCard
                languageCard
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("settingsLanguage.title", locale: appState.locale))
        .kiioHidesTabBar()
        .safeAreaInset(edge: .bottom) {
            KiioPrimaryButton(
                title: L10n.tr("common.save", locale: appState.locale),
                isLoading: isSaving
            ) {
                Task { await saveLanguage() }
            }
            .padding(20)
            .background(KiioTheme.background.opacity(0.96))
        }
        .task {
            selected = L10n.backendAgentLocale(bootstrapStore.preference?.agentLanguage ?? appState.locale)
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var currentLanguage: AgentLanguageOption {
        languages.first(where: { $0.code == selected })
            ?? languages.first(where: { $0.code == "en_US" })
            ?? languages[0]
    }

    private var previewCard: some View {
        KiioCard {
            Text(L10n.tr("settingsLanguage.preview", locale: appState.locale))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KiioTheme.mutedText)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(KiioTheme.accentSoft)
                    .clipShape(Circle())

                Text(L10n.tr(currentLanguage.previewKey, locale: appState.locale))
                    .font(.system(size: 14))
                    .foregroundStyle(KiioTheme.text)
                    .lineSpacing(3)
                    .padding(12)
                    .background(KiioTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(KiioTheme.border, lineWidth: 1)
                    )
            }
        }
    }

    private var scopeBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .font(.system(size: 12, weight: .semibold))
            Text(L10n.tr("settingsLanguage.agentScope", locale: appState.locale))
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(KiioTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(KiioTheme.accentSoft)
        .clipShape(Capsule())
    }

    private var hintCard: some View {
        Text(L10n.tr("settingsLanguage.agentHint", locale: appState.locale))
            .font(.system(size: 14))
            .foregroundStyle(KiioTheme.secondaryText)
            .lineSpacing(3)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
    }

    private var languageCard: some View {
        VStack(spacing: 0) {
            ForEach(languages) { language in
                Button {
                    selected = language.code
                } label: {
                    HStack(spacing: 12) {
                        Text(language.flag)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(KiioTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(KiioTheme.accentSoft)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.tr(language.nameKey, locale: appState.locale))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(KiioTheme.text)
                            Text(language.displayCode)
                                .font(.system(size: 12))
                                .foregroundStyle(KiioTheme.secondaryText)
                        }

                        Spacer()

                        Image(systemName: selected == language.code ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected == language.code ? KiioTheme.accent : KiioTheme.mutedText)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if language.id != languages.last?.id {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }

    private func saveLanguage() async {
        isSaving = true
        defer { isSaving = false }

        if await bootstrapStore.updateAgentLanguagePreference(selected) {
            dismiss()
        } else {
            alertMessage = bootstrapStore.errorMessage
        }
    }

}

private struct AgentLanguageOption: Identifiable, Equatable {
    let code: String
    let displayCode: String
    let flag: String
    let nameKey: String
    let previewKey: String

    var id: String { code }
}
