import Foundation

public struct Table {
    public static func render(rows: [[String: String]], columns: [(key: String, title: String)]) -> String {
        guard !rows.isEmpty else {
            return "No results."
        }

        var widths = columns.map { $0.title.count }
        for row in rows {
            for (index, column) in columns.enumerated() {
                widths[index] = max(widths[index], (row[column.key] ?? "").count)
            }
        }

        var lines: [String] = []
        lines.append(line(values: columns.map(\.title), widths: widths))
        lines.append(line(values: widths.map { String(repeating: "-", count: $0) }, widths: widths))
        for row in rows {
            lines.append(line(values: columns.map { row[$0.key] ?? "" }, widths: widths))
        }
        return lines.joined(separator: "\n")
    }

    private static func line(values: [String], widths: [Int]) -> String {
        zip(values, widths)
            .map { value, width in value.padding(toLength: width, withPad: " ", startingAt: 0) }
            .joined(separator: "  ")
    }
}
