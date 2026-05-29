import SwiftUI

struct OutfitView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        OutfitListScene(store: OutfitStore(service: dependencies.outfitService))
    }
}

private struct OutfitListScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: OutfitStore

    init(store: OutfitStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            Section {
                KiioCard(padding: 8, radius: 16) {
                    Picker("", selection: Binding(
                        get: { store.selectedFilter },
                        set: { filter in Task { await store.selectFilter(filter) } }
                    )) {
                        ForEach(OutfitFilter.allCases) { filter in
                            Text(filterTitle(filter))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .kiioListHeaderRow()
            }
            .listRowBackground(Color.clear)

            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if store.outfits.isEmpty {
                KiioEmptyStateView(
                    systemImage: "tshirt",
                    title: L10n.tr("outfit.empty.title", locale: appState.locale),
                    message: L10n.tr("outfit.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                ForEach(store.outfits) { outfit in
                    NavigationLink {
                        OutfitDetailView(outfitId: outfit.id, store: store)
                    } label: {
                        OutfitRow(outfit: outfit)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(outfit) }
                        } label: {
                            Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                        }
                    }
                    .kiioListCardRow()
                }

                KiioPaginationFooter(
                    isLoading: store.isLoadingMore,
                    hasMore: store.hasMoreOutfits,
                    isEmpty: store.outfits.isEmpty,
                    locale: appState.locale
                ) {
                    Task { await store.loadMoreOutfits() }
                }
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("outfit.title", locale: appState.locale))
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .clothOutfit else { return }
            Task { await refreshFromBackend(version: event?.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.clothOutfit, incomingVersion: version)
        guard await store.load(reset: true) else { return }
        syncStore.markSynced(.clothOutfit, version: targetVersion)
        if syncStore.hasRemoteVersion(.clothOutfit, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func delete(_ outfit: ClothOutfitDTO) async {
        if await store.delete(id: outfit.id) {
            await refreshFromBackend()
        }
    }

    private func filterTitle(_ filter: OutfitFilter) -> String {
        switch filter {
        case .all:
            return L10n.tr("common.all", locale: appState.locale)
        case .today:
            return L10n.tr("outfit.filter.today", locale: appState.locale)
        case .recent:
            return L10n.tr("outfit.filter.recent", locale: appState.locale)
        }
    }
}

private struct OutfitDetailView: View {
    @ObservedObject var store: OutfitStore

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let outfitId: String

    init(outfitId: String, store: OutfitStore) {
        self.outfitId = outfitId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let outfit = store.detail {
                Section {
                    KiioCard {
                        HStack(alignment: .top, spacing: 14) {
                            KiioIconBadge(systemImage: "tshirt", size: 54, iconSize: 22)
                            VStack(alignment: .leading, spacing: 9) {
                                Text(outfit.displayTitle)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(KiioTheme.text)
                                KiioMetaPill(icon: "calendar", text: outfit.outfitDate ?? outfit.createdAt ?? "--")
                            }
                        }
                    }
                }
                .kiioListCardRow()

                if let content = outfit.displayContent {
                    Section(L10n.tr("outfit.suggestion", locale: appState.locale)) {
                        Text(content)
                            .foregroundStyle(KiioTheme.text)
                    }
                }

                if let items = outfit.items, !items.isEmpty {
                    Section(L10n.tr("outfit.items", locale: appState.locale)) {
                        ForEach(items) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Image(systemName: "hanger")
                                    .foregroundStyle(KiioTheme.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(KiioTheme.text)
                                    if let itemType = item.itemType, itemType != item.displayName {
                                        Text(itemType)
                                            .font(.system(size: 12))
                                            .foregroundStyle(KiioTheme.secondaryText)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                if let links = outfit.links?.filter({ $0.url?.isEmpty == false }), !links.isEmpty {
                    Section(L10n.tr("outfit.links", locale: appState.locale)) {
                        ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                            if let rawURL = link.url, let url = URL(string: rawURL) {
                                Link(destination: url) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(link.title?.isEmpty == false ? link.title! : L10n.tr("outfit.link", locale: appState.locale, index + 1))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(KiioTheme.accent)
                                        if let priceText = link.priceText, !priceText.isEmpty {
                                            Text(priceText)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(KiioTheme.text)
                                        }
                                        Text(rawURL)
                                            .font(.system(size: 12))
                                            .foregroundStyle(KiioTheme.secondaryText)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                    }
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "tshirt",
                    title: L10n.tr("outfit.detail.empty.title", locale: appState.locale),
                    message: L10n.tr("outfit.detail.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("outfit.detailTitle", locale: appState.locale))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.isActionRunning)
            }
        }
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard let event,
                  event.notifyModule == .clothOutfit,
                  event.matchesBizId(outfitId) else { return }
            Task { await refreshFromBackend(version: event.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.clothOutfit, incomingVersion: version)
        guard await store.loadDetail(id: outfitId) else { return }
        syncStore.markSynced(.clothOutfit, version: targetVersion)
        if syncStore.hasRemoteVersion(.clothOutfit, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func delete() async {
        guard await store.delete(id: outfitId) else { return }
        _ = await store.load(reset: true, silent: true)
        dismiss()
    }
}

private struct OutfitRow: View {
    let outfit: ClothOutfitDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KiioIconBadge(systemImage: "tshirt", size: 42, iconSize: 17)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(outfit.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(2)
                    Spacer()
                }

                if let content = outfit.displayContent {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(2)
                }

                if let date = outfit.outfitDate ?? outfit.createdAt {
                    KiioMetaPill(icon: "calendar", text: date)
                }

                let tags = (outfit.items ?? [])
                    .map { $0.itemName ?? $0.itemType ?? "" }
                    .filter { !$0.isEmpty }
                    .prefix(3)
                if !tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(tags), id: \.self) { tag in
                            KiioMetaPill(icon: nil, text: tag, tone: .accent)
                        }
                    }
                }
            }
        }
        .padding(15)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
    }
}
