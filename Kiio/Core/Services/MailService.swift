import Foundation

@MainActor
final class MailService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func accounts() async throws -> [MailAccountDTO] {
        try await apiClient.get("/mail/accounts")
    }

    func accountDetail(id: String) async throws -> MailAccountDTO {
        try await apiClient.get("/mail/accounts/\(id)")
    }

    func createAccount(_ request: MailAccountSaveRequest) async throws -> String {
        try await apiClient.post("/mail/accounts", body: request)
    }

    func updateAccount(id: String, request: MailAccountSaveRequest) async throws {
        let _: EmptyResponse = try await apiClient.put("/mail/accounts/\(id)", body: request)
    }

    func operations(status: String? = nil, page: Int = 1, limit: Int = 20) async throws -> PageData<MailOperationDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status, status != "all" {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        try await apiClient.get(
            "/mail/operations",
            queryItems: queryItems
        )
    }

    func operationDetail(id: String) async throws -> MailOperationDTO {
        try await apiClient.get("/mail/operations/\(id)")
    }

    func setDefaultAccount(id: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/mail/accounts/\(id)/default")
    }

    func deleteAccount(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/mail/accounts/\(id)")
    }

    func deleteOperation(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/mail/operations/\(id)")
    }
}
