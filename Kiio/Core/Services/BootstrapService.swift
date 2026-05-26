import Foundation

@MainActor
final class BootstrapService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func publicConfig() async throws -> PublicConfig {
        try await apiClient.get("/user/pub-config", authenticated: false)
    }

    func agents() async throws -> [AgentDTO] {
        try await apiClient.get(
            "/agent/list",
            queryItems: [
                URLQueryItem(name: "keyword", value: ""),
                URLQueryItem(name: "searchType", value: "name")
            ]
        )
    }

    func devices(agentId: String) async throws -> [DeviceDTO] {
        try await apiClient.get("/device/bind/\(agentId)")
    }
}
