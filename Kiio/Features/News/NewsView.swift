import SafariServices
import SwiftUI
import UIKit

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
            categoryPicker

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
                            .kiioHidesTabBar()
                    } label: {
                        NewsRecordRow(record: record)
                    }
                    .buttonStyle(.plain)
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
        .navigationTitle(L10n.tr("news.title", locale: appState.locale))
        .kiioHidesTabBar()
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

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(
                    title: L10n.tr("common.all", locale: appState.locale),
                    code: "all"
                )

                ForEach(visibleCategories) { category in
                    if let code = category.code?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !code.isEmpty {
                        categoryButton(title: category.displayName, code: code)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 4, trailing: 0))
    }

    private var visibleCategories: [NewsCategoryDTO] {
        store.categories.filter { category in
            guard let code = category.code?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !code.isEmpty else { return false }
            return code.caseInsensitiveCompare("all") != .orderedSame
        }
    }

    private func categoryButton(title: String, code: String) -> some View {
        let isSelected = store.selectedCategoryCode == code

        return Button {
            Task { await store.selectCategory(code) }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : KiioTheme.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(isSelected ? KiioTheme.accent : KiioTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? KiioTheme.accent : KiioTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.02), radius: 6, y: 3)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.isLoading || store.isLoadingMore)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.newsRecord, incomingVersion: version)
        guard await store.loadCurrent(reset: true) else { return }
        syncStore.markSynced(.newsRecord, version: targetVersion)
        if syncStore.hasRemoteVersion(.newsRecord, after: targetVersion) {
            await refreshFromBackend()
        }
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

    @State private var linkAlert: NewsLinkAlert?
    @State private var browserDestination: NewsBrowserDestination?

    let recordId: String
    @ObservedObject var store: NewsStore

    init(recordId: String, store: NewsStore) {
        self.recordId = recordId
        self.store = store
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if store.isLoading {
                    KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                } else if let record = store.detail, record.id == recordId {
                    headerCard(record)

                    if let summary = nonEmpty(record.summary) {
                        NewsTextSectionCard(
                            title: L10n.tr("common.summary", locale: appState.locale),
                            systemImage: "sparkles",
                            text: linkified(summary),
                            isHighlighted: true
                        )
                    }

                    if let content = nonEmpty(record.snippet) {
                        NewsTextSectionCard(
                            title: L10n.tr("common.content", locale: appState.locale),
                            systemImage: "doc.text",
                            text: linkified(content)
                        )
                    }

                    if let links = sourceLinks(record), !links.isEmpty {
                        originalLinksCard(links)
                    }
                } else {
                    KiioEmptyStateView(
                        systemImage: "newspaper",
                        title: L10n.tr("news.detail.empty.title", locale: appState.locale),
                        message: L10n.tr("news.detail.empty.message", locale: appState.locale)
                    )
                    .padding(.top, 80)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("news.detail.title", locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .kiioHidesTabBar()
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
        .environment(\.openURL, OpenURLAction { url in
            requestExternalLink(url.absoluteString)
            return .handled
        })
        .alert(item: $linkAlert) { alert in
            externalLinkAlert(alert)
        }
        .sheet(item: $browserDestination) { destination in
            NewsSafariView(url: destination.url)
                .ignoresSafeArea()
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func headerCard(_ record: NewsRecordDTO) -> some View {
        KiioCard(padding: 18) {
            if let thumbnailURL = nonEmpty(record.thumbnailUrl),
               let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    KiioTheme.accentSoft
                        .overlay {
                            Image(systemName: "newspaper")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(KiioTheme.accent)
                        }
                }
                .frame(height: 190)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(record.displayTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(KiioTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 10) {
                if let source = nonEmpty(record.source) {
                    NewsMetadataRow(
                        systemImage: "newspaper",
                        title: L10n.tr("common.source", locale: appState.locale),
                        value: source
                    )
                }

                if let time = publishedTime(record) {
                    NewsMetadataRow(
                        systemImage: "clock",
                        title: L10n.tr("news.publishedAt", locale: appState.locale),
                        value: time
                    )
                }

                if let category = nonEmpty(record.categoryName) ?? nonEmpty(record.categoryCode) {
                    NewsMetadataRow(
                        systemImage: "tag",
                        title: L10n.tr("common.category", locale: appState.locale),
                        value: category,
                        isAccent: true
                    )
                }
            }
            .padding(.top, 2)
        }
    }

    private func originalLinksCard(_ links: [NewsLinkDTO]) -> some View {
        KiioCard(padding: 16) {
            KiioSectionTitle(
                title: L10n.tr("news.originalLinks", locale: appState.locale),
                icon: "link"
            )

            VStack(spacing: 9) {
                ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                    Button {
                        requestExternalLink(link.url)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "safari")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(KiioTheme.accent)
                                .frame(width: 34, height: 34)
                                .background(KiioTheme.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.tr("news.viewOriginal", locale: appState.locale))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(KiioTheme.text)
                                    .lineLimit(1)

                                Text(linkSubtitle(link))
                                    .font(.system(size: 12))
                                    .foregroundStyle(KiioTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(KiioTheme.accent)
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(KiioTheme.accent.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func publishedTime(_ record: NewsRecordDTO) -> String? {
        nonEmpty(record.relativeTime) ?? nonEmpty(record.newsDate) ?? nonEmpty(record.createdAt)
    }

    private func sourceLinks(_ record: NewsRecordDTO) -> [NewsLinkDTO]? {
        record.links?.filter { nonEmpty($0.url) != nil }
    }

    private func linkSubtitle(_ link: NewsLinkDTO) -> String {
        nonEmpty(link.title)
            ?? nonEmpty(link.source)
            ?? linkDisplayAddress(link.url)
    }

    private func linkDisplayAddress(_ rawValue: String?) -> String {
        guard let value = nonEmpty(rawValue) else {
            return L10n.tr("news.external.missing", locale: appState.locale)
        }
        let candidate = value.lowercased().hasPrefix("www.") ? "https://\(value)" : value
        return URLComponents(string: candidate)?.host ?? value
    }

    private func requestExternalLink(_ rawValue: String?) {
        guard let value = nonEmpty(rawValue) else {
            linkAlert = .error(L10n.tr("news.external.missing", locale: appState.locale))
            return
        }

        let candidate = value.lowercased().hasPrefix("www.") ? "https://\(value)" : value
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              components.host?.isEmpty == false,
              let url = components.url else {
            linkAlert = .error(L10n.tr("news.external.invalid", locale: appState.locale))
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            linkAlert = .error(L10n.tr("news.external.unavailable", locale: appState.locale))
            return
        }

        linkAlert = .confirmation(url)
    }

    private func externalLinkAlert(_ alert: NewsLinkAlert) -> Alert {
        switch alert {
        case .confirmation(let url):
            return Alert(
                title: Text(L10n.tr("news.external.confirmTitle", locale: appState.locale)),
                message: Text(L10n.tr(
                    "news.external.confirmMessage",
                    locale: appState.locale,
                    url.host ?? url.absoluteString
                )),
                primaryButton: .default(Text(L10n.tr("news.external.open", locale: appState.locale))) {
                    DispatchQueue.main.async {
                        browserDestination = NewsBrowserDestination(url: url)
                    }
                },
                secondaryButton: .cancel(Text(L10n.tr("common.cancel", locale: appState.locale)))
            )
        case .error(let message):
            return Alert(
                title: Text(L10n.tr("common.error", locale: appState.locale)),
                message: Text(message),
                dismissButton: .default(Text(L10n.tr("common.ok", locale: appState.locale)))
            )
        }
    }

    private func linkified(_ value: String) -> AttributedString {
        let attributed = NSMutableAttributedString(string: value)
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else {
            return AttributedString(value)
        }

        let range = NSRange(location: 0, length: attributed.length)
        detector.enumerateMatches(in: value, options: [], range: range) { result, _, _ in
            guard let result, let url = result.url else { return }
            attributed.addAttribute(.link, value: url, range: result.range)
        }
        return AttributedString(attributed)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
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
}

private struct NewsRecordRow: View {
    let record: NewsRecordDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 5) {
                Text(record.displayTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(2)
                    .truncationMode(.tail)

                if let summary = nonEmpty(record.displaySummary) {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 1)

                HStack(spacing: 8) {
                    if let source = nonEmpty(record.source) ?? nonEmpty(record.categoryName) {
                        Text(source)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(KiioTheme.accent)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 2)

                    if let time = nonEmpty(record.relativeTime)
                        ?? nonEmpty(record.newsDate)
                        ?? nonEmpty(record.createdAt) {
                        Label(time, systemImage: "clock")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(KiioTheme.mutedText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 108, alignment: .trailing)
                    }
                }
            }
            .frame(minHeight: 84, alignment: .top)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let rawURL = nonEmpty(record.thumbnailUrl),
           let url = URL(string: rawURL) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                thumbnailPlaceholder
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            thumbnailPlaceholder
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var thumbnailPlaceholder: some View {
        KiioTheme.accentSoft
            .overlay {
                Image(systemName: "newspaper")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(KiioTheme.accent)
            }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

private struct NewsMetadataRow: View {
    let systemImage: String
    let title: String
    let value: String
    var isAccent = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isAccent ? KiioTheme.accent : KiioTheme.mutedText)
                .frame(width: 15)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(KiioTheme.secondaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isAccent ? KiioTheme.accent : KiioTheme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}

private struct NewsTextSectionCard: View {
    let title: String
    let systemImage: String
    let text: AttributedString
    var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isHighlighted ? KiioTheme.accent : KiioTheme.secondaryText)

            Text(text)
                .font(.system(size: isHighlighted ? 15 : 16))
                .foregroundStyle(KiioTheme.text)
                .lineSpacing(isHighlighted ? 6 : 8)
                .fixedSize(horizontal: false, vertical: true)
                .tint(KiioTheme.accent)
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHighlighted ? KiioTheme.accentSoft : KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isHighlighted ? KiioTheme.accent.opacity(0.18) : KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
    }
}

private enum NewsLinkAlert: Identifiable {
    case confirmation(URL)
    case error(String)

    var id: String {
        switch self {
        case .confirmation(let url):
            return "confirmation-\(url.absoluteString)"
        case .error(let message):
            return "error-\(message)"
        }
    }
}

private struct NewsBrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct NewsSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(KiioTheme.accent)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
