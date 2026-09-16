import KanbananaCore
import Foundation
import LocalAuthentication
import Security

package enum CredentialStatus: Equatable, Sendable {
    case checking, saved, missing, accessNeeded
    package var message: String {
        switch self {
        case .checking: "Checking saved key…"
        case .saved: "API key saved in macOS Keychain"
        case .missing: "No API key saved"
        case .accessNeeded: "Keychain access needed — your saved key has not been removed"
        }
    }
}

package protocol CredentialStorage: Sendable {
    func status() async -> CredentialStatus
    func load() async throws -> String
    func save(_ value: String) async throws
    func delete() async throws
}

package extension CredentialStorage {
    func delete() async throws { throw Keychain.Failure(status: errSecUnimplemented) }
}

package struct KeychainCredentials: CredentialStorage {
    package init() {}
    package func status() async -> CredentialStatus { await Task.detached(priority: .utility) { Keychain.status() }.value }
    package func load() async throws -> String { try await Task.detached(priority: .utility) { try Keychain.load() }.value }
    package func save(_ value: String) async throws { try await Task.detached(priority: .utility) { try Keychain.save(value) }.value }
    package func delete() async throws { try await Task.detached(priority: .utility) {
        let status = SecItemDelete(Keychain.query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Keychain.Failure(status: status) }
    }.value }
}

package enum Keychain {
    package static let service = "com.laurenceholt.agent-kanban"
    package static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "openai"]
    }
    package struct Failure: LocalizedError {
        package init(status: OSStatus) { self.status = status }
        package let status: OSStatus
        package var isMissing: Bool { status == errSecItemNotFound }
        package var errorDescription: String? {
            switch status {
            case errSecItemNotFound: "No saved API key was found. Add a key in Settings."
            case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
                "macOS has not allowed access to the saved key. Unlock Keychain or allow kanbanana in the macOS prompt, then retry. The key has not been removed."
            default: "Keychain could not complete the operation (\(status)). Your existing key has not been removed."
            }
        }
    }
    package static func status() -> CredentialStatus {
        var lookup = query
        lookup[kSecReturnAttributes as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        // Checking whether a key exists must never open a password dialog.
        let context = LAContext(); context.interactionNotAllowed = true
        lookup[kSecUseAuthenticationContext as String] = context
        var result: CFTypeRef?
        switch SecItemCopyMatching(lookup as CFDictionary, &result) {
        case errSecSuccess: return .saved
        case errSecItemNotFound: return .missing
        default: return .accessNeeded
        }
    }
    package static func load() throws -> String {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        guard status == errSecSuccess else { throw Failure(status: status) }
        guard let data = result as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else { throw Failure(status: errSecItemNotFound) }
        return key
    }
    package static func save(_ value: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw Failure(status: status) }
        var add = query
        add[kSecValueData as String] = data
        let added = SecItemAdd(add as CFDictionary, nil)
        guard added == errSecSuccess else { throw Failure(status: added) }
    }
}
