import Foundation

@MainActor
final class NotifyService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func versions() async throws -> AppNotifyVersionsDTO {
        try await apiClient.get("/notify/versions")
    }
}
