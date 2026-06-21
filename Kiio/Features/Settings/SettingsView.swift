import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var isConfirmingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
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
        VStack(alignment: .leading, spacing: 10) {
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
        VStack(alignment: .leading, spacing: 10) {
            KiioSectionTitle(title: L10n.tr("settings.language", locale: appState.locale), icon: "globe")

            KiioCard(padding: 0) {
                languageButton(
                    title: L10n.tr("language.zh", locale: appState.locale),
                    subtitle: "zh-CN",
                    locale: "zh_CN"
                )

                Divider()
                    .padding(.leading, 64)

                languageButton(
                    title: L10n.tr("language.en", locale: appState.locale),
                    subtitle: "en-US",
                    locale: "en_US"
                )

                Divider()
                    .padding(.leading, 64)

                NavigationLink {
                    AgentLanguagePreferenceView()
                } label: {
                    SettingsMenuRow(
                        icon: "sparkles",
                        title: L10n.tr("settings.agentLanguage", locale: appState.locale),
                        subtitle: L10n.tr("settings.agentLanguageSub", locale: appState.locale),
                        accessory: .chevron
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pendingSection(title: String, rows: [SettingsPendingRow]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KiioSectionTitle(title: title)
            KiioCard(padding: 0) {
                ForEach(rows.indices, id: \.self) { index in
                    SettingsMenuRow(
                        icon: rows[index].icon,
                        title: L10n.tr(rows[index].titleKey, locale: appState.locale),
                        subtitle: L10n.tr(rows[index].subtitleKey, locale: appState.locale),
                        accessory: .badge(L10n.tr("common.soon", locale: appState.locale))
                    )

                    if index != rows.count - 1 {
                        Divider()
                            .padding(.leading, 64)
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

    private func languageButton(title: String, subtitle: String, locale: String) -> some View {
        Button {
            updateLocale(locale)
        } label: {
            SettingsMenuRow(
                icon: "globe",
                title: title,
                subtitle: subtitle,
                accessory: appState.locale == locale ? .checkmark : .none
            )
        }
        .buttonStyle(.plain)
    }

    private func updateLocale(_ locale: String) {
        appState.setLocale(locale)
        Task {
            await bootstrapStore.updateLanguagePreference(locale)
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
            KiioIconBadge(systemImage: icon, size: 40, iconSize: 15)

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
        .padding(16)
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
