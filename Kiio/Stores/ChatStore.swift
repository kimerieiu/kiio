import Foundation
import Combine

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var agent: AgentDTO?
    @Published private(set) var sessions: [ChatSessionDTO] = []
    @Published private(set) var latestMessages: [ChatMessageDTO] = []
    @Published private(set) var messages: [ChatMessageDTO] = []
    @Published private(set) var totalSessions = 0
    @Published private(set) var hasMoreSessions = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isLoadingHistory = false
    @Published var errorMessage: String?

    private let service: ChatService
    private var nextPage = 1
    private let pageLimit = 10

    init(service: ChatService) {
        self.service = service
    }

    func loadLatestConversation(agent: AgentDTO?) async {
        self.agent = agent

        guard let agent else {
            sessions = []
            latestMessages = []
            totalSessions = 0
            nextPage = 1
            hasMoreSessions = false
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.sessions(agentId: agent.id, page: 1, limit: 1)
            sessions = page.list
            totalSessions = page.total
            nextPage = 1
            hasMoreSessions = false

            if let firstSession = page.list.first {
                let history = try await service.history(agentId: agent.id, sessionId: firstSession.sessionId)
                latestMessages = history.filter(\.isVisibleConversationMessage)
            } else {
                latestMessages = []
            }
            errorMessage = nil
        } catch {
            sessions = []
            latestMessages = []
            totalSessions = 0
            nextPage = 1
            hasMoreSessions = false
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func load(agent: AgentDTO?) async {
        self.agent = agent

        guard let agent else {
            sessions = []
            latestMessages = []
            totalSessions = 0
            nextPage = 1
            hasMoreSessions = false
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let page = try await service.sessions(agentId: agent.id, page: 1, limit: pageLimit)
            sessions = page.list
            totalSessions = page.total
            nextPage = 2
            hasMoreSessions = sessions.count < totalSessions

            if let firstSession = page.list.first {
                let history = try await service.history(agentId: agent.id, sessionId: firstSession.sessionId)
                latestMessages = history.filter(\.isVisibleConversationMessage)
            } else {
                latestMessages = []
            }
            errorMessage = nil
        } catch {
            sessions = []
            latestMessages = []
            totalSessions = 0
            nextPage = 1
            hasMoreSessions = false
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func loadMoreSessions() async {
        guard let agent, hasMoreSessions, !isLoading, !isLoadingMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await service.sessions(agentId: agent.id, page: nextPage, limit: pageLimit)
            sessions.append(contentsOf: page.list)
            totalSessions = page.total
            nextPage += 1
            hasMoreSessions = sessions.count < totalSessions && !page.list.isEmpty
            errorMessage = nil
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func loadHistory(agent: AgentDTO?, session: ChatSessionDTO) async {
        guard let agent else {
            messages = []
            return
        }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            let history = try await service.history(agentId: agent.id, sessionId: session.sessionId)
            messages = history.filter(\.isVisibleConversationMessage)
            errorMessage = nil
        } catch {
            messages = []
            errorMessage = AppError.from(error).errorDescription
        }
    }
}
