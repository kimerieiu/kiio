import Foundation
import Security

final class TokenStore {
    private let service = "com.kimerie.Kiio"
    private let account = "auth-token"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load() -> TokenDTO? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return try? decoder.decode(TokenDTO.self, from: data)
    }

    func save(_ token: TokenDTO) {
        guard let data = try? encoder.encode(token) else {
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
}
