import Foundation

@MainActor
final class UserService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func userInfo() async throws -> UserDetail {
        try await apiClient.get("/user/info")
    }

    func userPreference() async throws -> UserPreferenceDTO {
        try await apiClient.get("/user/preference")
    }

    func updateUserPreference(language: String) async throws -> UserPreferenceDTO {
        try await updateUserPreference(language: language, agentLanguage: nil, timezone: TimeZone.current.identifier)
    }

    func updateUserPreference(agentLanguage: String) async throws -> UserPreferenceDTO {
        try await updateUserPreference(language: nil, agentLanguage: agentLanguage, timezone: nil)
    }

    private func updateUserPreference(
        language: String?,
        agentLanguage: String?,
        timezone: String?
    ) async throws -> UserPreferenceDTO {
        try await apiClient.put(
            "/user/preference",
            body: UserPreferenceDTO(language: language, agentLanguage: agentLanguage, timezone: timezone)
        )
    }
}
