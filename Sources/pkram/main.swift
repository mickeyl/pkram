import ArgumentParser
import Foundation
import PapierkramCore

@main
struct PKRam: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pkram",
        abstract: "Track Papierkram work time from the terminal.",
        version: "1.0.0",
        subcommands: [
            Auth.self,
            Config.self,
            Projects.self,
            Tasks.self,
            Entries.self,
            Timer.self
        ]
    )
}

struct ClientContext {
    let config: PapierkramConfig
    let configStore: ConfigStore
    let client: PapierkramClient

    static func load() throws -> ClientContext {
        let configStore = ConfigStore()
        let config = try configStore.load()
        return try ClientContext(
            config: config,
            configStore: configStore,
            client: PapierkramClient(config: config)
        )
    }
}

func printJSON(_ value: JSONValue) throws {
    print(try value.prettyPrinted())
}

func printRows(_ rows: [[String: String]], columns: [(key: String, title: String)]) {
    print(Table.render(rows: rows, columns: columns))
}

func optionalComment(_ value: String?) -> String? {
    guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    return value
}

func requireValue<T>(_ value: T?, message: String) throws -> T {
    guard let value else {
        throw ValidationError(message)
    }
    return value
}

/// Resolves `--task` from either a numeric ID or a name declared under `tasks` in .pkram.
func resolveTask(_ value: String?, config: PapierkramConfig) throws -> Int? {
    guard let value, !value.isEmpty else { return nil }
    if let id = Int(value) { return id }
    if let id = config.namedTasks[value] { return id }
    let known = config.namedTasks.keys.sorted().joined(separator: ", ")
    let hint = known.isEmpty ? "no named tasks are configured" : "known names: \(known)"
    throw PapierkramError.filesystem("Unknown task '\(value)' (\(hint)). Pass a numeric ID or add the name to tasks in .pkram.")
}

func requireConfirmation(_ prompt: String, force: Bool) throws {
    if force {
        return
    }
    FileHandle.standardError.write(Data((prompt + " Type 'yes' to continue: ").utf8))
    guard let answer = readLine(), answer == "yes" else {
        throw ExitCode(2)
    }
}

func requireReturnConfirmation(_ summary: String, force: Bool) throws {
    if force {
        return
    }
    guard isatty(STDIN_FILENO) == 1 else {
        throw ValidationError("Confirmation is required for creating time entries. Re-run with --force in non-interactive use.")
    }
    FileHandle.standardError.write(Data((summary + "\nPress Return to create this entry, or type anything else to cancel: ").utf8))
    guard let answer = readLine(), answer.isEmpty else {
        throw ExitCode(2)
    }
}

func readSecret(prompt: String) throws -> String {
    FileHandle.standardError.write(Data(prompt.utf8))
    var oldTerm = termios()
    var newTerm = termios()
    let fd = STDIN_FILENO
    let isTerminal = isatty(fd) == 1

    if isTerminal, tcgetattr(fd, &oldTerm) == 0 {
        newTerm = oldTerm
        newTerm.c_lflag &= ~UInt(ECHO)
        _ = tcsetattr(fd, TCSANOW, &newTerm)
    }
    defer {
        if isTerminal {
            _ = tcsetattr(fd, TCSANOW, &oldTerm)
            FileHandle.standardError.write(Data("\n".utf8))
        }
    }

    guard let line = readLine(), !line.isEmpty else {
        throw PapierkramError.keychain("No token was provided.")
    }
    return line
}

func usesColorOnStderr(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
    guard isatty(STDERR_FILENO) == 1 else {
        return false
    }
    if environment["NO_COLOR"] != nil {
        return false
    }
    if environment["TERM"] == "dumb" {
        return false
    }
    return true
}

func styled(_ value: String, code: String, enabled: Bool) -> String {
    guard enabled else {
        return value
    }
    return "\u{001B}[\(code)m\(value)\u{001B}[0m"
}

func hoursDisplay(from startDate: Date, to endDate: Date) -> String {
    let minutes = Int(endDate.timeIntervalSince(startDate) / 60)
    if minutes % 60 == 0 {
        return "\(minutes / 60) h"
    }
    return String(format: "%.2f h", Double(minutes) / 60.0)
}

func quoted(_ value: String?) -> String {
    "\"\(value ?? "")\""
}

func jsonName(_ value: JSONValue, fallback: String) -> String {
    value["name"]?.stringValue ?? fallback
}

func jsonID(_ value: JSONValue, keys: [String]) -> Int? {
    for key in keys {
        if let id = value[key]?.intValue {
            return id
        }
    }
    return nil
}

func confirmationSummary(
    context: ClientContext,
    taskID: Int,
    entryDate: String,
    startedAtTime: String,
    endedAtTime: String,
    startDate: Date,
    endDate: Date,
    comment: String?,
    color: Bool = usesColorOnStderr()
) async throws -> String {
    let task = try await context.client.getTask(id: taskID)
    let projectID = jsonID(task, keys: ["project_id"]) ?? task["project"]?["id"]?.intValue
    let project: JSONValue
    if let projectID {
        project = try await context.client.getProject(id: projectID)
    } else {
        project = task["project"] ?? .object([:])
    }

    let companyID = project["customer"]?["id"]?.intValue ?? project["company_id"]?.intValue
    let companyName: String
    if let name = project["customer"]?["name"]?.stringValue {
        companyName = name
    } else if let companyID {
        companyName = jsonName(try await context.client.getCompany(id: companyID), fallback: "ID \(companyID)")
    } else {
        companyName = "-"
    }

    let projectName = jsonName(project, fallback: projectID.map { "ID \($0)" } ?? "-")
    let taskName = jsonName(task, fallback: "ID \(taskID)")
    let heading = styled("Create time entry:", code: "1", enabled: color)
    let customer = styled(companyName, code: "36;1", enabled: color)
    let styledProject = styled(projectName, code: "34;1", enabled: color)
    let styledTask = styled(taskName, code: "35;1", enabled: color)
    let date = styled(entryDate, code: "33;1", enabled: color)
    let start = styled(startedAtTime, code: "32;1", enabled: color)
    let end = styled(endedAtTime, code: "32;1", enabled: color)
    let hours = styled(hoursDisplay(from: startDate, to: endDate), code: "33;1", enabled: color)
    let text = styled(quoted(comment), code: "1", enabled: color)
    return "\(heading) Kunde \(customer), Projekt \(styledProject), Aufgabe \(styledTask), am \(date) von \(start) bis \(end) = \(hours) für \(text)."
}

struct Auth: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage Papierkram authentication.",
        subcommands: [SetToken.self, Check.self, Status.self, Delete.self]
    )

    struct SetToken: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set-token",
            abstract: "Store the Papierkram API token in macOS Keychain."
        )

        @Flag(help: "Read the token from stdin instead of prompting.")
        var stdin = false

        func run() throws {
            let config = try ConfigStore().load()
            let token: String
            if stdin {
                let data = FileHandle.standardInput.readDataToEndOfFile()
                token = String(decoding: data, as: UTF8.self)
            } else {
                token = try readSecret(prompt: "Paste Papierkram API token: ")
            }

            let account = try PapierkramClient.resolveSubdomain(config)
            try KeychainTokenStore().saveToken(token, account: account)
            print("Stored token for \(account) in Keychain service \(KeychainTokenStore.defaultService).")
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Report whether a token is stored, without printing it."
        )

        func run() throws {
            let config = try ConfigStore().load()
            let account = try PapierkramClient.resolveSubdomain(config)
            let stored = KeychainTokenStore().hasToken(account: account)
            print("subdomain: \(account)")
            print("keychain_service: \(KeychainTokenStore.defaultService)")
            print("token_stored: \(stored ? "yes" : "no")")
            if !stored {
                print("Run `pkram auth set-token` to store one.")
            }
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove the stored Papierkram API token from macOS Keychain."
        )

        @Flag(name: [.customShort("f"), .long], help: "Delete without interactive confirmation.")
        var force = false

        func run() throws {
            let config = try ConfigStore().load()
            let account = try PapierkramClient.resolveSubdomain(config)
            if !force {
                FileHandle.standardError.write(
                    Data("Remove the stored token for \(account)? Type 'yes' to continue: ".utf8))
                guard readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) == "yes" else {
                    print("Kept the stored token.")
                    return
                }
            }
            if try KeychainTokenStore().deleteToken(account: account) {
                print("Removed the token for \(account).")
            } else {
                print("No token was stored for \(account).")
            }
        }
    }

    struct Check: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify that authentication works."
        )

        func run() async throws {
            let context = try ClientContext.load()
            _ = try await context.client.listProjects(query: ListQuery(page: 1, pageSize: 1))
            print("Authentication works for \(context.config.subdomain).")
        }
    }
}

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Read and write local pkram configuration.",
        subcommands: [Show.self, Set.self]
    )

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show current configuration.")

        func run() throws {
            let store = ConfigStore()
            let config = try store.load()
            print("subdomain: \(config.subdomain ?? "-")")
            print("default_user_id: \(config.defaultUserID)")
            print("default_company_id: \(config.defaultCompanyID.map(String.init) ?? "-")")
            print("default_project_id: \(config.defaultProjectID.map(String.init) ?? "-")")
            print("default_task_id: \(config.defaultTaskID.map(String.init) ?? "-")")
            let named = config.namedTasks.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            print("tasks: \(named.isEmpty ? "-" : named)")
            print("user_config_path: \(store.configPath)")
            print("project_config_path: \(config.projectConfigPath ?? "-")")
        }
    }

    struct Set: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Set a config value.")

        @Argument(help: "Config key: subdomain or default-user-id.")
        var key: String

        @Argument(help: "New value.")
        var value: String

        func run() throws {
            let store = ConfigStore()
            var config = try store.loadUserConfig()
            switch key {
            case "subdomain":
                config.subdomain = value
            case "default-user-id":
                guard let userID = Int(value), userID > 0 else {
                    throw ValidationError("default-user-id must be a positive integer.")
                }
                config.defaultUserID = userID
            default:
                throw ValidationError("Unknown config key '\(key)'. Use subdomain or default-user-id.")
            }
            try store.save(config)
            print("Updated \(key) in \(store.configPath).")
        }
    }
}

struct Projects: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List Papierkram projects.",
        subcommands: [List.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List projects.")

        @Option(name: [.customShort("c"), .long], help: "Filter by customer/company ID.")
        var company: Int?

        @Flag(name: [.customShort("a"), .long], help: "Ignore .pkram company_id and list all projects.")
        var all = false

        @Option(help: "Page number.")
        var page: Int = 1

        @Option(name: .long, help: "Items per page.")
        var pageSize: Int = 50

        @Flag(name: .long, help: "Print raw JSON response.")
        var json = false

        func run() async throws {
            let context = try ClientContext.load()
            var filters: [String: String] = [:]
            if all, company != nil {
                throw ValidationError("Use either --all or --company, not both.")
            }
            if !all, let company = company ?? context.config.defaultCompanyID {
                filters["company_id"] = String(company)
            }
            let result = try await context.client.listProjects(
                query: ListQuery(page: page, pageSize: pageSize, orderBy: "name", orderDirection: "asc", filters: filters)
            )
            if json {
                try printJSON(result)
            } else {
                printRows(
                    JSONCompaction.compactProjects(result),
                    columns: [
                        ("id", "ID"),
                        ("name", "Name"),
                        ("record_state", "State"),
                        ("company_id", "Company")
                    ]
                )
            }
        }
    }
}

struct Tasks: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List Papierkram tasks.",
        subcommands: [List.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List tasks.")

        @Option(name: [.customShort("p"), .long], help: "Filter by project ID.")
        var project: Int?

        @Option(help: "Page number.")
        var page: Int = 1

        @Option(name: .long, help: "Items per page.")
        var pageSize: Int = 50

        @Flag(name: .long, help: "Print raw JSON response.")
        var json = false

        func run() async throws {
            let context = try ClientContext.load()
            var filters: [String: String] = [:]
            if let project = project ?? context.config.defaultProjectID {
                filters["project_id"] = String(project)
                if self.project == nil, !json {
                    FileHandle.standardError.write(
                        Data("Note: limited to project \(project) from \(context.config.projectConfigPath ?? "config").\n".utf8))
                }
            }
            let result = try await context.client.listTasks(
                query: ListQuery(page: page, pageSize: pageSize, orderBy: "name", orderDirection: "asc", filters: filters)
            )
            if json {
                try printJSON(result)
            } else {
                printRows(
                    JSONCompaction.compactTasks(result),
                    columns: [
                        ("id", "ID"),
                        ("name", "Name"),
                        ("project_id", "Project"),
                        ("complete", "Done")
                    ]
                )
            }
        }
    }
}

struct Entries: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List, create, and delete Papierkram time entries.",
        subcommands: [List.self, Add.self, Delete.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List time entries.")

        @Option(help: "Start date: YYYY-MM-DD, today, yesterday, or tomorrow.")
        var from: String = "today"

        @Option(help: "End date: YYYY-MM-DD, today, yesterday, or tomorrow.")
        var to: String = "today"

        @Option(name: [.customShort("p"), .long], help: "Filter by project ID.")
        var project: Int?

        @Option(name: [.customShort("t"), .long], help: "Filter by task ID or a name from tasks in .pkram. Not defaulted from .pkram.")
        var task: String?

        @Option(help: "Page number.")
        var page: Int = 1

        @Option(name: .long, help: "Items per page.")
        var pageSize: Int = 50

        @Flag(name: .long, help: "Print raw JSON response.")
        var json = false

        func run() async throws {
            let context = try ClientContext.load()
            let fromDate = try DateParsing.parseDay(from)
            let toDate = try DateParsing.parseDay(to)
            let range = try DateParsing.rfc3339Range(from: fromDate, to: toDate)
            var filters: [String: String] = [
                "start_time_range_start": range.0,
                "start_time_range_end": range.1,
                "user_id": String(context.config.defaultUserID)
            ]
            if let project = project ?? context.config.defaultProjectID {
                filters["project_id"] = String(project)
                if self.project == nil, !json {
                    FileHandle.standardError.write(
                        Data("Note: limited to project \(project) from \(context.config.projectConfigPath ?? "config").\n".utf8))
                }
            }
            // Deliberately not falling back to defaultTaskID: a listing silently narrowed
            // to one task looks identical to "nothing was booked that day".
            if let task = try resolveTask(task, config: context.config) {
                filters["task_id"] = String(task)
            }
            let result = try await context.client.listTimeEntries(
                query: ListQuery(page: page, pageSize: pageSize, orderBy: "started_at", orderDirection: "asc", filters: filters)
            )
            if json {
                try printJSON(result)
            } else {
                printRows(
                    JSONCompaction.compactTimeEntries(result),
                    columns: [
                        ("id", "ID"),
                        ("started_at", "Start"),
                        ("ended_at", "End"),
                        ("duration", "Duration"),
                        ("task_id", "Task"),
                        ("comments", "Comment")
                    ]
                )
            }
        }
    }

    struct Add: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a time entry.")

        @Option(name: [.customShort("t"), .long], help: "Task ID or a name from tasks in .pkram. Defaults to .pkram task_id.")
        var task: String?

        @Option(help: "Entry date: YYYY-MM-DD, today, yesterday, or tomorrow.")
        var date: String = "today"

        @Option(help: "Start time as HH:MM.")
        var start: String

        @Option(help: "End time as HH:MM.")
        var end: String

        @Option(name: [.customShort("m"), .long], help: "Work comment.")
        var comment: String?

        @Option(help: "User ID. Defaults to config default-user-id.")
        var user: Int?

        @Flag(help: "Mark as unbillable.")
        var unbillable = false

        @Flag(name: [.customShort("f"), .long], help: "Create without interactive confirmation.")
        var force = false

        @Flag(name: .long, help: "Print raw JSON response.")
        var json = false

        func run() async throws {
            let context = try ClientContext.load()
            let taskID = try requireValue(
                try resolveTask(task, config: context.config) ?? context.config.defaultTaskID,
                message: "Missing task ID. Pass --task <id> or set task_id in .pkram."
            )
            let day = try DateParsing.parseDay(date)
            let startDate = try DateParsing.dateTime(day: day, time: start)
            let endDate = try DateParsing.dateTime(day: day, time: end)
            guard endDate > startDate else {
                throw PapierkramError.invalidDuration
            }

            let entry = NewTimeEntry(
                entryDate: DateParsing.dayString(day),
                startedAtTime: try DateParsing.validateTime(start),
                endedAtTime: try DateParsing.validateTime(end),
                comments: optionalComment(comment),
                unbillable: unbillable,
                taskID: taskID,
                userID: user ?? context.config.defaultUserID
            )
            if !force {
                let summary = try await confirmationSummary(
                    context: context,
                    taskID: taskID,
                    entryDate: entry.entryDate,
                    startedAtTime: entry.startedAtTime,
                    endedAtTime: entry.endedAtTime,
                    startDate: startDate,
                    endDate: endDate,
                    comment: entry.comments
                )
                try requireReturnConfirmation(summary, force: false)
            }

            let result = try await context.client.createTimeEntry(entry)
            if json {
                try printJSON(result)
            } else {
                let id = result["id"]?.stringValue ?? "created"
                print("Created time entry \(id) for task \(taskID).")
            }
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Delete a time entry.")

        @Argument(help: "Time entry ID.")
        var id: Int

        @Flag(name: [.customShort("f"), .long], help: "Delete without confirmation.")
        var force = false

        func run() async throws {
            try requireConfirmation("Delete time entry \(id)?", force: force)
            let context = try ClientContext.load()
            try await context.client.deleteTimeEntry(id: id)
            print("Deleted time entry \(id).")
        }
    }
}

struct Timer: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Track a local timer and submit it as a Papierkram time entry.",
        subcommands: [Start.self, Status.self, Stop.self, Cancel.self]
    )

    struct Start: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Start a local timer.")

        @Option(name: [.customShort("t"), .long], help: "Task ID or a name from tasks in .pkram. Defaults to .pkram task_id.")
        var task: String?

        @Option(name: [.customShort("m"), .long], help: "Work comment.")
        var comment: String?

        @Option(help: "User ID. Defaults to config default-user-id.")
        var user: Int?

        @Flag(help: "Mark resulting entry as unbillable.")
        var unbillable = false

        func run() throws {
            let config = try ConfigStore().load()
            let taskID = try requireValue(
                try resolveTask(task, config: config) ?? config.defaultTaskID,
                message: "Missing task ID. Pass --task <id> or set task_id in .pkram."
            )
            let session = TimerSession(
                taskID: taskID,
                userID: user ?? config.defaultUserID,
                comments: optionalComment(comment),
                unbillable: unbillable
            )
            try TimerStore().start(session)
            print("Started timer for task \(taskID) at \(DateParsing.timeFormatter.string(from: session.startedAt)).")
        }
    }

    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Show the running timer.")

        func run() throws {
            guard let session = try TimerStore().load() else {
                print("No timer running.")
                return
            }
            let elapsed = Date().timeIntervalSince(session.startedAt)
            let minutes = Int(elapsed / 60)
            print("Task: \(session.taskID)")
            print("Started: \(session.startedAtDisplay)")
            print("Elapsed: \(minutes / 60)h \(minutes % 60)m")
            if let comments = session.comments {
                print("Comment: \(comments)")
            }
            if session.unbillable {
                print("Unbillable: true")
            }
        }
    }

    struct Stop: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Stop the timer and create a Papierkram time entry.")

        @Option(name: [.customShort("m"), .long], help: "Override work comment.")
        var comment: String?

        @Flag(help: "Print the entry that would be created, without sending it.")
        var dryRun = false

        @Flag(name: .long, help: "Print raw JSON response.")
        var json = false

        func run() async throws {
            let store = TimerStore()
            var session = try store.load() ?? {
                throw PapierkramError.noTimerRunning
            }()
            if let comment = optionalComment(comment) {
                session.comments = comment
            }
            let entry = try session.entry()

            if dryRun {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(entry)
                print(String(decoding: data, as: UTF8.self))
                return
            }

            _ = try store.stop()
            do {
                let context = try ClientContext.load()
                let result = try await context.client.createTimeEntry(entry)
                if json {
                    try printJSON(result)
                } else {
                    let id = result["id"]?.stringValue ?? "created"
                    print("Stopped timer and created time entry \(id) for task \(session.taskID).")
                }
            } catch {
                try? store.start(session)
                throw error
            }
        }
    }

    struct Cancel: ParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Cancel the running local timer without submitting it.")

        @Flag(name: [.customShort("f"), .long], help: "Cancel without confirmation.")
        var force = false

        func run() throws {
            try requireConfirmation("Cancel the running timer?", force: force)
            try TimerStore().cancel()
            print("Canceled timer.")
        }
    }
}
