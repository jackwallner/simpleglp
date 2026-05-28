import Foundation
import SwiftData

enum ImportService {
    enum ImportError: Error {
        case invalidEncoding
    }

    /// Imports shots from a Simple GLP CSV export. Restores dose, injection site, and notes,
    /// and recomputes each shot's schedule status against the current plan so adherence stats
    /// stay correct after a restore. Imported shots are added, never replacing existing entries.
    @MainActor
    static func importEvents(from url: URL, into context: ModelContext) throws -> Int {
        let data = try Data(contentsOf: url)
        guard let csv = String(data: data, encoding: .utf8) else { throw ImportError.invalidEncoding }

        var records = parseCSV(csv)
        guard !records.isEmpty else { return 0 }
        // Drop the header row when present.
        if let first = records.first?.first, first.lowercased() == "timestamp" {
            records.removeFirst()
        }

        let formatter = ISO8601DateFormatter()
        let plan = PlanStore.currentPlan(in: context)
        // Seed with existing shots so same-week duplicates are flagged as extra.
        var known = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        var count = 0

        for cols in records {
            guard cols.count >= 3, !cols[0].isEmpty, let timestamp = formatter.date(from: cols[0]) else { continue }
            let medication = cols[1].isEmpty ? "GLP-1" : cols[1]
            let dose = Double(cols[2]) ?? 0

            let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: known)
            let event = ShotEvent(
                timestamp: timestamp,
                medicationName: medication,
                doseMg: dose,
                scheduledDate: match.scheduledDate,
                scheduleStatus: match.status,
                minutesFromSchedule: match.minutesFromSchedule
            )
            if cols.count >= 5, !cols[4].isEmpty {
                event.injectionSite = InjectionSite(rawValue: cols[4])
            }
            if cols.count >= 6, !cols[5].isEmpty {
                event.userNotes = cols[5]
            }
            event.finalizeCapture()
            context.insert(event)
            known.append(event)
            count += 1
        }

        try context.save()
        return count
    }

    /// Minimal RFC 4180 parser: handles quoted fields containing commas, newlines, and
    /// escaped (doubled) quotes. Returns one array of fields per record.
    static func parseCSV(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        var iterator = text.makeIterator()
        var pending = iterator.next()

        func commitField() {
            record.append(field)
            field = ""
        }
        func commitRecord() {
            commitField()
            // Skip blank trailing records (e.g. final newline).
            if !(record.count == 1 && record[0].isEmpty) {
                records.append(record)
            }
            record = []
        }

        while let char = pending {
            let next = iterator.next()
            if inQuotes {
                if char == "\"" {
                    if next == "\"" {
                        field.append("\"")
                        pending = iterator.next()
                        continue
                    }
                    inQuotes = false
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    commitField()
                case "\n":
                    commitRecord()
                case "\r":
                    if next == "\n" {
                        commitRecord()
                        pending = iterator.next()
                        continue
                    }
                    commitRecord()
                default:
                    field.append(char)
                }
            }
            pending = next
        }
        // Flush the final field/record if the file didn't end with a newline.
        if !field.isEmpty || !record.isEmpty {
            commitRecord()
        }
        return records
    }
}
