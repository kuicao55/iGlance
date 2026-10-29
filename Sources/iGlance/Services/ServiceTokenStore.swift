import Foundation
import Security

protocol ServiceTokenStoring: AnyObject {
    func token(for id: UUID) -> String?
    func setToken(_ token: String?, for id: UUID)
    func deleteToken(for id: UUID)
}

/// Tokens are stored as generic passwords in the user's Keychain, keyed by the
/// binding UUID. They never touch UserDefaults or the JSON bindings file.
final class KeychainServiceTokenStore: ServiceTokenStoring {
    private let service = "com.kui.iGlance.service-token"

    func token(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setToken(_ token: String?, for id: UUID) {
        guard let token, !token.isEmpty else {
            deleteToken(for: id)
            return
        }

        let data = Data(token.utf8)
        let query = baseQuery(for: id)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    func deleteToken(for id: UUID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }

    private func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
    }
}

/// Used by tests and previews so no Keychain access is required.
final class InMemoryServiceTokenStore: ServiceTokenStoring {
    private var tokens: [UUID: String] = [:]

    func token(for id: UUID) -> String? { tokens[id] }

    func setToken(_ token: String?, for id: UUID) {
        guard let token, !token.isEmpty else {
            tokens.removeValue(forKey: id)
            return
        }
        tokens[id] = token
    }

    func deleteToken(for id: UUID) {
        tokens.removeValue(forKey: id)
    }
}
