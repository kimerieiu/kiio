import SwiftUI

struct InviteView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var activeRoute: DeviceRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    companionCard
                    nextSteps
                }
                .padding(24)
            }
            .background(KiioTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                actions
                    .padding(20)
                    .background(KiioTheme.background.opacity(0.96))
            }
            .navigationDestination(isPresented: routeBinding) {
                switch activeRoute {
                case .some(.provisioning):
                    DeviceProvisioningGuideView {
                        activeRoute = .pairing
                    }
                case .some(.pairing):
                    DevicePairingGuideView {
                        appState.showMain(selectedTab: .home)
                    }
                case .some(.agentLanguage):
                    AgentLanguagePreferenceView()
                case .none:
                    EmptyView()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            KiioLogoView(size: 58)

            VStack(alignment: .leading, spacing: 9) {
                Text(L10n.tr("invite.title", locale: appState.locale))
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(L10n.tr("invite.subtitle", locale: appState.locale))
                    .font(.system(size: 15))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineSpacing(4)
            }
        }
        .padding(.top, 18)
    }

    private var companionCard: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(KiioTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("invite.companionTitle", locale: appState.locale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(companionSummary)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(3)
                }

                Spacer()
            }
        }
    }

    private var nextSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("invite.nextSteps", locale: appState.locale))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
                .padding(.horizontal, 4)

            stepRow(
                icon: "wifi",
                title: L10n.tr("invite.step.setup.title", locale: appState.locale),
                subtitle: L10n.tr("invite.step.setup.subtitle", locale: appState.locale)
            )
            stepRow(
                icon: "number.square",
                title: L10n.tr("invite.step.bind.title", locale: appState.locale),
                subtitle: L10n.tr("invite.step.bind.subtitle", locale: appState.locale)
            )
            stepRow(
                icon: "house",
                title: L10n.tr("invite.step.explore.title", locale: appState.locale),
                subtitle: L10n.tr("invite.step.explore.subtitle", locale: appState.locale)
            )
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            KiioPrimaryButton(title: L10n.tr("invite.addDevice", locale: appState.locale)) {
                activeRoute = .provisioning
            }

            KiioSecondaryButton(title: L10n.tr("invite.browseFirst", locale: appState.locale)) {
                appState.showMain(selectedTab: .home)
            }
        }
    }

    private func stepRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 38, height: 38)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineSpacing(3)
            }

            Spacer()
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var companionSummary: String {
        if bootstrapStore.agents.isEmpty {
            return L10n.tr("invite.companionPending", locale: appState.locale)
        }
        return L10n.tr(
            "invite.companionSummary",
            locale: appState.locale,
            bootstrapStore.agents.count,
            bootstrapStore.devices.count
        )
    }

    private var routeBinding: Binding<Bool> {
        Binding(
            get: { activeRoute != nil },
            set: { isPresented in
                if !isPresented {
                    activeRoute = nil
                }
            }
        )
    }
}
