//
//  AIProxyAppAttestKeyStore.swift
//  AIProxy
//

import Foundation
import Security

/// Persists the attested key ID between launches. One entry per scope.
nonisolated protocol AIProxyAppAttestKeyStore: Sendable {
    func keyID(for scope: String) throws -> String?
    func setKeyID(_ keyID: String, for scope: String) throws
    func deleteKeyID(for scope: String) throws
}

/// Keychain-backed store. Entries are device-only and never sync or back up,
/// which matches the key itself: an App Attest key lives in one Secure Enclave.
///
/// The service name and account format are shared with AIProxy's other Swift
/// packages, so an app that uses more than one of them attests once and every
/// package signs with the same key.
nonisolated struct AIProxyKeychainAppAttestKeyStore: AIProxyAppAttestKeyStore {
    static let defaultService = "com.aiproxy.app-attest"

    private let service: String

    init(service: String = Self.defaultService) {
        self.service = service
    }

    func keyID(for scope: String) throws -> String? {
        guard let data = try read(account(scope)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    func setKeyID(_ keyID: String, for scope: String) throws {
        try upsert(Data(keyID.utf8), at: account(scope))
    }

    func deleteKeyID(for scope: String) throws {
        try delete(account(scope))
    }

    private func account(_ scope: String) -> String {
        "\(scope)#key-id"
    }

    private func query(_ account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
    }

    private func read(_ account: String) throws -> Data? {
        var q = query(account)
        q[kSecReturnData] = true
        q[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw AIProxyError.appAttestKeychainError(status: status)
        }
    }

    private func upsert(_ data: Data, at account: String) throws {
        let q = query(account)
        let attrs: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        switch SecItemUpdate(q as CFDictionary, attrs as CFDictionary) {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var add = q
            add.merge(attrs) { _, new in new }
            switch SecItemAdd(add as CFDictionary, nil) {
            case errSecSuccess:
                return
            case errSecDuplicateItem:
                let retry = SecItemUpdate(q as CFDictionary, attrs as CFDictionary)
                guard retry == errSecSuccess else { throw AIProxyError.appAttestKeychainError(status: retry) }
            case let addStatus:
                throw AIProxyError.appAttestKeychainError(status: addStatus)
            }
        case let status:
            throw AIProxyError.appAttestKeychainError(status: status)
        }
    }

    private func delete(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIProxyError.appAttestKeychainError(status: status)
        }
    }
}
