import Foundation

@MainActor
final class LegalDocumentService {
    private let apiClient: APIClient
    private let session: URLSession
    private let maximumDocumentBytes = 2 * 1_024 * 1_024

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        self.session = URLSession(configuration: configuration)
    }

    func latest(slug: String, locale: String) async throws -> LegalDocumentVersionDTO {
        try await apiClient.get(
            "/legal/documents/\(slug)/latest",
            queryItems: [URLQueryItem(name: "locale", value: locale)],
            authenticated: false
        )
    }

    func download(_ metadata: LegalDocumentVersionDTO) async throws -> String {
        guard let url = URL(string: metadata.pageUrl), isTrustedLegalPage(url) else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              let finalURL = httpResponse.url,
              isTrustedLegalPage(finalURL),
              (200..<300).contains(httpResponse.statusCode),
              data.count <= maximumDocumentBytes,
              httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/html") == true,
              let html = String(data: data, encoding: .utf8),
              validate(html: html, metadata: metadata) else {
            throw AppError.invalidResponse
        }
        return html
    }

    func recordEvent(_ request: LegalConsentEventRequest) async throws -> String {
        try await apiClient.post("/legal/consents/events", body: request)
    }

    func validate(html: String, metadata: LegalDocumentVersionDTO) -> Bool {
        html.contains(#"name="kiio-legal-slug" content="\#(metadata.slug)""#)
            && html.contains(#"name="kiio-legal-version" content="\#(metadata.version)""#)
            && html.contains(#"name="kiio-legal-locale" content="\#(metadata.locale)""#)
            && html.contains(#"name="kiio-legal-content-hash" content="\#(metadata.contentHash)""#)
    }

    private func isTrustedLegalPage(_ url: URL) -> Bool {
        let base = AppConfig.apiBaseURL
        let expectedPrefix = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let actualPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return url.scheme == base.scheme
            && url.host == base.host
            && url.port == base.port
            && actualPath.hasPrefix("\(expectedPrefix)/legal/pages/")
    }
}
