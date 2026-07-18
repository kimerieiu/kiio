import SwiftUI

struct AgentLanguagePreferenceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected = "en_US"
    @State private var isSaving = false
    @State private var isConfirmingLanguageChange = false
    @State private var alertMessage: String?

    private let languages = SupportedLanguage.all

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
                requestSave()
            }
            .padding(20)
            .background(KiioTheme.background.opacity(0.96))
        }
        .task {
            selected = L10n.backendAgentLocale(bootstrapStore.preference?.agentLanguage ?? appState.locale)
        }
        .confirmationDialog(
            L10n.tr("common.confirm", locale: appState.locale),
            isPresented: $isConfirmingLanguageChange,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("common.confirm", locale: appState.locale)) {
                Task { await saveLanguage() }
            }
            Button(L10n.tr("common.cancel", locale: appState.locale), role: .cancel) {}
        } message: {
            Text(
                "\(L10n.tr("settings.agentLanguage", locale: appState.locale)): "
                + L10n.tr(currentLanguage.agentNameKey, locale: appState.locale)
            )
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var currentLanguage: SupportedLanguage {
        languages.first(where: { $0.code == selected })
            ?? SupportedLanguage.defaultLanguage
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
                        Text(language.badge)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(KiioTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(KiioTheme.accentSoft)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.tr(language.agentNameKey, locale: appState.locale))
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

    private func requestSave() {
        let savedLanguage = L10n.backendAgentLocale(
            bootstrapStore.preference?.agentLanguage ?? appState.locale
        )
        guard selected != savedLanguage else {
            dismiss()
            return
        }
        isConfirmingLanguageChange = true
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
