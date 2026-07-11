import Foundation

public enum JSONCompaction {
    public static func entries(in value: JSONValue) -> [JSONValue] {
        value["entries"]?.arrayValue ?? value["data"]?.arrayValue ?? value.arrayValue ?? []
    }

    public static func compactProjects(_ value: JSONValue) -> [[String: String]] {
        entries(in: value).map { entry in
            compact(entry, keys: ["id", "name", "record_state", "start_date", "end_date", "company_id"])
        }
    }

    public static func compactTasks(_ value: JSONValue) -> [[String: String]] {
        entries(in: value).map { entry in
            compact(entry, keys: ["id", "name", "complete", "deadline", "project_id"])
        }
    }

    public static func compactTimeEntries(_ value: JSONValue) -> [[String: String]] {
        entries(in: value).map { entry in
            compact(entry, keys: ["id", "started_at", "ended_at", "duration", "comments", "task_id", "project_id"])
        }
    }

    public static func compact(_ value: JSONValue, keys: [String]) -> [String: String] {
        var result: [String: String] = [:]
        for key in keys {
            if let string = value[key]?.stringValue {
                result[key] = string
            }
        }
        return result
    }
}
