import Foundation

@MainActor
final class ReminderService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func tasks(status: String? = nil, page: Int = 1, limit: Int = 20) async throws -> PageData<ReminderTaskDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let status, status != "all" {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return try await apiClient.get("/reminder/tasks", queryItems: queryItems)
    }

    func detail(id: String) async throws -> ReminderTaskDTO {
        try await apiClient.get("/reminder/tasks/\(id)")
    }

    func logs(id: String, page: Int = 1, limit: Int = 10) async throws -> PageData<ReminderTriggerLogDTO> {
        try await apiClient.get(
            "/reminder/tasks/\(id)/logs",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func complete(id: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/reminder/tasks/\(id)/complete")
    }

    func cancel(id: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/reminder/tasks/\(id)/cancel")
    }

    func delete(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/reminder/tasks/\(id)")
    }
}
