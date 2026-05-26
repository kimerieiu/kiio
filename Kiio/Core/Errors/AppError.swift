import Foundation

enum AppError: Error, Identifiable, LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyData
    case unauthorized
    case server(String)
    case transport(String)
    case decoding(String)

    var id: String {
        errorDescription ?? "unknown"
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is invalid."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .emptyData:
            return "The server returned no data."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .server(let message):
            return message
        case .transport(let message):
            return message
        case .decoding(let message):
            return "Unable to read server response: \(message)"
        }
    }

    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        return .transport(error.localizedDescription)
    }
}
