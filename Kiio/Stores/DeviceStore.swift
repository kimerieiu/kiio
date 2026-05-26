import Foundation
import Combine

@MainActor
final class DeviceStore: ObservableObject {
    @Published var isBinding = false
    @Published var isUpdating = false
    @Published var errorMessage: String?

    private let deviceService: DeviceService
    private let bootstrapStore: BootstrapStore

    init(deviceService: DeviceService, bootstrapStore: BootstrapStore) {
        self.deviceService = deviceService
        self.bootstrapStore = bootstrapStore
    }

    func bindDevice(agentId: String, code: String) async -> Bool {
        isBinding = true
        defer { isBinding = false }

        do {
            try await deviceService.bindDevice(agentId: agentId, code: code)
            await bootstrapStore.refresh()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func updateDevice(id: String, alias: String? = nil, autoUpdate: Int? = nil) async -> Bool {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await deviceService.updateDevice(id: id, alias: alias, autoUpdate: autoUpdate)
            await bootstrapStore.refresh()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func unbindDevice(id: String) async -> Bool {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await deviceService.unbindDevice(id: id)
            await bootstrapStore.refresh()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
