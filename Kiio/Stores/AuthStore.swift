import Foundation
import Combine

enum StartupAuthResult {
    case noLocalSession
    case localSessionExpired
    case validated(UserDetail)
    case unauthorized
    case recoverableFailure(AppError)
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var token: TokenDTO?
    @Published private(set) var currentUser: UserDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let userService: UserService
    private let tokenStore: TokenStore
    private var expiryTask: Task<Void, Never>?

    init(authService: AuthService, userService: UserService, tokenStore: TokenStore) {
        self.authService = authService
        self.userService = userService
        self.tokenStore = tokenStore
        self.token = tokenStore.load()
        scheduleExpiryCheck()
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

    func deleteAccount() async throws {
        try await runLoading {
            try await authService.deleteAccount()
            logout()
        }
    }

    func updateUser(_ user: UserDetail?) {
        currentUser = user
    }

    func validateStartupSession() async -> StartupAuthResult {
        switch tokenStore.loadState() {
        case .missing:
            cancelExpiryCheck()
            clearInMemorySession()
            return .noLocalSession
        case .expired:
            cancelExpiryCheck()
            clearInMemorySession()
            errorMessage = AppError.unauthorized.errorDescription
            return .localSessionExpired
        case .valid(let localToken):
            token = localToken
            scheduleExpiryCheck()
        }

        do {
            let user = try await userService.userInfo()
            currentUser = user
            errorMessage = nil
            return .validated(user)
        } catch {
            let appError = AppError.from(error)
            if case .unauthorized = appError {
                logout()
                errorMessage = appError.errorDescription
                return .unauthorized
            }

            errorMessage = appError.errorDescription
            return .recoverableFailure(appError)
        }
    }

    func logout() {
        cancelExpiryCheck()
        tokenStore.clear()
        clearInMemorySession()
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
        scheduleExpiryCheck()
    }

    private func clearInMemorySession() {
        token = nil
        currentUser = nil
    }

    private func cancelExpiryCheck() {
        expiryTask?.cancel()
        expiryTask = nil
    }

    private func scheduleExpiryCheck() {
        cancelExpiryCheck()

        guard let expiresAt = tokenStore.expiresAt() else {
            return
        }

        let delay = expiresAt.timeIntervalSinceNow
        guard delay > 0 else {
            handleUnauthorized()
            return
        }

        expiryTask = Task { [weak self] in
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.handleUnauthorized()
        }
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
