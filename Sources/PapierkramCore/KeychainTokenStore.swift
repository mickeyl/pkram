import Foundation
import Security

public final class KeychainTokenStore {
    public static let defaultService = "papierkram-api-key"

    private let service: String

    public init(service: String = KeychainTokenStore.defaultService) {
        self.service = service
    }

    public func readToken(account: String) throws -> String {
        if let token = try readTokenWithSecurityTool(account: account) {
            return token
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = false
        #endif

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            throw PapierkramError.apiKeyMissing(subdomain: account)
        }
        guard status == errSecSuccess else {
            throw PapierkramError.keychain(Self.message(for: status))
        }
        guard let data = result as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw PapierkramError.keychain("Stored token for '\(account)' is empty or unreadable.")
        }
        return token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func saveToken(_ token: String, account: String) throws {
        let data = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        guard !data.isEmpty else {
            throw PapierkramError.keychain("Refusing to store an empty token.")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw PapierkramError.keychain(Self.message(for: updateStatus))
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PapierkramError.keychain(Self.message(for: addStatus))
        }
    }

    /// Removes the stored token. Returns false when there was nothing to remove,
    /// so callers can tell "cleaned up" from "was never there" without reading the token.
    @discardableResult
    public func deleteToken(account: String) throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
            case errSecSuccess:
                return true
            case errSecItemNotFound:
                return false
            default:
                throw PapierkramError.keychain(Self.message(for: status))
        }
    }

    /// Whether a non-empty token is stored, without handing the token to the caller.
    public func hasToken(account: String) -> Bool {
        ((try? readToken(account: account)) ?? "").isEmpty == false
    }

    private static func message(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "OSStatus \(status)"
    }

    private func readTokenWithSecurityTool(account: String) throws -> String? {
        let executable = URL(fileURLWithPath: "/usr/bin/security")
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            return nil
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "find-generic-password",
            "-a", account,
            "-s", service,
            "-w"
        ]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let token = String(decoding: outputData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0, !token.isEmpty {
            return token
        }

        let message = String(decoding: errorData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains("could not be found") || message.contains("The specified item could not be found") {
            throw PapierkramError.apiKeyMissing(subdomain: account)
        }

        // Fall back to Security.framework for unusual environments where the
        // security tool exists but cannot be launched through Process.
        if message.isEmpty {
            return nil
        }
        throw PapierkramError.keychain(message)
    }
}
