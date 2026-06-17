import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        ChatScene(store: ChatStore(service: dependencies.chatService))
    }
}

private struct ChatScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @StateObject private var store: ChatStore

    init(store: ChatStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar

                content
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(store.agent == nil ? KiioTheme.mutedText : KiioTheme.success)
                    .frame(width: 8, height: 8)
                Text(store.agent?.displayName ?? L10n.tr("chat.defaultCompanion", locale: appState.locale))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(KiioTheme.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(KiioTheme.border, lineWidth: 1)
            )

            Spacer()

            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KiioTheme.text)
                .frame(width: 38, height: 38)
                .background(KiioTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(Text(L10n.tr("chat.sessions", locale: appState.locale)))
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading {
            KiioCard {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L10n.tr("chat.loadingConversations", locale: appState.locale))
                        .font(.system(size: 14))
                        .foregroundStyle(KiioTheme.secondaryText)
                }
            }
        } else if store.agent == nil {
            KiioEmptyStateView(
                systemImage: "bubble.left.and.bubble.right",
                title: L10n.tr("chat.noAgent.title", locale: appState.locale),
                message: L10n.tr("chat.noAgent.message", locale: appState.locale)
            )
        } else if let latestSession = store.sessions.first {
            latestSessionSummary(latestSession)
            latestConversation
            sessionsList
        } else {
            KiioEmptyStateView(
                systemImage: "bubble.left.and.bubble.right",
                title: L10n.tr("chat.empty.title", locale: appState.locale),
                message: L10n.tr("chat.empty.message", locale: appState.locale)
            )
        }
    }

    private func latestSessionSummary(_ session: ChatSessionDTO) -> some View {
        NavigationLink {
            ChatSessionDetailView(agent: store.agent, session: session)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.tr("chat.latestSession", locale: appState.locale))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KiioTheme.accent)
                    Text("#\(session.sessionId.prefix(8))")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(KiioTheme.text)
                    if let createdAt = session.createdAt,
                       let date = ChatDateFormatter.date(from: createdAt) {
                        Text(ChatDateFormatter.clockOrDayString(from: date))
                            .font(.system(size: 12))
                            .foregroundStyle(KiioTheme.secondaryText)
                    }
                }

                Spacer()

                Text(L10n.tr("chat.messageCount", locale: appState.locale, store.latestMessages.count))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(KiioTheme.accentSoft)
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(KiioTheme.mutedText)
            }
            .padding(16)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var latestConversation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("chat.latest", locale: appState.locale))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
                .padding(.horizontal, 4)

            if store.latestMessages.isEmpty {
                KiioCard {
                    Text(L10n.tr("chat.noMessages", locale: appState.locale))
                        .font(.system(size: 14))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(store.latestMessages.prefix(8)) { message in
                        ChatMessageRow(message: message)
                    }
                }
            }
        }
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("chat.sessions", locale: appState.locale))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
                .padding(.horizontal, 4)

            if store.sessions.isEmpty {
                KiioCard {
                    Text(L10n.tr("chat.noSessions", locale: appState.locale))
                        .font(.system(size: 14))
                        .foregroundStyle(KiioTheme.secondaryText)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(groupedSessions) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(KiioTheme.secondaryText)
                                .padding(.horizontal, 4)

                            ForEach(group.sessions) { session in
                                NavigationLink {
                                    ChatSessionDetailView(agent: store.agent, session: session)
                                } label: {
                                    ChatSessionRow(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    KiioPaginationFooter(
                        isLoading: store.isLoadingMore,
                        hasMore: store.hasMoreSessions,
                        isEmpty: store.sessions.isEmpty,
                        locale: appState.locale
                    ) {
                        Task { await store.loadMoreSessions() }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func load() async {
        await bootstrapStore.ensureLoaded()
        await store.load(agent: bootstrapStore.agents.first)
    }

    private var groupedSessions: [ChatSessionGroup] {
        var groups: [ChatSessionGroup] = []
        for session in store.sessions {
            let title = groupTitle(for: session.createdAt)
            if let index = groups.firstIndex(where: { $0.id == title }) {
                groups[index].sessions.append(session)
            } else {
                groups.append(ChatSessionGroup(id: title, title: title, sessions: [session]))
            }
        }
        return groups
    }

    private func groupTitle(for value: String?) -> String {
        guard let date = ChatDateFormatter.date(from: value) else {
            return L10n.tr("chat.earlier", locale: appState.locale)
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.tr("chat.today", locale: appState.locale)
        }
        if calendar.isDateInYesterday(date) {
            return L10n.tr("chat.yesterday", locale: appState.locale)
        }
        return L10n.tr("chat.earlier", locale: appState.locale)
    }
}

struct ChatMessageRow: View {
    let message: ChatMessageDTO

    var body: some View {
        HStack(alignment: .top) {
            if message.isUserMessage {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.isUserMessage ? .trailing : .leading, spacing: 4) {
                Text(message.displayContent)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .foregroundStyle(message.isUserMessage ? .white : KiioTheme.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(message.isUserMessage ? KiioTheme.accent : KiioTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(message.isAgentMessage ? KiioTheme.border : .clear, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(message.isAgentMessage ? 0.035 : 0), radius: 10, y: 5)

                if let messageTime = messageTime {
                    Text(messageTime)
                        .font(.system(size: 10))
                        .foregroundStyle(KiioTheme.mutedText)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: message.isUserMessage ? .trailing : .leading)

            if message.isAgentMessage {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var messageTime: String? {
        guard let date = ChatDateFormatter.date(from: message.createdAt) else {
            return nil
        }
        return ChatDateFormatter.clockOrDayString(from: date)
    }
}

struct ChatSessionDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    let agent: AgentDTO?
    let session: ChatSessionDTO

    var body: some View {
        ChatSessionDetailScene(
            agent: agent,
            session: session,
            store: ChatStore(service: dependencies.chatService)
        )
    }
}

private struct ChatSessionDetailScene: View {
    @EnvironmentObject private var appState: AppState

    let agent: AgentDTO?
    let session: ChatSessionDTO
    @StateObject private var store: ChatStore

    init(agent: AgentDTO?, session: ChatSessionDTO, store: ChatStore) {
        self.agent = agent
        self.session = session
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            if store.isLoadingHistory {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if store.messages.isEmpty {
                KiioEmptyStateView(
                    systemImage: "bubble.left.and.bubble.right",
                    title: L10n.tr("chat.detail.empty.title", locale: appState.locale),
                    message: L10n.tr("chat.detail.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                if let dateTitle = dateTitle {
                    Text(dateTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KiioTheme.mutedText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .kiioListHeaderRow()
                }

                ForEach(store.messages) { message in
                    ChatMessageRow(message: message)
                        .kiioListCardRow()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle("#\(session.sessionId.prefix(8))")
        .task {
            await store.loadHistory(agent: agent, session: session)
        }
        .refreshable {
            await store.loadHistory(agent: agent, session: session)
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private var dateTitle: String? {
        guard let first = store.messages.first,
              let date = ChatDateFormatter.date(from: first.createdAt) else {
            return nil
        }
        return ChatDateFormatter.dayString(from: date)
    }
}

private struct ChatSessionRow: View {
    @EnvironmentObject private var appState: AppState

    let session: ChatSessionDTO

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 38, height: 38)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("#\(session.sessionId.prefix(8))")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    Spacer()
                    if let createdAt = session.createdAt,
                       let date = ChatDateFormatter.date(from: createdAt) {
                        Text(ChatDateFormatter.clockOrDayString(from: date))
                            .font(.system(size: 12))
                            .foregroundStyle(KiioTheme.mutedText)
                    }
                }

                Text(L10n.tr("chat.messageCount", locale: appState.locale, session.chatCount ?? 0))
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(14)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }
}

private struct ChatSessionGroup: Identifiable {
    let id: String
    let title: String
    var sessions: [ChatSessionDTO]
}

private enum ChatDateFormatter {
    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = backendFormatter.date(from: value) {
            return date
        }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        return isoFormatter.date(from: normalized) ?? fallbackISOFormatter.date(from: normalized)
    }

    static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func clockOrDayString(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: date)
    }
}
