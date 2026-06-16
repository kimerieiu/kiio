import Foundation

enum DeviceRoute: String, Identifiable, Hashable {
    case provisioning
    case pairing
    case agentLanguage

    var id: String { rawValue }
}

enum DeviceListSortMode: Equatable {
    case recent
    case name
}

enum DeviceConnectionHelper {
    static let recentInterval: TimeInterval = 10 * 60

    static func latestDevice(from devices: [DeviceDTO]) -> DeviceDTO? {
        devices.sorted { lhs, rhs in
            timeValue(lhs.lastConnectedAt) > timeValue(rhs.lastConnectedAt)
        }.first
    }

    static func isRecentlyConnected(_ device: DeviceDTO) -> Bool {
        guard let date = date(from: device.lastConnectedAt) else { return false }
        return Date().timeIntervalSince(date) <= recentInterval
    }

    static func sortedDevices(_ devices: [DeviceDTO], mode: DeviceListSortMode) -> [DeviceDTO] {
        switch mode {
        case .recent:
            return devices.sorted { timeValue($0.lastConnectedAt) > timeValue($1.lastConnectedAt) }
        case .name:
            return devices.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    static func identityText(_ device: DeviceDTO) -> String {
        device.macAddress?.isEmpty == false ? device.macAddress! : device.id
    }

    static func boardText(_ device: DeviceDTO) -> String {
        device.board?.isEmpty == false ? device.board! : "--"
    }

    static func versionText(_ device: DeviceDTO) -> String {
        device.appVersion?.isEmpty == false ? device.appVersion! : "--"
    }

    static func formatLastConnected(_ value: String?, locale: String) -> String {
        guard let date = date(from: value) else {
            return L10n.tr("device.neverConnected", locale: locale)
        }

        let elapsed = Date().timeIntervalSince(date)
        if elapsed >= 0 && elapsed < 60 {
            return L10n.tr("device.justNow", locale: locale)
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.tr("device.todayAt", locale: locale, clockFormatter(locale: locale).string(from: date))
        }
        if calendar.isDateInYesterday(date) {
            return L10n.tr("device.yesterdayAt", locale: locale, clockFormatter(locale: locale).string(from: date))
        }

        return dateFormatter(locale: locale).string(from: date)
    }

    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = backendFormatter.date(from: value) {
            return date
        }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        return isoFormatter.date(from: normalized) ?? fallbackISOFormatter.date(from: normalized)
    }

    private static func timeValue(_ value: String?) -> TimeInterval {
        date(from: value)?.timeIntervalSince1970 ?? 0
    }

    private static func clockFormatter(locale: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.hasPrefix("zh") ? "zh_CN" : "en_US")
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private static func dateFormatter(locale: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.hasPrefix("zh") ? "zh_CN" : "en_US")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }

    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
