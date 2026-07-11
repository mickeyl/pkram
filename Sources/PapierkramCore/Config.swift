import Foundation

public struct PapierkramConfig: Codable, Equatable, Sendable {
    public var subdomain: String?
    public var defaultUserID: Int
    public var defaultCompanyID: Int?
    public var defaultProjectID: Int?
    public var defaultTaskID: Int?
    public var namedTasks: [String: Int]
    public var projectConfigPath: String?

    public init(
        subdomain: String? = nil,
        defaultUserID: Int = 1,
        defaultCompanyID: Int? = nil,
        defaultProjectID: Int? = nil,
        defaultTaskID: Int? = nil,
        namedTasks: [String: Int] = [:],
        projectConfigPath: String? = nil
    ) {
        self.subdomain = subdomain
        self.defaultUserID = defaultUserID
        self.defaultCompanyID = defaultCompanyID
        self.defaultProjectID = defaultProjectID
        self.defaultTaskID = defaultTaskID
        self.namedTasks = namedTasks
        self.projectConfigPath = projectConfigPath
    }

    enum CodingKeys: String, CodingKey {
        case subdomain
        case defaultUserID
        case defaultCompanyID
        case defaultProjectID
        case defaultTaskID
        case namedTasks
    }
}

public struct ProjectConfig: Codable, Equatable, Sendable {
    public var subdomain: String?
    public var companyID: Int?
    public var projectID: Int?
    public var taskID: Int?
    public var tasks: [String: Int]?
    public var userID: Int?

    public init(
        subdomain: String? = nil,
        companyID: Int? = nil,
        projectID: Int? = nil,
        taskID: Int? = nil,
        tasks: [String: Int]? = nil,
        userID: Int? = nil
    ) {
        self.subdomain = subdomain
        self.companyID = companyID
        self.projectID = projectID
        self.taskID = taskID
        self.tasks = tasks
        self.userID = userID
    }

    enum CodingKeys: String, CodingKey {
        case subdomain
        case companyID = "company_id"
        case projectID = "project_id"
        case taskID = "task_id"
        case tasks
        case userID = "user_id"
    }
}

public final class ConfigStore: Sendable {
    public static let projectConfigFilename = ".pkram"
    public static let maxProjectConfigSearchDepth = 8

    private let paths: AppPaths
    private let currentDirectory: URL
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public init(paths: AppPaths = AppPaths(), currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
        self.paths = paths
        self.currentDirectory = currentDirectory.standardizedFileURL
    }

    public func loadUserConfig() throws -> PapierkramConfig {
        var config = PapierkramConfig()
        if FileManager.default.fileExists(atPath: paths.configFile.path) {
            do {
                let data = try Data(contentsOf: paths.configFile)
                config = try decoder.decode(PapierkramConfig.self, from: data)
            } catch {
                throw PapierkramError.filesystem("Can't read config at \(paths.configFile.path): \(error.localizedDescription)")
            }
        }
        return config
    }

    public func load() throws -> PapierkramConfig {
        var config = try loadUserConfig()

        if let projectConfigFile = findProjectConfigFile() {
            do {
                let data = try Data(contentsOf: projectConfigFile)
                let projectConfig = try decoder.decode(ProjectConfig.self, from: data)
                if let subdomain = projectConfig.subdomain, !subdomain.isEmpty {
                    config.subdomain = subdomain
                }
                if let userID = projectConfig.userID {
                    config.defaultUserID = userID
                }
                config.defaultCompanyID = projectConfig.companyID
                config.defaultProjectID = projectConfig.projectID
                config.defaultTaskID = projectConfig.taskID
                config.namedTasks = projectConfig.tasks ?? [:]
                config.projectConfigPath = projectConfigFile.path
            } catch {
                throw PapierkramError.filesystem("Can't read project config at \(projectConfigFile.path): \(error.localizedDescription)")
            }
        }

        let environment = ProcessInfo.processInfo.environment
        if let subdomain = environment["PAPIERKRAM_SUBDOMAIN"], !subdomain.isEmpty {
            config.subdomain = subdomain
        }
        if let userID = environment["PAPIERKRAM_USER_ID"], let parsed = Int(userID) {
            config.defaultUserID = parsed
        }
        if let companyID = environment["PAPIERKRAM_COMPANY_ID"], let parsed = Int(companyID) {
            config.defaultCompanyID = parsed
        }
        if let projectID = environment["PAPIERKRAM_PROJECT_ID"], let parsed = Int(projectID) {
            config.defaultProjectID = parsed
        }
        if let taskID = environment["PAPIERKRAM_TASK_ID"], let parsed = Int(taskID) {
            config.defaultTaskID = parsed
        }
        return config
    }

    public func save(_ config: PapierkramConfig) throws {
        do {
            try paths.ensureConfigDirectory()
            let data = try encoder.encode(config)
            try data.write(to: paths.configFile, options: [.atomic])
        } catch let error as PapierkramError {
            throw error
        } catch {
            throw PapierkramError.filesystem("Can't write config at \(paths.configFile.path): \(error.localizedDescription)")
        }
    }

    public var configPath: String {
        paths.configFile.path
    }

    public func findProjectConfigFile() -> URL? {
        let searchDirectories = projectSearchDirectories()
        for directory in searchDirectories {
            let candidate = directory.appendingPathComponent(Self.projectConfigFilename)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    public func projectSearchDirectories() -> [URL] {
        var directories = [currentDirectory]
        var cursor = currentDirectory
        var parents: [URL] = []
        var foundGitRoot = false

        for _ in 0..<Self.maxProjectConfigSearchDepth {
            if hasGitMarker(in: cursor) {
                foundGitRoot = true
                break
            }

            let parent = cursor.deletingLastPathComponent().standardizedFileURL
            if parent.path == cursor.path {
                break
            }
            parents.append(parent)
            cursor = parent
        }

        guard foundGitRoot else {
            return directories
        }

        for parent in parents {
            if !directories.contains(parent) {
                directories.append(parent)
            }
            if hasGitMarker(in: parent) {
                break
            }
        }
        return directories
    }

    private func hasGitMarker(in directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(".git").path)
    }
}
