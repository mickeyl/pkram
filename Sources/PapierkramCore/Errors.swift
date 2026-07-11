import Foundation

public enum PapierkramError: Error, CustomStringConvertible {
    case apiKeyMissing(subdomain: String)
    case subdomainMissing
    case api(status: Int, reason: String, body: String)
    case invalidDate(String)
    case invalidTime(String)
    case invalidDuration
    case invalidResponse(String)
    case timerAlreadyRunning(TimerSession)
    case noTimerRunning
    case keychain(String)
    case filesystem(String)

    public var description: String {
        switch self {
        case .subdomainMissing:
            return "No Papierkram subdomain configured. Run `pkram config set subdomain <your-subdomain>` or set subdomain in .pkram."
        case let .apiKeyMissing(subdomain):
            return "No Papierkram API token found in Keychain for subdomain '\(subdomain)'. Run `pkram auth set-token`."
        case let .api(status, reason, body):
            if body.isEmpty {
                return "Papierkram API error \(status) \(reason)."
            }
            return "Papierkram API error \(status) \(reason): \(body)"
        case let .invalidDate(value):
            return "Invalid date '\(value)'. Use YYYY-MM-DD, today, yesterday, or tomorrow."
        case let .invalidTime(value):
            return "Invalid time '\(value)'. Use HH:MM."
        case .invalidDuration:
            return "End time must be after start time."
        case let .invalidResponse(message):
            return "Unexpected Papierkram response: \(message)"
        case let .timerAlreadyRunning(session):
            return "A timer is already running since \(session.startedAtDisplay). Stop it first with `pkram timer stop`."
        case .noTimerRunning:
            return "No timer is running. Start one with `pkram timer start --task <id>`."
        case let .keychain(message):
            return "Keychain error: \(message)"
        case let .filesystem(message):
            return "Filesystem error: \(message)"
        }
    }
}
