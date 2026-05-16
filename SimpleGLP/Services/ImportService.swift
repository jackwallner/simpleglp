import Foundation
import SwiftData

enum ImportService {
    static func importEvents(from url: URL, into context: ModelContext) throws -> Int {
        let data = try Data(contentsOf: url)
        guard let csv = String(data: data, encoding: .utf8) else { throw ImportError.invalidEncoding }
        var lines = csv.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return 0 }
        lines.removeFirst()
        let formatter = ISO8601DateFormatter()
        var count = 0
        for line in lines where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count >= 3, let timestamp = formatter.date(from: cols[0]) else { continue }
            let dose = Double(cols[2]) ?? 0
            let event = ShotEvent(timestamp: timestamp, medicationName: cols[1], doseMg: dose)
            event.finalizeCapture()
            context.insert(event)
            count += 1
        }
        try context.save()
        return count
    }

    enum ImportError: Error {
        case invalidEncoding
    }
}
