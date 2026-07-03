import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var isConfirmingSignOut = false
    @State private var isShowingAbout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                profileHeader
                proBanner
                menuGroup(
                    title: L10n.tr("profile.groups.assets", locale: appState.locale),
                    rows: assetRows
                )
                menuGroup(
                    title: L10n.tr("profile.groups.system", locale: appState.locale),
                    rows: systemRows
                )
                signOutButton
            }
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
        .alert(L10n.tr("profile.about", locale: appState.locale), isPresented: $isShowingAbout) {
            Button(L10n.tr("common.ok", locale: appState.locale), role: .cancel) {}
        } message: {
            Text(aboutMessage)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            KiioLogoView(size: 36)
            Text(L10n.tr("app.name", locale: appState.locale))
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(KiioTheme.secondaryText)
            Spacer()
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                    .frame(width: 40, height: 40)
                    .background(KiioTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(KiioTheme.border, lineWidth: 1)
                    )
            }
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(KiioTheme.accent)
                Text(initial)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 7) {
                Text(displayName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(L10n.tr("profile.id", locale: appState.locale, userId))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(1)

                    Text(roleText)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(KiioTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(KiioTheme.accentSoft)
                        .clipShape(Capsule())
                }
            }

            Spacer()
        }
        .padding(18)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }

    private var proBanner: some View {
        NavigationLink {
            SubscriptionView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "crown")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(KiioTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("profile.proTitle", locale: appState.locale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr("profile.proDesc", locale: appState.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 5) {
                    Text(L10n.tr("profile.manageSubscription", locale: appState.locale))
                        .font(.system(size: 11, weight: .bold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(KiioTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(KiioTheme.accentSoft)
                .clipShape(Capsule())
            }
            .padding(16)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var assetRows: [ProfileMenuRowData] {
        [
            ProfileMenuRowData(
                icon: "receipt",
                title: L10n.tr("profile.orders", locale: appState.locale),
                subtitle: L10n.tr("profile.ordersSub", locale: appState.locale),
                destination: .orders
            )
        ]
    }

    private var systemRows: [ProfileMenuRowData] {
        [
            ProfileMenuRowData(
                icon: "shield",
                title: L10n.tr("profile.accountSecurity", locale: appState.locale),
                subtitle: L10n.tr("profile.settingsSubtitle", locale: appState.locale),
                destination: .settings
            ),
            ProfileMenuRowData(
                icon: "info.circle",
                title: L10n.tr("profile.about", locale: appState.locale),
                subtitle: "\(serviceName) \(versionText)",
                destination: .about,
                badgeText: versionText
            )
        ]
    }

    private func menuGroup(title: String, rows: [ProfileMenuRowData]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(rows) { row in
                    switch row.destination {
                    case .orders:
                        NavigationLink { OrdersPlaceholderView() } label: { ProfileMenuRow(row: row) }
                            .buttonStyle(.plain)
                    case .settings:
                        NavigationLink { SettingsView() } label: { ProfileMenuRow(row: row) }
                            .buttonStyle(.plain)
                    case .about:
                        Button {
                            isShowingAbout = true
                        } label: {
                            ProfileMenuRow(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var signOutButton: some View {
        Button {
            isConfirmingSignOut = true
        } label: {
            Text(L10n.tr("profile.signOut", locale: appState.locale))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.danger)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(KiioTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private var roleText: String {
        user?.superAdmin == 1
            ? L10n.tr("profile.role.admin", locale: appState.locale)
            : L10n.tr("profile.role.user", locale: appState.locale)
    }

    private var serviceName: String {
        bootstrapStore.publicConfig?.name?.isEmpty == false
            ? bootstrapStore.publicConfig!.name!
            : L10n.tr("app.name", locale: appState.locale)
    }

    private var versionText: String {
        bootstrapStore.publicConfig?.version?.isEmpty == false
            ? bootstrapStore.publicConfig!.version!
            : "1.0.0"
    }

    private var aboutMessage: String {
        "\(serviceName)\n\(L10n.tr("profile.currentVersion", locale: appState.locale)) \(versionText)"
    }

    private func signOut() {
        authStore.logout()
        bootstrapStore.reset()
        appState.showAuth()
    }
}

private struct ProfileMenuRow: View {
    let row: ProfileMenuRowData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 38, height: 38)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(row.subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            if row.destination != .about {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KiioTheme.mutedText)
            } else {
                Text(row.badgeText ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KiioTheme.mutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(KiioTheme.accentSoft)
                    .clipShape(Capsule())
            }
        }
        .padding(15)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }
}

private struct ProfileMenuRowData: Identifiable {
    let icon: String
    let title: String
    let subtitle: String
    let destination: ProfileMenuDestination
    var badgeText: String? = nil

    var id: String { title }
}

private enum ProfileMenuDestination: Equatable {
    case orders
    case settings
    case about
}

private struct OrdersPlaceholderView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                KiioCard {
                    HStack(alignment: .top, spacing: 14) {
                        KiioIconBadge(systemImage: "receipt", size: 52, iconSize: 22)
                        VStack(alignment: .leading, spacing: 7) {
                            KiioStatusBadge(text: L10n.tr("common.soon", locale: appState.locale), tone: .muted)
                            Text(L10n.tr("orders.empty.title", locale: appState.locale))
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(KiioTheme.text)
                            Text(L10n.tr("orders.empty.message", locale: appState.locale))
                                .font(.system(size: 14))
                                .foregroundStyle(KiioTheme.secondaryText)
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("orders.title", locale: appState.locale))
    }
}
