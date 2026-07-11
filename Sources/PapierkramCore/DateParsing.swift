import Foundation

public enum DateParsing {
    public static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    public static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    public static func parseDay(_ value: String, now: Date = Date()) throws -> Date {
        let calendar = Calendar.current
        switch value.lowercased() {
        case "today", "heute":
            return calendar.startOfDay(for: now)
        case "yesterday", "gestern":
            guard let date = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) else {
                throw PapierkramError.invalidDate(value)
            }
            return date
        case "tomorrow", "morgen":
            guard let date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
                throw PapierkramError.invalidDate(value)
            }
            return date
        default:
            guard let date = dayFormatter.date(from: value) else {
                throw PapierkramError.invalidDate(value)
            }
            return date
        }
    }

    public static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    public static func validateTime(_ value: String) throws -> String {
        guard timeFormatter.date(from: value) != nil else {
            throw PapierkramError.invalidTime(value)
        }
        return value
    }

    public static func dateTime(day: Date, time: String) throws -> Date {
        let time = try validateTime(time)
        var calendar = Calendar.current
        calendar.timeZone = .current

        let timeDate = timeFormatter.date(from: time)!
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        guard let result = calendar.date(from: components) else {
            throw PapierkramError.invalidTime(time)
        }
        return result
    }

    public static func rfc3339Range(from startDay: Date, to endDay: Date) throws -> (String, String) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDay)
        guard let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDay)),
              let inclusiveEnd = calendar.date(byAdding: .second, value: -1, to: exclusiveEnd)
        else {
            throw PapierkramError.invalidDate(dayString(endDay))
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return (formatter.string(from: start), formatter.string(from: inclusiveEnd))
    }
}
