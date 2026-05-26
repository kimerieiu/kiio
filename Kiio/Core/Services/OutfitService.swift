import Foundation

@MainActor
final class OutfitService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func outfits(
        outfitDate: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> PageData<ClothOutfitDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let outfitDate, !outfitDate.isEmpty {
            queryItems.append(URLQueryItem(name: "outfitDate", value: outfitDate))
        }
        if let startDate, !startDate.isEmpty {
            queryItems.append(URLQueryItem(name: "startDate", value: startDate))
        }
        if let endDate, !endDate.isEmpty {
            queryItems.append(URLQueryItem(name: "endDate", value: endDate))
        }
        return try await apiClient.get("/cloth/outfits", queryItems: queryItems)
    }

    func detail(id: String) async throws -> ClothOutfitDTO {
        try await apiClient.get("/cloth/outfits/\(id)")
    }

    func delete(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/cloth/outfits/\(id)")
    }
}
