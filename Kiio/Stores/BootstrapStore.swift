import Foundation
import Combine

@MainActor
final class BootstrapStore: ObservableObject {
    @Published private(set) var publicConfig: PublicConfig?
    @Published private(set) var preference: UserPreferenceDTO?
    @Published private(set) var userInfo: UserDetail?
    @Published private(set) var agents: [AgentDTO] = []
    @Published private(set) var devices: [DeviceDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let bootstrapService: BootstrapService
    private let userService: UserService
    private let tokenStore: TokenStore
    private var loaded = false

    init(bootstrapService: BootstrapService, userService: UserService, tokenStore: TokenStore) {
        self.bootstrapService = bootstrapService
        self.userService = userService
        self.tokenStore = tokenStore
    }

    @discardableResult
    func ensureLoaded(force: Bool = false) async -> Bool {
        if loaded && !force {
            return true
        }
        return await refresh(force: force)
    }

    @discardableResult
    func refresh(force: Bool = true) async -> Bool {
        if isLoading {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            publicConfig = try await bootstrapService.publicConfig()

            guard tokenStore.load()?.token.isEmpty == false else {
                userInfo = nil
                agents = []
                devices = []
                loaded = true
                return true
            }

            let user = try await userService.userInfo()
            preference = try? await userService.userPreference()
            let loadedAgents = try await bootstrapService.agents()
            userInfo = user
            agents = loadedAgents

            var loadedDevices: [DeviceDTO] = []
            for agent in loadedAgents {
                let agentDevices = (try? await bootstrapService.devices(agentId: agent.id)) ?? []
                loadedDevices.append(contentsOf: agentDevices)
            }
            devices = loadedDevices

            errorMessage = nil
            loaded = true
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func reset() {
        userInfo = nil
        preference = nil
        agents = []
        devices = []
        loaded = false
        errorMessage = nil
    }

    func updateLanguagePreference(_ locale: String) async {
        guard tokenStore.load()?.token.isEmpty == false else {
            return
        }

        do {
            preference = try await userService.updateUserPreference(language: L10n.backendLocale(locale))
            errorMessage = nil
        } catch {
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func updateAgentLanguagePreference(_ locale: String) async -> Bool {
        guard tokenStore.load()?.token.isEmpty == false else {
            return false
        }

        do {
            preference = try await userService.updateUserPreference(agentLanguage: L10n.backendAgentLocale(locale))
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
