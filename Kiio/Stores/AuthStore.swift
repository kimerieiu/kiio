import Foundation
import Combine

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: TokenDTO?
    @Published private(set) var currentUser: UserDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let tokenStore: TokenStore

    init(authService: AuthService, tokenStore: TokenStore) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.token = tokenStore.load()
    }

    var isAuthenticated: Bool {
        token?.token.isEmpty == false
    }

    func sendEmailCode(email: String) async throws {
        try await runLoading {
            try await authService.sendEmailCode(email: email)
        }
    }

    func loginWithPassword(email: String, password: String) async throws {
        try await runLoading {
            let token = try await authService.loginWithPassword(email: email, password: password)
            setAuthenticated(token)
        }
    }

    func loginWithCode(email: String, code: String) async throws {
        try await runLoading {
            let token = try await authService.loginWithCode(email: email, code: code)
            setAuthenticated(token)
        }
    }

    func register(email: String, password: String, code: String, language: String) async throws {
        try await runLoading {
            let token = try await authService.register(email: email, password: password, code: code, language: language)
            setAuthenticated(token)
        }
    }

    func resetPassword(email: String, code: String, password: String) async throws {
        try await runLoading {
            try await authService.resetPassword(email: email, code: code, password: password)
        }
    }

    func updateUser(_ user: UserDetail?) {
        currentUser = user
    }

    func logout() {
        tokenStore.clear()
        token = nil
        currentUser = nil
    }

    func handleUnauthorized() {
        logout()
        errorMessage = AppError.unauthorized.errorDescription
    }

    private func setAuthenticated(_ token: TokenDTO) {
        tokenStore.save(token)
        self.token = token
        currentUser = nil
        errorMessage = nil
    }

    private func runLoading(_ operation: () async throws -> Void) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            let appError = AppError.from(error)
            errorMessage = appError.errorDescription
            throw appError
        }
    }
}
