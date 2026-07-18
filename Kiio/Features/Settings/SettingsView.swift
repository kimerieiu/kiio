import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                accountSection
                languageSection
                legalSection
                signOutButton
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

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            KiioSectionTitle(title: L10n.tr("settings.account", locale: appState.locale), icon: "person")

            KiioCard(padding: 0) {
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
        .disabled(authStore.isLoading)
    }

    private var currentAppLanguageSubtitle: String {
        L10n.tr("settings.appLanguageSub", locale: appState.locale, appLanguageName(for: appState.locale))
    }

    private func appLanguageName(for locale: String) -> String {
        let language = SupportedLanguage.option(for: locale)
        return L10n.tr(language.appNameKey, locale: appState.locale)
    }

    private func signOut() {
        authStore.logout()
        bootstrapStore.reset()
        appState.showAuth()
    }
}

private struct AccountSecurityView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingAccountDeletion = false
    @State private var accountDeletionError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
    @State private var isSaving = false

    private let languages = SupportedLanguage.all

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
                            title: L10n.tr(language.appNameKey, locale: appState.locale),
                            subtitle: language.displayCode,
                            accessory: L10n.backendLocale(appState.locale) == language.code ? .checkmark : .none
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)

                    if language.id != languages.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }

    private func updateLocale(_ locale: String) {
        let previousLocale = L10n.backendLocale(appState.locale)
        let requestedLocale = L10n.backendLocale(locale)
        guard previousLocale != requestedLocale, !isSaving else { return }

        isSaving = true
        appState.setLocale(requestedLocale)
        Task {
            let succeeded = await bootstrapStore.updateLanguagePreference(requestedLocale)
            isSaving = false

            if succeeded {
                appState.setLocale(bootstrapStore.preference?.language ?? requestedLocale)
            } else {
                appState.setLocale(previousLocale)
                alertMessage = bootstrapStore.errorMessage
            }
        }
    }
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
