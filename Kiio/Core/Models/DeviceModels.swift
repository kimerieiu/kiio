import Foundation

struct DeviceDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let macAddress: String?
    let lastConnectedAt: String?
    let autoUpdate: Int?
    let board: String?
    let alias: String?
    let agentId: String?
    let appVersion: String?
    let sort: Int?
    let updateDate: String?
    let createDate: String?

    var displayName: String {
        if let alias, !alias.isEmpty {
            return alias
        }
        if let board, !board.isEmpty {
            return board
        }
        return macAddress ?? "Kiio Device"
    }
}
