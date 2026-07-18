import SwiftUI

struct LanguageSelectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedLocale = L10n.preferredLocale()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            KiioLogoView(size: 54)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("language.title", locale: selectedLocale))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("language.subtitle", locale: selectedLocale))
                    .font(.system(size: 15))
                    .foregroundStyle(KiioTheme.secondaryText)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(SupportedLanguage.all) { language in
                        languageRow(language)
                    }
                }
            }

            KiioPrimaryButton(title: L10n.tr("common.continue", locale: selectedLocale)) {
                appState.completeLanguage(selectedLocale)
            }
        }
        .padding(24)
        .background(KiioTheme.background.ignoresSafeArea())
        .environment(\.locale, Locale(identifier: selectedLocale))
        .environment(
            \.layoutDirection,
            L10n.isRightToLeft(selectedLocale) ? .rightToLeft : .leftToRight
        )
        .onAppear {
            selectedLocale = appState.locale
        }
    }

    private func languageRow(_ language: SupportedLanguage) -> some View {
        Button {
            selectedLocale = language.code
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr(language.appNameKey, locale: selectedLocale))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KiioTheme.text)
                    Text(language.displayCode)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                }
                Spacer()
                Image(systemName: selectedLocale == language.code ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedLocale == language.code ? KiioTheme.accent : KiioTheme.mutedText)
            }
            .padding(16)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
        }
    }
}
