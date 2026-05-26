import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var isConfirmingSignOut = false

    var body: some View {
        List {
            Section(L10n.tr("settings.account", locale: appState.locale)) {
                HStack(spacing: 12) {
                    Text(initial)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(KiioTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(KiioTheme.text)
                            .lineLimit(1)
                        Text(L10n.tr("profile.id", locale: appState.locale, userId))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Button(role: .destructive) {
                    isConfirmingSignOut = true
                } label: {
                    HStack {
                        Text(L10n.tr("profile.signOut", locale: appState.locale))
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }

            Section(L10n.tr("settings.language", locale: appState.locale)) {
                Button {
                    updateLocale("zh_CN")
                } label: {
                    settingRow(title: L10n.tr("language.zh", locale: appState.locale), value: appState.locale == "zh_CN")
                }

                Button {
                    updateLocale("en_US")
                } label: {
                    settingRow(title: L10n.tr("language.en", locale: appState.locale), value: appState.locale == "en_US")
                }
            }

            Section(L10n.tr("settings.about", locale: appState.locale)) {
                HStack {
                    Text(L10n.tr("common.api", locale: appState.locale))
                    Spacer()
                    Text(AppConfig.apiBaseURL.absoluteString)
                        .foregroundStyle(KiioTheme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text(L10n.tr("common.version", locale: appState.locale))
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(KiioTheme.secondaryText)
                }
            }
        }
        .navigationTitle(L10n.tr("settings.title", locale: appState.locale))
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.insetGrouped)
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

    private func updateLocale(_ locale: String) {
        appState.setLocale(locale)
        Task {
            await bootstrapStore.updateLanguagePreference(locale)
        }
    }

    private func settingRow(title: String, value: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if value {
                Image(systemName: "checkmark")
                    .foregroundStyle(KiioTheme.accent)
            }
        }
    }

    private var user: UserDetail? {
        bootstrapStore.userInfo ?? authStore.currentUser
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
