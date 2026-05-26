import Foundation

@MainActor
final class DeviceQRCodeBindingViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var didBind = false
    @Published var scannedCode: String?
    @Published var errorMessage: String?
    @Published var needsRescan = false

    func handleScannedValue(
        _ rawValue: String,
        locale: String,
        agentId: String?,
        deviceStore: DeviceStore
    ) async -> Bool {
        guard !isProcessing, !didBind, !needsRescan else {
            return false
        }

        isProcessing = true
        defer {
            if !didBind {
                isProcessing = false
            }
        }

        let payload: DeviceQRCodePayload
        do {
            payload = try DeviceQRCodeParser.parse(rawValue)
        } catch {
            errorMessage = L10n.tr("device.scan.invalidQRCode", locale: locale)
            needsRescan = true
            return false
        }

        guard let agentId, !agentId.isEmpty else {
            scannedCode = payload.code
            errorMessage = L10n.tr("device.noAgent", locale: locale)
            needsRescan = true
            return false
        }

        scannedCode = payload.code
        if await deviceStore.bindDevice(agentId: agentId, code: payload.code) {
            didBind = true
            isProcessing = false
            return true
        }

        errorMessage = deviceStore.errorMessage ?? L10n.tr("device.scan.bindFailed", locale: locale)
        needsRescan = true
        return false
    }

    func scanAgain() {
        isProcessing = false
        didBind = false
        scannedCode = nil
        errorMessage = nil
        needsRescan = false
    }
}
