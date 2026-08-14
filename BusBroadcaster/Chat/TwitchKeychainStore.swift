import Foundation
import Security

// MARK: - TwitchKeychainStore
/// Stores and retrieves the Twitch OAuth access token from the macOS Keychain.
/// Service key: "com.busbroadcaster.twitch.token"
/// Credentials are never printed or logged.
enum TwitchKeychainStore {

    private static let service  = "com.busbroadcaster.twitch.token"
    private static let account  = "oauth"

    // MARK: - Read
    static func token() -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let tok  = String(data: data, encoding: .utf8)
        else { return nil }
        return tok
    }

    // MARK: - Write
    static func store(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        let deleteQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [CFString: Any] = [
            kSecClass:                 kSecClassGenericPassword,
            kSecAttrService:           service,
            kSecAttrAccount:           account,
            kSecValueData:             data,
            kSecAttrAccessible:        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    // MARK: - Delete
    static func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}