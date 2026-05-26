import Foundation

@MainActor
final class AccountingService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func bills(
        type: String? = nil,
        status: String? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async throws -> PageData<AccountingBillDTO> {
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let type, type != "all" {
            queryItems.append(URLQueryItem(name: "billType", value: type))
        }
        if let status, status != "all" {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        return try await apiClient.get("/accounting/bills", queryItems: queryItems)
    }

    func pendingBills(page: Int = 1, limit: Int = 10) async throws -> PageData<AccountingBillDTO> {
        try await apiClient.get(
            "/accounting/bills/pending-confirm",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "limit", value: String(limit))
            ]
        )
    }

    func detail(id: String) async throws -> AccountingBillDTO {
        try await apiClient.get("/accounting/bills/\(id)")
    }

    func categories(type: String? = nil) async throws -> [AccountingCategoryDTO] {
        var queryItems: [URLQueryItem] = []
        if let type, !type.isEmpty, type != "transfer" {
            queryItems.append(URLQueryItem(name: "categoryType", value: type))
        }
        return try await apiClient.get("/accounting/categories", queryItems: queryItems)
    }

    func accounts() async throws -> [AccountingPaymentAccountDTO] {
        try await apiClient.get("/accounting/accounts")
    }

    func update(id: String, request: AccountingBillUpdateRequest) async throws {
        let _: EmptyResponse = try await apiClient.put("/accounting/bills/\(id)", body: request)
    }

    func confirm(id: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/accounting/bills/\(id)/confirm")
    }

    func delete(id: String) async throws {
        let _: EmptyResponse = try await apiClient.delete("/accounting/bills/\(id)")
    }
}
