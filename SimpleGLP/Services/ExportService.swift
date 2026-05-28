import Foundation
import SwiftData

enum ExportService {
    static let header = "timestamp,medication,dose_mg,schedule_status,injection_site,notes"

    static func exportEvents(from context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let events = try context.fetch(descriptor)
        let formatter = ISO8601DateFormatter()
        var lines: [String] = [header]
        for event in events {
            let row = [
                formatter.string(from: event.timestamp),
                event.medicationName,
                String(event.doseMg),
                event.scheduleStatus.rawValue,
                event.injectionSite?.rawValue ?? "",
                event.userNotes ?? ""
            ]
            lines.append(row.map(csvEscaped).joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SimpleGLP_Export_\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Wraps a field in quotes (and doubles any embedded quotes) when it contains a
    /// comma, quote, or newline, per RFC 4180. Keeps simple values unquoted.
    static func csvEscaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
