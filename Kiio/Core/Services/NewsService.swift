import Foundation

@MainActor
final class NewsService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func categories() async throws -> [NewsCategoryDTO] {
        try await apiClient.get("/news/categories")
    }

    func records(categoryCode: String? = nil, page: Int = 1, limit: Int = 20) async throws -> PageData<NewsRecordDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let categoryCode, categoryCode != "all" {
            queryItems.append(URLQueryItem(name: "categoryCode", value: categoryCode))
        }
        return try await apiClient.get("/news/records", queryItems: queryItems)
    }

    func detail(id: String) async throws -> NewsRecordDTO {
        try await apiClient.get("/news/records/\(id)")
    }

    func delete(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/news/records/\(id)")
    }
}
