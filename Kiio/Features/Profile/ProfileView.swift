import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var isConfirmingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                profileHeader
                companionBanner
                assetsCard
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
    }

    private var companionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 46, height: 46)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("profile.companionTitle", locale: appState.locale))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("home.summary", locale: appState.locale, bootstrapStore.agents.count, bootstrapStore.devices.count))
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(16)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var assetsCard: some View {
        HStack(spacing: 0) {
            NavigationLink {
                DeviceListView()
            } label: {
                assetMetric(
                    value: "\(bootstrapStore.agents.count)",
                    label: L10n.tr("profile.agents", locale: appState.locale)
                )
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(KiioTheme.mutedText.opacity(0.18))
                .frame(width: 1, height: 44)

            NavigationLink {
                DeviceListView()
            } label: {
                assetMetric(
                    value: "\(bootstrapStore.devices.count)",
                    label: L10n.tr("profile.devices", locale: appState.locale)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 18)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var assetRows: [ProfileMenuRowData] {
        [
            ProfileMenuRowData(
                icon: "dot.radiowaves.left.and.right",
                title: L10n.tr("device.allCompanions", locale: appState.locale),
                subtitle: L10n.tr("device.manageCompanions", locale: appState.locale, bootstrapStore.devices.count),
                destination: .devices
            ),
            ProfileMenuRowData(
                icon: "hanger",
                title: L10n.tr("profile.digitalCloset", locale: appState.locale),
                subtitle: L10n.tr("profile.digitalClosetSub", locale: appState.locale),
                destination: .outfit
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
                subtitle: "Kiio v1.0.0",
                destination: .about
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
                    case .devices:
                        NavigationLink { DeviceListView() } label: { ProfileMenuRow(row: row) }
                            .buttonStyle(.plain)
                    case .outfit:
                        NavigationLink { OutfitView() } label: { ProfileMenuRow(row: row) }
                            .buttonStyle(.plain)
                    case .settings:
                        NavigationLink { SettingsView() } label: { ProfileMenuRow(row: row) }
                            .buttonStyle(.plain)
                    case .about:
                        ProfileMenuRow(row: row)
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

    private func assetMetric(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(KiioTheme.text)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KiioTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
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
                Text("1.0.0")
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
    }
}

private struct ProfileMenuRowData: Identifiable {
    let icon: String
    let title: String
    let subtitle: String
    let destination: ProfileMenuDestination

    var id: String { title }
}

private enum ProfileMenuDestination: Equatable {
    case devices
    case outfit
    case settings
    case about
}
