import Foundation
import SwiftData

enum ExportService {
    static func exportEvents(from context: ModelContext) throws -> URL {
        let descriptor = FetchDescriptor<ShotEvent>(sortBy: [SortDescriptor(\.timestamp, order: .forward)])
        let events = try context.fetch(descriptor)
        var lines: [String] = ["timestamp,medication,dose_mg,schedule_status,injection_site,notes"]
        for event in events {
            let row = [
                ISO8601DateFormatter().string(from: event.timestamp),
                event.medicationName,
                String(event.doseMg),
                event.scheduleStatus.rawValue,
                event.injectionSite?.rawValue ?? "",
                event.userNotes ?? ""
            ]
            lines.append(row.joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SimpleGLP_Export_\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
