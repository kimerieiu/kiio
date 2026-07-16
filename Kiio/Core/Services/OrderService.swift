import Foundation

@MainActor
final class OrderService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func orders(page: Int = 1, limit: Int = 20) async throws -> PageData<ShopifyOrderDTO> {
        try await apiClient.get(
            "/subscription/shopify/orders",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func detail(id: String) async throws -> ShopifyOrderDTO {
        try await apiClient.get("/subscription/shopify/orders/\(id)")
    }
}
