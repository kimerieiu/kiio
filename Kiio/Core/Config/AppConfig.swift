import Foundation

enum AppConfig {
    static let debugAPIBaseURL = "https://api.jbternal.com/xiaozhi"
    static let releasePlaceholderAPIBaseURL = "https://api.jbternal.com/xiaozhi"
    static let requestTimeout: TimeInterval = 30

    static var apiBaseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "KIIO_API_BASE_URL") as? String

        #if DEBUG
        let rawValue = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? debugAPIBaseURL
        #else
        let rawValue = configured?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? releasePlaceholderAPIBaseURL
        #endif

        guard let url = URL(string: rawValue) else {
            return URL(string: debugAPIBaseURL)!
        }

        return url
    }
}
