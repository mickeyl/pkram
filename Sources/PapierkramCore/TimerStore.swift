import Foundation

public struct TimerSession: Codable, Equatable, Sendable {
    public var taskID: Int
    public var userID: Int
    public var startedAt: Date
    public var comments: String?
    public var unbillable: Bool

    public init(taskID: Int, userID: Int, startedAt: Date = Date(), comments: String? = nil, unbillable: Bool = false) {
        self.taskID = taskID
        self.userID = userID
        self.startedAt = startedAt
        self.comments = comments
        self.unbillable = unbillable
    }

    public var startedAtDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: startedAt)
    }

    public func entry(endedAt: Date = Date(), minimumMinutes: Int = 1) throws -> NewTimeEntry {
        guard endedAt > startedAt else {
            throw PapierkramError.invalidDuration
        }

        let calendar = Calendar.current
        let adjustedEnd = max(endedAt, startedAt.addingTimeInterval(TimeInterval(minimumMinutes * 60)))
        let entryDate = DateParsing.dayString(startedAt)
        let startTime = DateParsing.timeFormatter.string(from: startedAt)
        var endTime = DateParsing.timeFormatter.string(from: adjustedEnd)

        if !calendar.isDate(startedAt, inSameDayAs: adjustedEnd) {
            let endOfStartDay = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: startedAt) ?? adjustedEnd
            endTime = DateParsing.timeFormatter.string(from: endOfStartDay)
        }

        return NewTimeEntry(
            entryDate: entryDate,
            startedAtTime: startTime,
            endedAtTime: endTime,
            comments: comments,
            unbillable: unbillable,
            taskID: taskID,
            userID: userID
        )
    }
}

public final class TimerStore {
    private let paths: AppPaths
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(paths: AppPaths = AppPaths()) {
        self.paths = paths
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public var timerPath: String {
        paths.timerFile.path
    }

    public func load() throws -> TimerSession? {
        guard FileManager.default.fileExists(atPath: paths.timerFile.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: paths.timerFile)
            return try decoder.decode(TimerSession.self, from: data)
        } catch {
            throw PapierkramError.filesystem("Can't read timer state at \(paths.timerFile.path): \(error.localizedDescription)")
        }
    }

    public func start(_ session: TimerSession) throws {
        if let existing = try load() {
            throw PapierkramError.timerAlreadyRunning(existing)
        }
        do {
            try paths.ensureStateDirectory()
            let data = try encoder.encode(session)
            try data.write(to: paths.timerFile, options: [.atomic])
        } catch let error as PapierkramError {
            throw error
        } catch {
            throw PapierkramError.filesystem("Can't write timer state at \(paths.timerFile.path): \(error.localizedDescription)")
        }
    }

    public func stop() throws -> TimerSession {
        guard let session = try load() else {
            throw PapierkramError.noTimerRunning
        }
        do {
            try FileManager.default.removeItem(at: paths.timerFile)
        } catch {
            throw PapierkramError.filesystem("Can't remove timer state at \(paths.timerFile.path): \(error.localizedDescription)")
        }
        return session
    }

    public func cancel() throws {
        guard FileManager.default.fileExists(atPath: paths.timerFile.path) else {
            throw PapierkramError.noTimerRunning
        }
        do {
            try FileManager.default.removeItem(at: paths.timerFile)
        } catch {
            throw PapierkramError.filesystem("Can't remove timer state at \(paths.timerFile.path): \(error.localizedDescription)")
        }
    }
}
