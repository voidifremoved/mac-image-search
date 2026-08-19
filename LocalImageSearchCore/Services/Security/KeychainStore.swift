import Foundation
import Security

public protocol SecretStoring: Sendable {
    func setSecret(_ secret: String, forKey key: String) throws
    func getSecret(forKey key: String) throws -> String?
    func deleteSecret(forKey key: String) throws
}

public final class KeychainStore: SecretStoring, @unchecked Sendable {
    private let service: String
    private let memoryFallback = InMemorySecretStore()

    public init(service: String = "com.localimagesearch.secrets") {
        self.service = service
    }

    public func setSecret(_ secret: String, forKey key: String) throws {
        try memoryFallback.setSecret(secret, forKey: key)
        guard let data = secret.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        // Try deleting existing item first to avoid signature/auth conflicts across debug builds
        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(newQuery as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            // If Keychain denies access (e.g. unsigned CLI tool in development), memory fallback is preserved
            AppLogger.security.warning("Keychain write status: \(addStatus), using memory/defaults fallback")
        }
    }

    public func getSecret(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecSuccess, let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }

        // If auth failed (-25293), item not found (-25300), or interaction not allowed, check memory fallback
        if let fallback = try? memoryFallback.getSecret(forKey: key), !fallback.isEmpty {
            return fallback
        }

        if status == errSecItemNotFound || status == -25293 || status == -25308 {
            return nil
        }

        return nil
    }

    public func deleteSecret(forKey key: String) throws {
        try memoryFallback.deleteSecret(forKey: key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: String] = [:]

    public init() {}

    public func setSecret(_ secret: String, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = secret
    }

    public func getSecret(forKey key: String) throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func deleteSecret(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }
}
