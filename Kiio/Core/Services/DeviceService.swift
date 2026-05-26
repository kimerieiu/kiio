import Foundation

struct UpdateDeviceRequest: Encodable {
    let alias: String?
    let autoUpdate: Int?
}

struct UnbindDeviceRequest: Encodable {
    let deviceId: String
}

@MainActor
final class DeviceService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func bindDevice(agentId: String, code: String) async throws {
        let _: EmptyResponse = try await apiClient.post("/device/bind/\(agentId)/\(code)")
    }

    func updateDevice(id: String, alias: String? = nil, autoUpdate: Int? = nil) async throws {
        let _: EmptyResponse = try await apiClient.put(
            "/device/update/\(id)",
            body: UpdateDeviceRequest(alias: alias, autoUpdate: autoUpdate)
        )
    }

    func unbindDevice(id: String) async throws {
        let _: EmptyResponse = try await apiClient.post(
            "/device/unbind",
            body: UnbindDeviceRequest(deviceId: id)
        )
    }
}
