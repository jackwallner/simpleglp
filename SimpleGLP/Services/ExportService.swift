import Foundation
import SwiftData

enum ExportService {
    static let columns = [
        "timestamp", "medication", "dose_mg", "schedule_status", "injection_site", "notes",
        "nausea", "appetite", "food_noise", "wellbeing",
        "body_mass_kg", "blood_glucose_mg_per_dl", "steps_today", "active_energy_kcal_today",
        "exercise_minutes_today", "sleep_hours_last_night", "resting_heart_rate_bpm",
        "recent_heart_rate_average_bpm", "workouts_last_24h", "water_ml_today", "caffeine_mg_today",
        "dietary_energy_kcal_today", "protein_grams_today"
    ]
    static let header = columns.joined(separator: ",")

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
                event.userNotes ?? "",
                optional(event.nausea),
                optional(event.appetite),
                optional(event.foodNoise),
                optional(event.wellbeing),
                optional(event.bodyMassKg),
                optional(event.bloodGlucoseMgPerDL),
                optional(event.stepsToday),
                optional(event.activeEnergyKcalToday),
                optional(event.exerciseMinutesToday),
                optional(event.sleepHoursLastNight),
                optional(event.restingHeartRateBpm),
                optional(event.recentHeartRateAverageBpm),
                optional(event.workoutsLast24h),
                optional(event.waterMlToday),
                optional(event.caffeineMgToday),
                optional(event.dietaryEnergyKcalToday),
                optional(event.proteinGramsToday)
            ]
            lines.append(row.map(csvEscaped).joined(separator: ","))
        }
        let csv = lines.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SimpleGLP_Export_\(Int(Date().timeIntervalSince1970)).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func optional<T>(_ value: T?) -> String {
        value.map { String(describing: $0) } ?? ""
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
