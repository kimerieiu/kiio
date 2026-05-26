import Foundation

@MainActor
final class ChatService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func sessions(agentId: String, page: Int = 1, limit: Int = 20) async throws -> PageData<ChatSessionDTO> {
        try await apiClient.get(
            "/agent/\(agentId)/sessions",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func history(agentId: String, sessionId: String) async throws -> [ChatMessageDTO] {
        try await apiClient.get("/agent/\(agentId)/chat-history/\(sessionId)")
    }
}
