import Foundation
import Security

enum TokenSessionState {
    case missing
    case expired
    case valid(TokenDTO)
}

final class TokenStore {
    private let service = "com.jbternal.kiio"
    private let account = "auth-token"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> TokenDTO? {
        guard case .valid(let token) = loadState() else {
            return nil
        }
        return token
    }

    func loadState(now: Date = Date()) -> TokenSessionState {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return .missing
        }

        guard let session = try? decoder.decode(StoredAuthSession.self, from: data),
              !session.token.isEmpty else {
            clear()
            return .missing
        }

        if session.isExpired(now: now) {
            clear()
            return .expired
        }

        return .valid(session.tokenDTO)
    }

    func expiresAt(now: Date = Date()) -> Date? {
        guard case .valid = loadState(now: now),
              let session = loadStoredSession() else {
            return nil
        }
        return session.expiresAt
    }

    func save(_ token: TokenDTO) {
        let session = StoredAuthSession(token: token, issuedAt: Date())
        guard let data = try? encoder.encode(session) else {
            return
        }

        clear()

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func loadStoredSession() -> StoredAuthSession? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(StoredAuthSession.self, from: data)
    }
}

private struct StoredAuthSession: Codable {
    let token: String
    let expire: Int?
    let clientHash: String?
    let issuedAt: Date?

    init(token: TokenDTO, issuedAt: Date) {
        self.token = token.token
        self.expire = token.expire
        self.clientHash = token.clientHash
        self.issuedAt = issuedAt
    }

    var tokenDTO: TokenDTO {
        TokenDTO(token: token, expire: expire, clientHash: clientHash)
    }

    var expiresAt: Date? {
        guard let issuedAt, let expire, expire > 0 else {
            return nil
        }
        return issuedAt.addingTimeInterval(TimeInterval(expire))
    }

    func isExpired(now: Date) -> Bool {
        guard let expiresAt else {
            return false
        }
        return now >= expiresAt
    }
}
