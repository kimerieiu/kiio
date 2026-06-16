import Foundation

@MainActor
final class APIClient {
    private let baseURL: URL
    private let tokenStore: TokenStore
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let unauthorizedCodes: Set<Int> = [401, 10020, 10021, 10044]

    var localeProvider: (() -> String)?
    var onUnauthorized: (() -> Void)?

    init(baseURL: URL = AppConfig.apiBaseURL, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func get<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem] = [],
        authenticated: Bool = true
    ) async throws -> Response {
        let body: EmptyRequest? = nil
        return try await send(path, method: "GET", queryItems: queryItems, body: body, authenticated: authenticated)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(path, method: "POST", body: body, authenticated: authenticated)
    }

    func post<Response: Decodable>(
        _ path: String,
        authenticated: Bool = true
    ) async throws -> Response {
        let body: EmptyRequest? = nil
        return try await send(path, method: "POST", body: body, authenticated: authenticated)
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        authenticated: Bool = true
    ) async throws -> Response {
        try await send(path, method: "PUT", body: body, authenticated: authenticated)
    }

    func delete<Response: Decodable>(
        _ path: String,
        authenticated: Bool = true
    ) async throws -> Response {
        let body: EmptyRequest? = nil
        return try await send(path, method: "DELETE", body: body, authenticated: authenticated)
    }

    private func send<Response: Decodable, Body: Encodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body? = nil,
        authenticated: Bool
    ) async throws -> Response {
        guard let url = buildURL(path, queryItems: queryItems) else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: AppConfig.requestTimeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(acceptLanguageHeader(), forHTTPHeaderField: "Accept-Language")

        if authenticated {
            switch tokenStore.loadState() {
            case .valid(let token) where !token.token.isEmpty:
                request.setValue("Bearer \(token.token)", forHTTPHeaderField: "Authorization")
            case .missing, .expired, .valid(_):
                onUnauthorized?()
                throw AppError.unauthorized
            }
        }

        if let body {
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AppError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? decoder.decode(ApiEnvelope<EmptyResponse>.self, from: data) {
                if unauthorizedCodes.contains(envelope.code) {
                    onUnauthorized?()
                    throw AppError.unauthorized
                }
                throw AppError.server(envelope.msg ?? "HTTP \(httpResponse.statusCode)")
            }

            if httpResponse.statusCode == 401 {
                onUnauthorized?()
                throw AppError.unauthorized
            }
            throw AppError.server("HTTP \(httpResponse.statusCode)")
        }

        do {
            let envelope = try decoder.decode(ApiEnvelope<Response>.self, from: data)
            guard envelope.code == 0 else {
                if unauthorizedCodes.contains(envelope.code) {
                    onUnauthorized?()
                    throw AppError.unauthorized
                }
                throw AppError.server(envelope.msg ?? "Request failed.")
            }

            if let payload = envelope.data {
                return payload
            }

            if Response.self == EmptyResponse.self {
                return EmptyResponse() as! Response
            }

            throw AppError.emptyData
        } catch let appError as AppError {
            throw appError
        } catch {
            throw AppError.decoding(error.localizedDescription)
        }
    }

    private func buildURL(_ path: String, queryItems: [URLQueryItem]) -> URL? {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let rawURL = "\(base)/\(cleanPath)"

        var components = URLComponents(string: rawURL)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        return components?.url
    }

    private func acceptLanguageHeader() -> String {
        switch localeProvider?() ?? "" {
        case "en", "en_US", "en-US":
            return "en-US"
        case "zh", "zh_CN", "zh-CN":
            return "zh-CN"
        default:
            return Locale.preferredLanguages.first ?? "zh-CN"
        }
    }
}
