import Foundation

public struct AppPaths: Sendable {
    public let configDirectory: URL
    public let stateDirectory: URL

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        let configBase = environment["XDG_CONFIG_HOME"].map(URL.init(fileURLWithPath:))
            ?? homeDirectory.appendingPathComponent(".config", isDirectory: true)
        let stateBase = environment["XDG_STATE_HOME"].map(URL.init(fileURLWithPath:))
            ?? homeDirectory.appendingPathComponent(".local/state", isDirectory: true)

        self.configDirectory = configBase.appendingPathComponent("pkram", isDirectory: true)
        self.stateDirectory = stateBase.appendingPathComponent("pkram", isDirectory: true)
    }

    public var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    public var timerFile: URL {
        stateDirectory.appendingPathComponent("timer.json")
    }

    public func ensureConfigDirectory() throws {
        try ensureDirectory(configDirectory)
    }

    public func ensureStateDirectory() throws {
        try ensureDirectory(stateDirectory)
    }

    private func ensureDirectory(_ url: URL) throws {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw PapierkramError.filesystem("Can't create \(url.path): \(error.localizedDescription)")
        }
    }
}
