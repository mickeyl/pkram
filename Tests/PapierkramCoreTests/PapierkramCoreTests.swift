import XCTest
@testable import PapierkramCore

final class PapierkramCoreTests: XCTestCase {
    private var temporaryURLs: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryURLs.removeAll()
        try super.tearDownWithError()
    }

    func testRelativeDayParsingUsesProvidedNow() throws {
        let now = DateParsing.dayFormatter.date(from: "2026-07-05")!

        XCTAssertEqual(DateParsing.dayString(try DateParsing.parseDay("today", now: now)), "2026-07-05")
        XCTAssertEqual(DateParsing.dayString(try DateParsing.parseDay("yesterday", now: now)), "2026-07-04")
        XCTAssertEqual(DateParsing.dayString(try DateParsing.parseDay("tomorrow", now: now)), "2026-07-06")
    }

    func testTimerSessionBuildsTimeEntry() throws {
        let day = try DateParsing.parseDay("2026-07-05")
        let start = try DateParsing.dateTime(day: day, time: "09:15")
        let end = try DateParsing.dateTime(day: day, time: "10:45")
        let session = TimerSession(taskID: 33, userID: 1, startedAt: start, comments: "CLI test")

        let entry = try session.entry(endedAt: end)
        let data = try JSONEncoder().encode(entry)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"entry_date\":\"2026-07-05\""))
        XCTAssertTrue(json.contains("\"started_at_time\":\"09:15\""))
        XCTAssertTrue(json.contains("\"ended_at_time\":\"10:45\""))
        XCTAssertTrue(json.contains("\"id\":33"))
    }

    func testTimerSessionRoundsVeryShortEntriesToOneMinute() throws {
        let day = try DateParsing.parseDay("2026-07-05")
        let start = try DateParsing.dateTime(day: day, time: "09:15")
        let end = start.addingTimeInterval(5)
        let session = TimerSession(taskID: 33, userID: 1, startedAt: start)

        let entry = try session.entry(endedAt: end)
        let data = try JSONEncoder().encode(entry)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"started_at_time\":\"09:15\""))
        XCTAssertTrue(json.contains("\"ended_at_time\":\"09:16\""))
    }

    func testCompactsProjectRows() {
        let response: JSONValue = .object([
            "entries": .array([
                .object([
                    "id": .number(22),
                    "name": .string("Example Project"),
                    "company_id": .number(11),
                    "ignored": .string("x")
                ])
            ])
        ])

        XCTAssertEqual(JSONCompaction.compactProjects(response), [
            [
                "id": "22",
                "name": "Example Project",
                "company_id": "11"
            ]
        ])
    }

    func testProjectConfigSearchOnlyUsesCurrentDirectoryOutsideGitRepo() throws {
        let root = try makeTemporaryDirectory()
        let child = root.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try #"{"company_id":11}"#.write(
            to: root.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let store = ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: child)

        XCTAssertNil(store.findProjectConfigFile())
        XCTAssertEqual(store.projectSearchDirectories().map(\.path), [child.path])
    }

    func testProjectConfigSearchWalksToNearestGitRootOnly() throws {
        let root = try makeTemporaryDirectory()
        let repo = root.appendingPathComponent("repo", isDirectory: true)
        let nested = repo.appendingPathComponent("Sources/App", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repo.appendingPathComponent(".git", isDirectory: true), withIntermediateDirectories: true)
        try #"{"project_id":22}"#.write(
            to: repo.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let store = ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: nested)

        XCTAssertEqual(store.findProjectConfigFile()?.path, repo.appendingPathComponent(".pkram").path)
        XCTAssertEqual(
            store.projectSearchDirectories().map(\.path),
            [
                nested.path,
                repo.appendingPathComponent("Sources").path,
                repo.path
            ]
        )
    }

    func testProjectConfigMergesMetadata() throws {
        let root = try makeTemporaryDirectory()
        try #"{"company_id":11,"project_id":22,"task_id":33,"user_id":1,"subdomain":"example"}"#.write(
            to: root.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let config = try ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: root).load()

        XCTAssertEqual(config.subdomain, "example")
        XCTAssertEqual(config.defaultUserID, 1)
        XCTAssertEqual(config.defaultCompanyID, 11)
        XCTAssertEqual(config.defaultProjectID, 22)
        XCTAssertEqual(config.defaultTaskID, 33)
        XCTAssertEqual(config.projectConfigPath, root.appendingPathComponent(".pkram").path)
    }

    func testUserConfigLoadIgnoresProjectConfig() throws {
        let root = try makeTemporaryDirectory()
        try #"{"company_id":11,"project_id":22,"task_id":33}"#.write(
            to: root.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let store = ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: root)
        let userConfig = try store.loadUserConfig()
        let mergedConfig = try store.load()

        XCTAssertNil(userConfig.defaultCompanyID)
        XCTAssertNil(userConfig.defaultProjectID)
        XCTAssertNil(userConfig.defaultTaskID)
        XCTAssertEqual(mergedConfig.defaultCompanyID, 11)
        XCTAssertEqual(mergedConfig.defaultProjectID, 22)
        XCTAssertEqual(mergedConfig.defaultTaskID, 33)
    }

    func testProjectConfigCarriesNamedTasks() throws {
        let root = try makeTemporaryDirectory()
        try #"{"project_id":22,"task_id":33,"tasks":{"tickets":44,"maintenance":33}}"#.write(
            to: root.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let config = try ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: root).load()

        XCTAssertEqual(config.defaultTaskID, 33)
        XCTAssertEqual(config.namedTasks, ["tickets": 44, "maintenance": 33])
    }

    func testProjectConfigWithoutTasksYieldsNoNames() throws {
        let root = try makeTemporaryDirectory()
        try #"{"project_id":22,"task_id":33}"#.write(
            to: root.appendingPathComponent(".pkram"),
            atomically: true,
            encoding: .utf8
        )

        let config = try ConfigStore(paths: AppPaths(homeDirectory: root), currentDirectory: root).load()

        XCTAssertEqual(config.defaultTaskID, 33)
        XCTAssertTrue(config.namedTasks.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pkram-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryURLs.append(url)
        return url
    }
}
