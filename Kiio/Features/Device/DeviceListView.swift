import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var syncStore: SyncStore

    @State private var sortMode: DeviceListSortMode = .recent
    @State private var activeRoute: DeviceRoute?
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                subtitle

                if bootstrapStore.isLoading && bootstrapStore.devices.isEmpty {
                    loadingState
                } else if bootstrapStore.agents.isEmpty {
                    noAgentState
                } else if sortedDevices.isEmpty {
                    emptyState
                } else {
                    if !onlineDevices.isEmpty {
                        deviceSection(
                            title: L10n.tr("device.list.online", locale: appState.locale),
                            devices: onlineDevices
                        )
                    }
                    if !offlineDevices.isEmpty {
                        deviceSection(
                            title: onlineDevices.isEmpty
                            ? L10n.tr("device.bound", locale: appState.locale)
                            : L10n.tr("device.list.offline", locale: appState.locale),
                            devices: offlineDevices
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("device.list.title", locale: appState.locale))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        activeRoute = .provisioning
                    } label: {
                        Label(L10n.tr("device.addCompanion", locale: appState.locale), systemImage: "plus")
                    }

                    Button {
                        sortMode = sortMode == .recent ? .name : .recent
                    } label: {
                        Label(sortActionTitle, systemImage: "arrow.up.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .refreshable {
            await bootstrapStore.refresh()
        }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .device else { return }
            Task { await refreshDevicesFromBackend(version: event?.version) }
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

    private var subtitle: some View {
        Text(L10n.tr("device.list.total", locale: appState.locale, bootstrapStore.devices.count))
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(KiioTheme.secondaryText)
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
        KiioEmptyStateView(
            systemImage: "dot.radiowaves.left.and.right",
            title: L10n.tr("device.noAgentTitle", locale: appState.locale),
            message: L10n.tr("device.noAgentDesc", locale: appState.locale)
        )
    }

    private var emptyState: some View {
        Button {
            activeRoute = .provisioning
        } label: {
            KiioEmptyStateView(
                systemImage: "plus",
                title: L10n.tr("device.list.emptyTitle", locale: appState.locale),
                message: L10n.tr("device.list.emptyDesc", locale: appState.locale)
            )
        }
        .buttonStyle(.plain)
    }

    private func deviceSection(title: String, devices: [DeviceDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(KiioTheme.text)

            VStack(spacing: 12) {
                ForEach(devices) { device in
                    NavigationLink {
                        DeviceDetailView(device: device)
                    } label: {
                        DeviceListCard(
                            device: device,
                            isPrimary: device.id == primaryDevice?.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sortedDevices: [DeviceDTO] {
        DeviceConnectionHelper.sortedDevices(bootstrapStore.devices, mode: sortMode)
    }

    private var onlineDevices: [DeviceDTO] {
        sortedDevices.filter { DeviceConnectionHelper.isRecentlyConnected($0) }
    }

    private var offlineDevices: [DeviceDTO] {
        sortedDevices.filter { !DeviceConnectionHelper.isRecentlyConnected($0) }
    }

    private var primaryDevice: DeviceDTO? {
        DeviceConnectionHelper.latestDevice(from: bootstrapStore.devices)
    }

    private var sortActionTitle: String {
        sortMode == .recent
            ? L10n.tr("device.list.sortByName", locale: appState.locale)
            : L10n.tr("device.list.sortByRecent", locale: appState.locale)
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

private struct DeviceListCard: View {
    @EnvironmentObject private var appState: AppState
    let device: DeviceDTO
    let isPrimary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(KiioTheme.accent)
                        .frame(width: 58, height: 58)
                        .background(KiioTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Circle()
                        .fill(isOnline ? KiioTheme.success : KiioTheme.mutedText)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(KiioTheme.surface, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(device.displayName)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(KiioTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if isPrimary {
                            Text(L10n.tr("device.list.primary", locale: appState.locale))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(KiioTheme.accent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(KiioTheme.accentSoft)
                                .clipShape(Capsule())
                        }
                    }

                    Text(isOnline ? L10n.tr("device.recentlyOnline", locale: appState.locale) : L10n.tr("device.bound", locale: appState.locale))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isOnline ? KiioTheme.success : KiioTheme.secondaryText)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KiioTheme.mutedText)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 8)], alignment: .leading, spacing: 8) {
                metaTag(icon: "cpu", text: DeviceConnectionHelper.boardText(device))
                metaTag(icon: "clock", text: DeviceConnectionHelper.formatLastConnected(device.lastConnectedAt, locale: appState.locale))
                metaTag(icon: "bolt", text: device.autoUpdate == 1 ? L10n.tr("device.list.autoOta", locale: appState.locale) : L10n.tr("device.list.manualUpdate", locale: appState.locale))
            }

            HStack {
                Text(DeviceConnectionHelper.identityText(device))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KiioTheme.mutedText)
                    .lineLimit(1)
                Spacer()
                Text(DeviceConnectionHelper.versionText(device))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KiioTheme.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isPrimary ? KiioTheme.accent.opacity(0.5) : KiioTheme.border, lineWidth: 1)
        )
    }

    private var isOnline: Bool {
        DeviceConnectionHelper.isRecentlyConnected(device)
    }

    private func metaTag(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(KiioTheme.secondaryText)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.background)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(KiioTheme.border, lineWidth: 1))
    }
}
