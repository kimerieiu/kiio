import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                accountCard
                languageSection
                legalSection
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("settings.title", locale: appState.locale))
        .kiioHidesTabBar()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                KiioBackButton {
                    dismiss()
                }
            }
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .refreshable {
            await bootstrapStore.refresh()
            authStore.updateUser(bootstrapStore.userInfo)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: L10n.tr("settings.account", locale: appState.locale), icon: "person")

            KiioCard(padding: 0) {
                VStack(spacing: 0) {
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
                    .padding(16)

                    Divider()
                        .padding(.leading, 16)

                    NavigationLink {
                        AccountSecurityView()
                            .kiioHidesTabBar()
                    } label: {
                        SettingsMenuRow(
                            icon: "lock.shield",
                            title: L10n.tr("profile.accountSecurity", locale: appState.locale),
                            subtitle: L10n.tr("settings.securitySub", locale: appState.locale),
                            accessory: .chevron
                        )
                    }
                    .buttonStyle(.plain)
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
                        .kiioHidesTabBar()
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

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(
                title: L10n.tr("settings.legal", locale: appState.locale),
                icon: "checkmark.shield"
            )

            KiioCard(padding: 0) {
                NavigationLink {
                    LegalCenterView()
                } label: {
                    SettingsMenuRow(
                        icon: "checkmark.shield",
                        title: L10n.tr("legal.center.title", locale: appState.locale),
                        subtitle: L10n.tr("legal.center.subtitle", locale: appState.locale),
                        accessory: .chevron
                    )
                }
                .buttonStyle(.plain)
            }
        }
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
}

private struct AccountSecurityView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingSignOut = false
    @State private var isConfirmingAccountDeletion = false
    @State private var accountDeletionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sessionSection
                accountDeletionSection
            }
            .padding(20)
        }
        .navigationTitle(L10n.tr("profile.accountSecurity", locale: appState.locale))
        .kiioHidesTabBar()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                KiioBackButton {
                    dismiss()
                }
            }
        }
        .background(KiioTheme.background.ignoresSafeArea())
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
        .confirmationDialog(
            L10n.tr("settings.deleteAccountConfirmTitle", locale: appState.locale),
            isPresented: $isConfirmingAccountDeletion,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("settings.deleteAccountAction", locale: appState.locale), role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            Button(L10n.tr("common.cancel", locale: appState.locale), role: .cancel) {}
        } message: {
            Text(L10n.tr("settings.deleteAccountConfirmMessage", locale: appState.locale))
        }
        .kiioErrorAlert(message: $accountDeletionError, locale: appState.locale)
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(
                title: L10n.tr("settings.session", locale: appState.locale),
                icon: "key"
            )

            KiioCard(padding: 0) {
                Button {
                    isConfirmingSignOut = true
                } label: {
                    SettingsMenuRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: L10n.tr("profile.signOut", locale: appState.locale),
                        subtitle: L10n.tr("profile.signOutSubtitle", locale: appState.locale),
                        accessory: .none
                    )
                }
                .buttonStyle(.plain)
                .disabled(authStore.isLoading)
            }
        }
    }

    private var accountDeletionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(
                title: L10n.tr("settings.dangerZone", locale: appState.locale),
                icon: "exclamationmark.triangle"
            )

            Button {
                isConfirmingAccountDeletion = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KiioTheme.danger)
                        .frame(width: 40, height: 40)
                        .background(KiioTheme.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            authStore.isLoading
                                ? L10n.tr("settings.deletingAccount", locale: appState.locale)
                                : L10n.tr("settings.deleteAccount", locale: appState.locale)
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KiioTheme.danger)

                        Text(L10n.tr("settings.deleteAccountSub", locale: appState.locale))
                            .font(.system(size: 12))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    if authStore.isLoading {
                        ProgressView()
                            .tint(KiioTheme.danger)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(KiioTheme.mutedText)
                    }
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KiioTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(KiioTheme.danger.opacity(0.24), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(authStore.isLoading)
        }
    }

    private func signOut() {
        authStore.logout()
        bootstrapStore.reset()
        appState.showAuth()
    }

    private func deleteAccount() async {
        do {
            try await authStore.deleteAccount()
            bootstrapStore.reset()
            appState.showAuth()
        } catch {
            accountDeletionError = AppError.from(error).errorDescription
        }
    }
}

private struct AppLanguagePreferenceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss
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
        .kiioHidesTabBar()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                KiioBackButton {
                    dismiss()
                }
            }
        }
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

private enum SettingsAccessory {
    case none
    case checkmark
    case chevron
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
        }
    }
}
