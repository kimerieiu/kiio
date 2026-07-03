import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var isConfirmingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                accountCard
                languageSection
                pendingSection(
                    title: L10n.tr("settings.notificationsPrivacy", locale: appState.locale),
                    rows: [
                        SettingsPendingRow(icon: "bell.badge", titleKey: "settings.push", subtitleKey: "settings.pushSub"),
                        SettingsPendingRow(icon: "hand.raised", titleKey: "settings.privacy", subtitleKey: "settings.privacySub"),
                        SettingsPendingRow(icon: "lock.shield", titleKey: "settings.security", subtitleKey: "settings.securitySub")
                    ]
                )
                pendingSection(
                    title: L10n.tr("settings.support", locale: appState.locale),
                    rows: [
                        SettingsPendingRow(icon: "questionmark.circle", titleKey: "settings.help", subtitleKey: "settings.helpSub"),
                        SettingsPendingRow(icon: "doc.text", titleKey: "settings.agreement", subtitleKey: "settings.agreementSub")
                    ]
                )
                signOutButton
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("settings.title", locale: appState.locale))
        .background(KiioTheme.background.ignoresSafeArea())
        .refreshable {
            await bootstrapStore.refresh()
            authStore.updateUser(bootstrapStore.userInfo)
        }
        .confirmationDialog(
            L10n.tr("profile.signOut", locale: appState.locale),
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("profile.signOut", locale: appState.locale), role: .destructive) {
                signOut()
            }
            Button(L10n.tr("common.cancel", locale: appState.locale), role: .cancel) {}
        } message: {
            Text(L10n.tr("profile.signOutConfirm", locale: appState.locale))
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: L10n.tr("settings.account", locale: appState.locale), icon: "person")

            KiioCard {
                HStack(spacing: 14) {
                    Text(initial)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(KiioTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 7) {
                        Text(displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(KiioTheme.text)
                            .lineLimit(1)
                        Text(L10n.tr("profile.id", locale: appState.locale, userId))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: L10n.tr("settings.language", locale: appState.locale), icon: "globe")

            KiioCard(padding: 0) {
                NavigationLink {
                    AppLanguagePreferenceView()
                } label: {
                    SettingsMenuRow(
                        icon: "globe",
                        title: L10n.tr("settings.appLanguage", locale: appState.locale),
                        subtitle: currentAppLanguageSubtitle,
                        accessory: .chevron
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pendingSection(title: String, rows: [SettingsPendingRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: title)
            KiioCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { index in
                        SettingsMenuRow(
                            icon: rows[index].icon,
                            title: L10n.tr(rows[index].titleKey, locale: appState.locale),
                            subtitle: L10n.tr(rows[index].subtitleKey, locale: appState.locale),
                            accessory: .badge(L10n.tr("common.soon", locale: appState.locale))
                        )

                        if index != rows.count - 1 {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
    }

    private var signOutButton: some View {
        Button {
            isConfirmingSignOut = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                Text(L10n.tr("profile.signOut", locale: appState.locale))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(KiioTheme.danger)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var user: UserDetail? {
        bootstrapStore.userInfo ?? authStore.currentUser
    }

    private var currentAppLanguageSubtitle: String {
        L10n.tr("settings.appLanguageSub", locale: appState.locale, appLanguageName(for: appState.locale))
    }

    private func appLanguageName(for locale: String) -> String {
        switch L10n.backendLocale(locale) {
        case "zh_CN":
            return L10n.tr("language.zh", locale: appState.locale)
        default:
            return L10n.tr("language.en", locale: appState.locale)
        }
    }

    private var displayName: String {
        user?.username?.isEmpty == false ? user!.username! : L10n.tr("profile.defaultUser", locale: appState.locale)
    }

    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var userId: String {
        user?.id ?? "--"
    }

    private func signOut() {
        authStore.logout()
        bootstrapStore.reset()
        appState.showAuth()
    }
}

private struct AppLanguagePreferenceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @State private var alertMessage: String?

    private let languages: [AppLanguageOption] = [
        AppLanguageOption(code: "zh_CN", displayCode: "zh-CN", nameKey: "language.zh"),
        AppLanguageOption(code: "en_US", displayCode: "en-US", nameKey: "language.en")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr("settings.appLanguageHint", locale: appState.locale))
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

                languageCard
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("settings.appLanguage", locale: appState.locale))
        .background(KiioTheme.background.ignoresSafeArea())
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var languageCard: some View {
        KiioCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(languages) { language in
                    Button {
                        updateLocale(language.code)
                    } label: {
                        SettingsMenuRow(
                            icon: "globe",
                            title: L10n.tr(language.nameKey, locale: appState.locale),
                            subtitle: language.displayCode,
                            accessory: L10n.backendLocale(appState.locale) == language.code ? .checkmark : .none
                        )
                    }
                    .buttonStyle(.plain)

                    if language.id != languages.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }

    private func updateLocale(_ locale: String) {
        guard L10n.backendLocale(appState.locale) != locale else { return }

        appState.setLocale(locale)
        Task {
            await bootstrapStore.updateLanguagePreference(locale)
            if let errorMessage = bootstrapStore.errorMessage {
                alertMessage = errorMessage
            }
        }
    }
}

private struct AppLanguageOption: Identifiable {
    let code: String
    let displayCode: String
    let nameKey: String

    var id: String { code }
}

private struct SettingsPendingRow {
    let icon: String
    let titleKey: String
    let subtitleKey: String
}

private enum SettingsAccessory {
    case none
    case checkmark
    case chevron
    case badge(String)
}

private struct SettingsMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accessory: SettingsAccessory

    var body: some View {
        HStack(spacing: 12) {
            KiioIconBadge(systemImage: icon, size: 36, iconSize: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            accessoryView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .checkmark:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        case .badge(let text):
            KiioStatusBadge(text: text, tone: .muted)
        }
    }
}
