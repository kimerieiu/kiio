import SwiftUI

struct NewsView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        NewsListScene(store: NewsStore(service: dependencies.newsService))
    }
}

private struct NewsListScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: NewsStore

    init(store: NewsStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if store.records.isEmpty {
                KiioEmptyStateView(
                    systemImage: "newspaper",
                    title: L10n.tr("news.empty.title", locale: appState.locale),
                    message: L10n.tr("news.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                ForEach(store.records) { record in
                    NavigationLink {
                        NewsDetailView(recordId: record.id, store: store)
                    } label: {
                        NewsRecordRow(record: record)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            Task { await delete(record) }
                        } label: {
                            Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                        }
                    }
                    .kiioListCardRow()
                }

                KiioPaginationFooter(
                    isLoading: store.isLoadingMore,
                    hasMore: store.hasMoreRecords,
                    isEmpty: store.records.isEmpty,
                    locale: appState.locale
                ) {
                    Task { await store.loadMoreRecords() }
                }
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(L10n.tr("common.all", locale: appState.locale)) {
                        Task { await store.selectCategory("all") }
                    }

                    ForEach(store.categories) { category in
                        if let code = category.code, !code.isEmpty {
                            Button(category.displayName) {
                                Task { await store.selectCategory(code) }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            await store.loadCategories()
            await refreshFromBackend()
        }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .newsRecord else { return }
            Task { await refreshFromBackend(version: event?.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.newsRecord, incomingVersion: version)
        guard await store.loadCurrent(reset: true) else { return }
        syncStore.markSynced(.newsRecord, version: targetVersion)
        if syncStore.hasRemoteVersion(.newsRecord, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private var navigationTitle: String {
        guard store.selectedCategoryCode != "all",
              let category = store.categories.first(where: { $0.code == store.selectedCategoryCode }) else {
            return L10n.tr("news.title", locale: appState.locale)
        }
        return category.displayName
    }

    private func delete(_ record: NewsRecordDTO) async {
        if await store.delete(id: record.id) {
            await refreshFromBackend()
        }
    }

}

private struct NewsDetailView: View {
    let recordId: String
    @ObservedObject var store: NewsStore

    init(recordId: String, store: NewsStore) {
        self.recordId = recordId
        self.store = store
    }

    var body: some View {
        NewsDetailScene(recordId: recordId, store: store)
    }
}

private struct NewsDetailScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let recordId: String
    @ObservedObject var store: NewsStore

    init(recordId: String, store: NewsStore) {
        self.recordId = recordId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let record = store.detail {
                Section {
                    KiioCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if let thumbnailURL = record.thumbnailUrl,
                               let url = URL(string: thumbnailURL) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    KiioTheme.accentSoft
                                }
                                .frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            Text(record.displayTitle)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(KiioTheme.text)
                                .lineLimit(4)

                            HStack(spacing: 6) {
                                if let source = record.source ?? record.categoryName {
                                    KiioMetaPill(icon: "newspaper", text: source, tone: .accent)
                                }
                                if let time = record.relativeTime ?? record.newsDate ?? record.createdAt {
                                    KiioMetaPill(icon: "clock", text: time)
                                }
                            }
                        }
                    }
                }
                .kiioListCardRow()

                if let summary = record.summary, !summary.isEmpty {
                    Section(L10n.tr("common.summary", locale: appState.locale)) {
                        Text(summary)
                            .foregroundStyle(KiioTheme.text)
                    }
                }

                if let snippet = record.snippet, !snippet.isEmpty {
                    Section(L10n.tr("common.content", locale: appState.locale)) {
                        Text(snippet)
                            .foregroundStyle(KiioTheme.text)
                    }
                }

                Section(L10n.tr("common.detail", locale: appState.locale)) {
                    labeled(L10n.tr("common.category", locale: appState.locale), record.categoryName ?? record.categoryCode)
                    labeled(L10n.tr("common.type", locale: appState.locale), record.type)
                    labeled(L10n.tr("news.keyword", locale: appState.locale), record.keyword)
                    labeled(L10n.tr("news.tagType", locale: appState.locale), record.tagType)
                    labeled(L10n.tr("common.createdAt", locale: appState.locale), record.createdAt)
                }

                if let links = record.links?.filter({ $0.url?.isEmpty == false }), !links.isEmpty {
                    Section(L10n.tr("news.links", locale: appState.locale)) {
                        ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(link.title?.isEmpty == false ? link.title! : L10n.tr("news.link", locale: appState.locale, index + 1))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(KiioTheme.accent)
                                Text(link.url ?? "")
                                    .font(.system(size: 12))
                                    .foregroundStyle(KiioTheme.secondaryText)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "newspaper",
                    title: L10n.tr("news.detail.empty.title", locale: appState.locale),
                    message: L10n.tr("news.detail.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("common.detail", locale: appState.locale))
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
                  event.notifyModule == .newsRecord,
                  event.matchesBizId(recordId) else { return }
            Task { await refreshFromBackend(version: event.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.newsRecord, incomingVersion: version)
        guard await store.loadDetail(id: recordId) else { return }
        syncStore.markSynced(.newsRecord, version: targetVersion)
        if syncStore.hasRemoteVersion(.newsRecord, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func delete() async {
        guard await store.delete(id: recordId) else { return }
        _ = await store.loadCurrent(reset: true, silent: true)
        dismiss()
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
            Spacer()
            Text(value?.isEmpty == false ? value! : "--")
                .foregroundStyle(KiioTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct NewsRecordRow: View {
    let record: NewsRecordDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                Text(record.displayTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(2)

                if let summary = record.displaySummary {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(3)
                }

                HStack(spacing: 6) {
                    if let categoryName = record.categoryName {
                        KiioMetaPill(icon: nil, text: categoryName, tone: .accent)
                    }
                    if let source = record.source {
                        KiioMetaPill(icon: nil, text: source)
                    }
                }

                if let relativeTime = record.relativeTime ?? record.newsDate {
                    KiioMetaPill(icon: "clock", text: relativeTime)
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

    @ViewBuilder
    private var thumbnail: some View {
        if let rawURL = record.thumbnailUrl,
           let url = URL(string: rawURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                KiioTheme.accentSoft
            }
            .frame(width: 66, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            KiioIconBadge(systemImage: "newspaper", size: 48, iconSize: 19)
        }
    }
}
