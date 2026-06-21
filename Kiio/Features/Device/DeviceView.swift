import SwiftUI

struct DeviceView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var syncStore: SyncStore

    @State private var isShowingAddSheet = false
    @State private var activeRoute: DeviceRoute?
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if bootstrapStore.isLoading && bootstrapStore.agents.isEmpty && bootstrapStore.devices.isEmpty {
                    loadingState
                } else if bootstrapStore.agents.isEmpty {
                    noAgentState
                } else {
                    dashboardContent
                }
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await bootstrapStore.refresh()
        }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .device else { return }
            Task { await refreshDevicesFromBackend(version: event?.version) }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            DeviceAddActionSheet(
                onProvisioning: { navigate(.provisioning) },
                onAgentLanguage: { navigate(.agentLanguage) },
                onCancel: { isShowingAddSheet = false }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: routeBinding) {
            switch activeRoute {
            case .some(.provisioning):
                DeviceProvisioningGuideView {
                    activeRoute = .pairing
                }
            case .some(.pairing):
                DevicePairingGuideView {
                    activeRoute = nil
                }
            case .some(.agentLanguage):
                AgentLanguagePreferenceView()
            case .none:
                EmptyView()
            }
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("device.title", locale: appState.locale))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("device.dashboard.subtitle", locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
            }

            Spacer()

            Button {
                isShowingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .frame(width: 40, height: 40)
                    .background(KiioTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
    }

    private var loadingState: some View {
        KiioCard {
            HStack(spacing: 12) {
                ProgressView()
                Text(L10n.tr("device.loading", locale: appState.locale))
                    .foregroundStyle(KiioTheme.secondaryText)
            }
        }
    }

    private var noAgentState: some View {
        KiioCard {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                Text(L10n.tr("device.noAgentTitle", locale: appState.locale))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("device.noAgentDesc", locale: appState.locale))
                    .font(.system(size: 14))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineSpacing(3)
            }
        }
    }

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let mainDevice {
                NavigationLink {
                    DeviceDetailView(device: mainDevice)
                } label: {
                    DeviceHeroCard(device: mainDevice)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    activeRoute = .provisioning
                } label: {
                    DeviceEmptyHeroCard()
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                DeviceMetricCard(
                    icon: "dot.radiowaves.left.and.right",
                    title: L10n.tr("device.boundCompanions", locale: appState.locale),
                    value: L10n.tr("device.count", locale: appState.locale, bootstrapStore.devices.count)
                )
                DeviceMetricCard(
                    icon: "clock.arrow.circlepath",
                    title: L10n.tr("device.latestConnection", locale: appState.locale),
                    value: latestConnectionText
                )
            }

            menuList
        }
    }

    private var menuList: some View {
        VStack(spacing: 10) {
            NavigationLink {
                DeviceListView()
            } label: {
                DeviceMenuRow(
                    icon: "list.bullet",
                    title: L10n.tr("device.allCompanions", locale: appState.locale),
                    subtitle: L10n.tr("device.manageCompanions", locale: appState.locale, bootstrapStore.devices.count),
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)

            if let mainDevice {
                NavigationLink {
                    DeviceDetailView(device: mainDevice)
                } label: {
                    DeviceMenuRow(
                        icon: "wifi",
                        title: L10n.tr("device.network", locale: appState.locale),
                        subtitle: DeviceConnectionHelper.formatLastConnected(mainDevice.lastConnectedAt, locale: appState.locale),
                        accessory: DeviceConnectionHelper.isRecentlyConnected(mainDevice) ? .chevron : .badge(L10n.tr("device.needsCheck", locale: appState.locale))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    activeRoute = .provisioning
                } label: {
                    DeviceMenuRow(
                        icon: "wifi",
                        title: L10n.tr("device.network", locale: appState.locale),
                        subtitle: L10n.tr("device.noConnection", locale: appState.locale),
                        accessory: .chevron
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await toggleAutoUpdate() }
            } label: {
                DeviceMenuRow(
                    icon: "bolt",
                    title: L10n.tr("device.autoUpdate", locale: appState.locale),
                    subtitle: autoUpdateText,
                    accessory: .switchOn(mainDevice?.autoUpdate == 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(mainDevice == nil || deviceStore.isUpdating)
        }
    }

    private var mainDevice: DeviceDTO? {
        DeviceConnectionHelper.latestDevice(from: bootstrapStore.devices)
    }

    private var latestConnectionText: String {
        guard let device = mainDevice else {
            return L10n.tr("device.neverConnected", locale: appState.locale)
        }
        return DeviceConnectionHelper.formatLastConnected(device.lastConnectedAt, locale: appState.locale)
    }

    private var autoUpdateText: String {
        guard let mainDevice else {
            return L10n.tr("device.noConnection", locale: appState.locale)
        }
        return mainDevice.autoUpdate == 1
            ? L10n.tr("device.autoUpdateOn", locale: appState.locale)
            : L10n.tr("device.autoUpdateOff", locale: appState.locale)
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

    private func navigate(_ destination: DeviceRoute) {
        isShowingAddSheet = false
        DispatchQueue.main.async {
            activeRoute = destination
        }
    }

    private func toggleAutoUpdate() async {
        guard let mainDevice else { return }
        let nextValue = mainDevice.autoUpdate == 1 ? 0 : 1
        if !(await deviceStore.updateDevice(id: mainDevice.id, autoUpdate: nextValue)) {
            alertMessage = deviceStore.errorMessage
        }
    }

    private func refreshDevicesFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.device, incomingVersion: version)
        guard await bootstrapStore.refresh() else {
            if let error = bootstrapStore.errorMessage {
                alertMessage = error
            }
            return
        }
        syncStore.markSynced(.device, version: targetVersion)
        if syncStore.hasRemoteVersion(.device, after: targetVersion) {
            await refreshDevicesFromBackend()
        }
    }
}

private struct DeviceAddActionSheet: View {
    @EnvironmentObject private var appState: AppState
    let onProvisioning: () -> Void
    let onAgentLanguage: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(KiioTheme.mutedText.opacity(0.25))
                .frame(width: 42, height: 4)
                .padding(.top, 8)

            Button(action: onProvisioning) {
                sheetRow(
                    icon: "plus",
                    title: L10n.tr("device.addCompanion", locale: appState.locale),
                    subtitle: L10n.tr("device.addCompanionSub", locale: appState.locale)
                )
            }
            .buttonStyle(.plain)

            Button(action: onAgentLanguage) {
                sheetRow(
                    icon: "globe",
                    title: L10n.tr("settings.agentLanguage", locale: appState.locale),
                    subtitle: L10n.tr("settings.agentLanguageSub", locale: appState.locale)
                )
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Text(L10n.tr("common.cancel", locale: appState.locale))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(KiioTheme.background.ignoresSafeArea())
    }

    private func sheetRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 38, height: 38)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(14)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct DeviceHeroCard: View {
    @EnvironmentObject private var appState: AppState
    let device: DeviceDTO

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                DeviceStatusPill(
                    text: DeviceConnectionHelper.isRecentlyConnected(device)
                    ? L10n.tr("device.recentlyOnline", locale: appState.locale)
                    : L10n.tr("device.bound", locale: appState.locale),
                    isOnline: DeviceConnectionHelper.isRecentlyConnected(device)
                )

                Text(device.displayName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.system(size: 13, weight: .semibold))
                    Text(DeviceConnectionHelper.formatLastConnected(device.lastConnectedAt, locale: appState.locale))
                        .font(.system(size: 13))
                }
                .foregroundStyle(KiioTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 86, height: 86)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

private struct DeviceEmptyHeroCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                DeviceStatusPill(text: L10n.tr("device.unbound", locale: appState.locale), isOnline: false)
                Text(L10n.tr("device.addFirstCompanion", locale: appState.locale))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("device.addFirstDesc", locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineSpacing(3)
            }

            Spacer()

            Image(systemName: "plus")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 82, height: 82)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

private struct DeviceStatusPill: View {
    let text: String
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isOnline ? KiioTheme.success : KiioTheme.mutedText)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(KiioTheme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(KiioTheme.background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(KiioTheme.border, lineWidth: 1))
    }
}

private struct DeviceMetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(KiioTheme.accent)

            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KiioTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }
}

private enum DeviceMenuAccessory {
    case chevron
    case badge(String)
    case switchOn(Bool)
}

private struct DeviceMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let accessory: DeviceMenuAccessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 38, height: 38)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
            accessoryView
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        case .badge(let text):
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(KiioTheme.danger)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(KiioTheme.danger.opacity(0.1))
                .clipShape(Capsule())
        case .switchOn(let isOn):
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? KiioTheme.accent : KiioTheme.mutedText.opacity(0.25))
                Circle()
                    .fill(.white)
                    .padding(3)
            }
            .frame(width: 44, height: 26)
        }
    }
}

private struct DeviceDetailHeroCard: View {
    @EnvironmentObject private var appState: AppState
    let device: DeviceDTO
    let isPrimary: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(width: 74, height: 74)
                    .background(KiioTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))

                Circle()
                    .fill(DeviceConnectionHelper.isRecentlyConnected(device) ? KiioTheme.success : KiioTheme.mutedText)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(KiioTheme.background, lineWidth: 3))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(device.displayName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if isPrimary {
                        Text(L10n.tr("device.list.primary", locale: appState.locale))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(KiioTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                DeviceStatusPill(
                    text: DeviceConnectionHelper.isRecentlyConnected(device)
                    ? L10n.tr("device.recentlyOnline", locale: appState.locale)
                    : L10n.tr("device.bound", locale: appState.locale),
                    isOnline: DeviceConnectionHelper.isRecentlyConnected(device)
                )

                Text(DeviceConnectionHelper.formatLastConnected(device.lastConnectedAt, locale: appState.locale))
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

private struct DeviceDetailMetricCard: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(KiioTheme.secondaryText)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(KiioTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }
}

struct DeviceDetailView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let device: DeviceDTO

    @State private var currentDevice: DeviceDTO
    @State private var isShowingRename = false
    @State private var isConfirmingUnbind = false
    @State private var activeRoute: DeviceRoute?
    @State private var isRefreshingStatus = false
    @State private var aliasDraft = ""
    @State private var alertMessage: String?

    init(device: DeviceDTO) {
        self.device = device
        _currentDevice = State(initialValue: device)
    }

    var body: some View {
        List {
            Section {
                DeviceDetailHeroCard(
                    device: currentDevice,
                    isPrimary: currentDevice.id == DeviceConnectionHelper.latestDevice(from: bootstrapStore.devices)?.id
                )
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))

            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    DeviceDetailMetricCard(
                        icon: "cpu",
                        title: L10n.tr("device.board", locale: appState.locale),
                        value: DeviceConnectionHelper.boardText(currentDevice)
                    )
                    DeviceDetailMetricCard(
                        icon: "bolt",
                        title: L10n.tr("device.version", locale: appState.locale),
                        value: DeviceConnectionHelper.versionText(currentDevice)
                    )
                    DeviceDetailMetricCard(
                        icon: "gearshape",
                        title: L10n.tr("device.autoUpdate", locale: appState.locale),
                        value: currentDevice.autoUpdate == 1
                        ? L10n.tr("device.enabled", locale: appState.locale)
                        : L10n.tr("device.disabled", locale: appState.locale)
                    )
                    DeviceDetailMetricCard(
                        icon: "clock.arrow.circlepath",
                        title: L10n.tr("device.latestConnection", locale: appState.locale),
                        value: DeviceConnectionHelper.formatLastConnected(currentDevice.lastConnectedAt, locale: appState.locale)
                    )
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))

            Section(L10n.tr("device.identity", locale: appState.locale)) {
                labeled(L10n.tr("device.name", locale: appState.locale), currentDevice.displayName)
                labeled(L10n.tr("device.id", locale: appState.locale), currentDevice.id)
                labeled(L10n.tr("device.mac", locale: appState.locale), currentDevice.macAddress ?? "--")
                labeled(L10n.tr("device.board", locale: appState.locale), currentDevice.board ?? "--")
            }

            Section(L10n.tr("device.firmware", locale: appState.locale)) {
                labeled(L10n.tr("device.version", locale: appState.locale), currentDevice.appVersion ?? "--")
                labeled(
                    L10n.tr("device.autoUpdate", locale: appState.locale),
                    currentDevice.autoUpdate == 1
                    ? L10n.tr("device.enabled", locale: appState.locale)
                    : L10n.tr("device.disabled", locale: appState.locale)
                )
            }

            Section(L10n.tr("device.settings", locale: appState.locale)) {
                Button {
                    aliasDraft = currentDevice.alias ?? currentDevice.displayName
                    isShowingRename = true
                } label: {
                    settingsRow(
                        icon: "pencil",
                        title: L10n.tr("device.rename", locale: appState.locale),
                        subtitle: currentDevice.alias ?? L10n.tr("device.renameHint", locale: appState.locale),
                        isLoading: deviceStore.isUpdating,
                        showsChevron: true
                    )
                }

                Button {
                    Task { await toggleAutoUpdate() }
                } label: {
                    settingsRow(
                        icon: "bolt",
                        title: L10n.tr("device.autoUpdate", locale: appState.locale),
                        subtitle: currentDevice.autoUpdate == 1
                        ? L10n.tr("device.autoUpdateOn", locale: appState.locale)
                        : L10n.tr("device.autoUpdateOff", locale: appState.locale),
                        isLoading: deviceStore.isUpdating
                    )
                }
                .disabled(deviceStore.isUpdating)

                Button {
                    activeRoute = .provisioning
                } label: {
                    settingsRow(
                        icon: "wifi",
                        title: L10n.tr("device.reProvision", locale: appState.locale),
                        subtitle: L10n.tr("device.reProvisionHint", locale: appState.locale),
                        showsChevron: true
                    )
                }

                Button {
                    Task { await refreshStatus() }
                } label: {
                    settingsRow(
                        icon: "arrow.clockwise",
                        title: L10n.tr("device.refreshStatus", locale: appState.locale),
                        subtitle: L10n.tr("device.refreshStatusHint", locale: appState.locale),
                        isLoading: isRefreshingStatus || bootstrapStore.isLoading
                    )
                }
                .disabled(isRefreshingStatus || bootstrapStore.isLoading)

                Button(role: .destructive) {
                    isConfirmingUnbind = true
                } label: {
                    settingsRow(
                        icon: "xmark.circle",
                        title: L10n.tr("device.unbind", locale: appState.locale),
                        subtitle: L10n.tr("device.unbindHint", locale: appState.locale),
                        isLoading: deviceStore.isUpdating
                    )
                }
                .disabled(deviceStore.isUpdating)
            }
        }
        .navigationTitle(currentDevice.displayName)
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .onChange(of: bootstrapStore.devices) { _ in
            syncCurrentDevice()
        }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .device else { return }
            Task { await refreshDevicesFromBackend(version: event?.version) }
        }
        .sheet(isPresented: $isShowingRename) {
            renameSheet
                .presentationDetents([.height(220)])
        }
        .navigationDestination(isPresented: routeBinding) {
            switch activeRoute {
            case .some(.provisioning):
                DeviceProvisioningGuideView {
                    activeRoute = .pairing
                }
            case .some(.pairing):
                DevicePairingGuideView {
                    activeRoute = nil
                }
            case .some(.agentLanguage):
                AgentLanguagePreferenceView()
            case .none:
                EmptyView()
            }
        }
        .confirmationDialog(
            L10n.tr("device.unbind", locale: appState.locale),
            isPresented: $isConfirmingUnbind,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("device.unbind", locale: appState.locale), role: .destructive) {
                Task { await unbind() }
            }
            Button(L10n.tr("common.cancel", locale: appState.locale), role: .cancel) {}
        } message: {
            Text(L10n.tr("device.unbindConfirm", locale: appState.locale, currentDevice.displayName))
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var renameSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField(L10n.tr("device.rename.placeholder", locale: appState.locale), text: $aliasDraft)
                    .kiioTextField()
                    .onChange(of: aliasDraft) { value in
                        aliasDraft = String(value.prefix(64))
                    }

                KiioPrimaryButton(
                    title: L10n.tr("common.save", locale: appState.locale),
                    isLoading: deviceStore.isUpdating,
                    isDisabled: aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    Task { await saveAlias() }
                }
            }
            .padding(20)
            .background(KiioTheme.background.ignoresSafeArea())
            .navigationTitle(L10n.tr("device.rename", locale: appState.locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel", locale: appState.locale)) {
                        isShowingRename = false
                    }
                }
            }
        }
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(KiioTheme.secondaryText)
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String, isLoading: Bool = false, showsChevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 34, height: 34)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(KiioTheme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()
            if isLoading {
                ProgressView()
            } else if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KiioTheme.mutedText)
            }
        }
    }

    private func saveAlias() async {
        let alias = aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !alias.isEmpty else { return }

        if await deviceStore.updateDevice(id: currentDevice.id, alias: alias) {
            currentDevice = patchedDevice(alias: alias)
            isShowingRename = false
            syncCurrentDevice()
        } else {
            alertMessage = deviceStore.errorMessage
        }
    }

    private func toggleAutoUpdate() async {
        let nextValue = currentDevice.autoUpdate == 1 ? 0 : 1

        if await deviceStore.updateDevice(id: currentDevice.id, autoUpdate: nextValue) {
            currentDevice = patchedDevice(autoUpdate: nextValue)
            syncCurrentDevice()
        } else {
            alertMessage = deviceStore.errorMessage
        }
    }

    private func refreshStatus() async {
        guard !isRefreshingStatus else { return }
        isRefreshingStatus = true
        defer { isRefreshingStatus = false }

        if await bootstrapStore.refresh() {
            syncCurrentDevice()
        } else if let error = bootstrapStore.errorMessage {
            alertMessage = error
        }
    }

    private func refreshDevicesFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.device, incomingVersion: version)
        guard await bootstrapStore.refresh() else {
            if let error = bootstrapStore.errorMessage {
                alertMessage = error
            }
            return
        }
        syncCurrentDevice()
        syncStore.markSynced(.device, version: targetVersion)
        if syncStore.hasRemoteVersion(.device, after: targetVersion) {
            await refreshDevicesFromBackend()
        }
    }

    private func unbind() async {
        if await deviceStore.unbindDevice(id: currentDevice.id) {
            dismiss()
        } else {
            alertMessage = deviceStore.errorMessage
        }
    }

    private func syncCurrentDevice() {
        if let refreshed = bootstrapStore.devices.first(where: { $0.id == currentDevice.id }) {
            currentDevice = refreshed
        }
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

    private func patchedDevice(alias: String? = nil, autoUpdate: Int? = nil) -> DeviceDTO {
        DeviceDTO(
            id: currentDevice.id,
            userId: currentDevice.userId,
            macAddress: currentDevice.macAddress,
            lastConnectedAt: currentDevice.lastConnectedAt,
            autoUpdate: autoUpdate ?? currentDevice.autoUpdate,
            board: currentDevice.board,
            alias: alias ?? currentDevice.alias,
            agentId: currentDevice.agentId,
            appVersion: currentDevice.appVersion,
            sort: currentDevice.sort,
            updateDate: currentDevice.updateDate,
            createDate: currentDevice.createDate
        )
    }
}
