import Foundation

@MainActor
final class AuthService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func publicConfig() async throws -> PublicConfig {
        try await apiClient.get("/user/pub-config", authenticated: false)
    }

    func sendEmailCode(email: String) async throws {
        let _: EmptyResponse = try await apiClient.post(
            "/user/emailVerification",
            body: EmailCodeRequest(email: email),
            authenticated: false
        )
    }

    func loginWithPassword(email: String, password: String) async throws -> TokenDTO {
        try await apiClient.post(
            "/user/login",
            body: LoginPasswordRequest(email: email, password: password),
            authenticated: false
        )
    }

    func loginWithCode(email: String, code: String) async throws -> TokenDTO {
        try await apiClient.post(
            "/user/login",
            body: LoginCodeRequest(email: email, emailCaptcha: code),
            authenticated: false
        )
    }

    func register(email: String, password: String, code: String, language: String) async throws -> TokenDTO {
        try await apiClient.post(
            "/user/register",
            body: RegisterRequest(email: email, password: password, emailCaptcha: code, language: language),
            authenticated: false
        )
    }

    func resetPassword(email: String, code: String, password: String) async throws {
        let _: EmptyResponse = try await apiClient.put(
            "/user/retrieve-password",
            body: ResetPasswordRequest(email: email, emailCaptcha: code, password: password),
            authenticated: false
        )
    }
}
