import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLocale = "zh_CN"

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            KiioLogoView(size: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("language.title", locale: appState.locale))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("language.subtitle", locale: appState.locale))
                    .font(.system(size: 15))
                    .foregroundStyle(KiioTheme.secondaryText)
            }

            VStack(spacing: 12) {
                languageRow(title: L10n.tr("language.zh", locale: appState.locale), subtitle: "zh_CN", value: "zh_CN")
                languageRow(title: L10n.tr("language.en", locale: appState.locale), subtitle: "en_US", value: "en_US")
            }

            Spacer()

            KiioPrimaryButton(title: L10n.tr("common.continue", locale: appState.locale)) {
                appState.completeLanguage(selectedLocale)
            }
        }
        .padding(24)
        .background(KiioTheme.background.ignoresSafeArea())
    }

    private func languageRow(title: String, subtitle: String, value: String) -> some View {
        Button {
            selectedLocale = value
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KiioTheme.text)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                }
                Spacer()
                Image(systemName: selectedLocale == value ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedLocale == value ? KiioTheme.accent : KiioTheme.mutedText)
            }
            .padding(16)
            .background(.white.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
