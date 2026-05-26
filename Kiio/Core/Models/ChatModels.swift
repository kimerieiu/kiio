import Foundation

struct ChatSessionDTO: Decodable, Identifiable, Equatable {
    let sessionId: String
    let createdAt: String?
    let chatCount: Int?

    var id: String { sessionId }
}

struct ChatMessageDTO: Decodable, Identifiable, Equatable {
    let createdAt: String?
    let chatType: Int?
    let content: String?
    let audioId: String?
    let macAddress: String?

    var id: String {
        "\(createdAt ?? "")-\(chatType ?? 0)-\(content ?? "")"
    }

    var isUserMessage: Bool {
        chatType == 1
    }

    var isAgentMessage: Bool {
        chatType == 2
    }

    var isVisibleConversationMessage: Bool {
        isUserMessage || isAgentMessage
    }

    var displayContent: String {
        guard let content else { return "" }
        guard isUserMessage,
              let data = content.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nested = object["content"] as? String else {
            return content
        }
        return nested
    }
}
