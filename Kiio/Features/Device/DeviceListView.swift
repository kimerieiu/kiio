import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var syncStore: SyncStore

    @State private var sortMode: DeviceListSortMode = .recent
    @State private var isShowingActionMenu = false
    @State private var activeRoute: DeviceRoute?
    @State private var alertMessage: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            if isShowingActionMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeActionMenu()
                    }
                    .zIndex(1)

                DeviceListActionMenu(
                    addTitle: L10n.tr("device.addCompanion", locale: appState.locale),
                    sortTitle: sortActionTitle,
                    onAdd: {
                        closeActionMenu()
                        activeRoute = .provisioning
                    },
                    onSort: {
                        closeActionMenu()
                        sortMode = sortMode == .recent ? .name : .recent
                    }
                )
                .padding(.top, 8)
                .padding(.trailing, 16)
                .transition(.scale(scale: 0.96, anchor: .topTrailing).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("device.list.title", locale: appState.locale))
        .kiioHidesTabBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    toggleActionMenu()
                } label: {
                    Image(systemName: isShowingActionMenu ? "xmark.circle.fill" : "ellipsis.circle")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(KiioTheme.text)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("device.list.actions", locale: appState.locale))
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
                .kiioHidesTabBar()
            case .some(.pairing):
                DevicePairingGuideView {
                    activeRoute = nil
                }
                .kiioHidesTabBar()
            case .some(.agentLanguage):
                AgentLanguagePreferenceView()
                    .kiioHidesTabBar()
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
                            .kiioHidesTabBar()
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

    private func toggleActionMenu() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            isShowingActionMenu.toggle()
        }
    }

    private func closeActionMenu() {
        guard isShowingActionMenu else { return }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.86)) {
            isShowingActionMenu = false
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

private struct DeviceListActionMenu: View {
    let addTitle: String
    let sortTitle: String
    let onAdd: () -> Void
    let onSort: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            actionButton(icon: "plus", title: addTitle, action: onAdd)
            actionButton(icon: "arrow.up.arrow.down", title: sortTitle, action: onSort)
        }
        .padding(8)
        .frame(width: 232)
        .background(KiioTheme.text)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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
