import Foundation

enum AppNotifyModule: String, Codable, CaseIterable, Identifiable {
    case accountingBill = "ACCOUNTING_BILL"
    case reminderTask = "REMINDER_TASK"
    case newsRecord = "NEWS_RECORD"
    case clothOutfit = "CLOTH_OUTFIT"
    case mailOperation = "MAIL_OPERATION"
    case device = "DEVICE"

    var id: String { rawValue }

    init?(notifyValue: String) {
        switch notifyValue {
        case "ACCOUNTING_BILL":
            self = .accountingBill
        case "REMINDER_TASK":
            self = .reminderTask
        case "NEWS_RECORD":
            self = .newsRecord
        case "CLOTH_OUTFIT":
            self = .clothOutfit
        case "MAIL_OPERATION":
            self = .mailOperation
        case "DEVICE", "DEVICE_STATUS", "DEVICE_BINDING":
            self = .device
        default:
            return nil
        }
    }
}

struct AppNotifyVersionsDTO: Decodable {
    let versions: [String: Int]

    private enum CodingKeys: String, CodingKey {
        case versions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawVersions = try container.decode([String: FlexibleInt].self, forKey: .versions)
        versions = rawVersions.mapValues(\.value)
    }
}

struct AppDataChangedEvent: Decodable, Equatable, Identifiable {
    let type: String?
    let eventId: String?
    let module: String?
    let action: String?
    let bizId: String?
    let version: Int?
    let occurredAt: String?
    let traceId: String?

    private enum CodingKeys: String, CodingKey {
        case type
        case eventId
        case module
        case action
        case bizId
        case version
        case occurredAt
        case traceId
    }

    init(
        type: String?,
        eventId: String?,
        module: String?,
        action: String?,
        bizId: String?,
        version: Int?,
        occurredAt: String?,
        traceId: String?
    ) {
        self.type = type
        self.eventId = eventId
        self.module = module
        self.action = action
        self.bizId = bizId
        self.version = version
        self.occurredAt = occurredAt
        self.traceId = traceId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
        module = try container.decodeIfPresent(String.self, forKey: .module)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        bizId = try container.decodeIfPresent(String.self, forKey: .bizId)
        version = try container.decodeIfPresent(FlexibleInt.self, forKey: .version)?.value
        occurredAt = try container.decodeIfPresent(String.self, forKey: .occurredAt)
        traceId = try container.decodeIfPresent(String.self, forKey: .traceId)
    }

    var id: String {
        eventId ?? "\(module ?? "")-\(action ?? "")-\(bizId ?? "")-\(version ?? 0)-\(occurredAt ?? "")"
    }

    var notifyModule: AppNotifyModule? {
        guard let module else { return nil }
        return AppNotifyModule(notifyValue: module)
    }

    var isDataChanged: Bool {
        type == nil || type == "DATA_CHANGED"
    }

    func matchesBizId(_ id: String) -> Bool {
        bizId == nil || bizId == id
    }

    static func sync(module: AppNotifyModule, version: Int) -> AppDataChangedEvent {
        AppDataChangedEvent(
            type: "DATA_CHANGED",
            eventId: "SYNC-\(module.rawValue)-\(version)",
            module: module.rawValue,
            action: "SYNC",
            bizId: nil,
            version: version,
            occurredAt: nil,
            traceId: nil
        )
    }
}

private struct FlexibleInt: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
            return
        }
        if let stringValue = try? container.decode(String.self),
           let intValue = Int(stringValue) {
            value = intValue
            return
        }
        value = 0
    }
}
