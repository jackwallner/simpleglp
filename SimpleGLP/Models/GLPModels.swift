import Foundation
import SwiftData

enum CaptureStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case complete
    case partial
    case failed
}

enum CaptureSourceStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case captured
    case unavailable
    case failed
}

enum GLPMedication: String, Codable, CaseIterable, Identifiable, Sendable {
    case ozempic = "Ozempic"
    case wegovy = "Wegovy"
    case mounjaro = "Mounjaro"
    case zepbound = "Zepbound"
    case compoundedSemaglutide = "Compounded semaglutide"
    case compoundedTirzepatide = "Compounded tirzepatide"
    case other = "Other"

    var id: String { rawValue }

    var standardDoseStepsMg: [Double] {
        switch self {
        case .ozempic: [0.25, 0.5, 1.0, 2.0]
        case .wegovy, .compoundedSemaglutide: [0.25, 0.5, 1.0, 1.7, 2.4]
        case .mounjaro, .zepbound, .compoundedTirzepatide: [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]
        case .other: []
        }
    }
}

enum InjectionSite: String, Codable, CaseIterable, Identifiable, Sendable {
    case abdomen = "Abdomen"
    case leftThigh = "Left thigh"
    case rightThigh = "Right thigh"
    case leftArm = "Left arm"
    case rightArm = "Right arm"
    case other = "Other"

    var id: String { rawValue }
}

enum ScheduleMatchStatus: String, Codable, CaseIterable, Sendable {
    case onSchedule
    case early
    case late
    case extra
    case unknown

    var label: String {
        switch self {
        case .onSchedule: "On schedule"
        case .early: "A little early"
        case .late: "A little late"
        case .extra: "Manual"
        case .unknown: "Not mapped"
        }
    }
}

struct HealthSnapshot: Sendable {
    var bodyMassKg: Double? = nil
    var bloodGlucoseMgPerDL: Double? = nil
    var stepsToday: Int? = nil
    var activeEnergyKcalToday: Double? = nil
    var exerciseMinutesToday: Double? = nil
    var sleepHoursLastNight: Double? = nil
    var restingHeartRateBpm: Double? = nil
    var recentHeartRateAverageBpm: Double? = nil
    var workoutsLast24h: Int? = nil
    var waterMlToday: Double? = nil
    var caffeineMgToday: Double? = nil
    var dietaryEnergyKcalToday: Double? = nil
    var proteinGramsToday: Double? = nil

    var hasMeaningfulValue: Bool {
        bodyMassKg != nil
        || bloodGlucoseMgPerDL != nil
        || stepsToday != nil
        || activeEnergyKcalToday != nil
        || exerciseMinutesToday != nil
        || sleepHoursLastNight != nil
        || restingHeartRateBpm != nil
        || recentHeartRateAverageBpm != nil
        || workoutsLast24h != nil
        || waterMlToday != nil
        || caffeineMgToday != nil
        || dietaryEnergyKcalToday != nil
        || proteinGramsToday != nil
    }
}

struct HealthCaptureResult: Sendable {
    var status: CaptureSourceStatus
    var message: String?
    var snapshot: HealthSnapshot?
}

@Model
final class MedicationPlan {
    @Attribute(.unique) var id: UUID
    var medicationRaw: String
    var customMedicationName: String?
    var doseMg: Double
    var scheduleStartDate: Date
    var preferredWeekday: Int
    var preferredHour: Int
    var preferredMinute: Int
    var reminderEnabled: Bool
    var reminderLeadMinutes: Int
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \DoseStep.plan) var doseSteps: [DoseStep]

    init(
        medication: GLPMedication = .ozempic,
        customMedicationName: String? = nil,
        doseMg: Double = 0.25,
        scheduleStartDate: Date = .now,
        preferredWeekday: Int = Calendar.current.component(.weekday, from: .now),
        preferredHour: Int = 9,
        preferredMinute: Int = 0,
        reminderEnabled: Bool = true,
        reminderLeadMinutes: Int = 0,
        doseSteps: [DoseStep] = []
    ) {
        self.id = UUID()
        self.medicationRaw = medication.rawValue
        self.customMedicationName = customMedicationName
        self.doseMg = doseMg
        self.scheduleStartDate = scheduleStartDate
        self.preferredWeekday = preferredWeekday
        self.preferredHour = preferredHour
        self.preferredMinute = preferredMinute
        self.reminderEnabled = reminderEnabled
        self.reminderLeadMinutes = reminderLeadMinutes
        self.createdAt = .now
        self.updatedAt = .now
        self.doseSteps = doseSteps
    }

    var medication: GLPMedication {
        get { GLPMedication(rawValue: medicationRaw) ?? .other }
        set { medicationRaw = newValue.rawValue }
    }

    var displayMedicationName: String {
        if medication == .other, let customMedicationName, !customMedicationName.isEmpty {
            return customMedicationName
        }
        return medication.rawValue
    }

    var preferredTimeComponents: DateComponents {
        DateComponents(hour: preferredHour, minute: preferredMinute)
    }
}

@Model
final class DoseStep {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var doseMg: Double
    var note: String?
    var plan: MedicationPlan?

    init(startDate: Date, doseMg: Double, note: String? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.doseMg = doseMg
        self.note = note
    }
}

@Model
final class ShotEvent {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var createdAt: Date
    var captureCompletedAt: Date?
    var captureStatusRaw: String
    var healthStatusRaw: String
    var healthStatusMessage: String?
    var medicationName: String
    var doseMg: Double
    var scheduledDate: Date?
    var scheduleStatusRaw: String
    var minutesFromSchedule: Int?
    var injectionSiteRaw: String?
    var userNotes: String?
    var nausea: Int?
    var appetite: Int?
    var foodNoise: Int?
    var wellbeing: Int?
    var bodyMassKg: Double?
    var bloodGlucoseMgPerDL: Double?
    var stepsToday: Int?
    var activeEnergyKcalToday: Double?
    var exerciseMinutesToday: Double?
    var sleepHoursLastNight: Double?
    var restingHeartRateBpm: Double?
    var recentHeartRateAverageBpm: Double?
    var workoutsLast24h: Int?
    var waterMlToday: Double?
    var caffeineMgToday: Double?
    var dietaryEnergyKcalToday: Double?
    var proteinGramsToday: Double?

    init(timestamp: Date = .now, medicationName: String = "GLP-1", doseMg: Double = 0, scheduledDate: Date? = nil, scheduleStatus: ScheduleMatchStatus = .unknown, minutesFromSchedule: Int? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.createdAt = .now
        self.captureCompletedAt = nil
        self.captureStatusRaw = CaptureStatus.pending.rawValue
        self.healthStatusRaw = CaptureSourceStatus.pending.rawValue
        self.healthStatusMessage = nil
        self.medicationName = medicationName
        self.doseMg = doseMg
        self.scheduledDate = scheduledDate
        self.scheduleStatusRaw = scheduleStatus.rawValue
        self.minutesFromSchedule = minutesFromSchedule
    }

    var captureStatus: CaptureStatus {
        get { CaptureStatus(rawValue: captureStatusRaw) ?? .pending }
        set { captureStatusRaw = newValue.rawValue }
    }

    var healthStatus: CaptureSourceStatus {
        get { CaptureSourceStatus(rawValue: healthStatusRaw) ?? .pending }
        set { healthStatusRaw = newValue.rawValue }
    }

    var scheduleStatus: ScheduleMatchStatus {
        get { ScheduleMatchStatus(rawValue: scheduleStatusRaw) ?? .unknown }
        set { scheduleStatusRaw = newValue.rawValue }
    }

    var injectionSite: InjectionSite? {
        get { injectionSiteRaw.flatMap { InjectionSite(rawValue: $0) } }
        set { injectionSiteRaw = newValue?.rawValue }
    }

    var weekdayIndex: Int { Calendar.current.component(.weekday, from: timestamp) }
    var hourOfDay: Int { Calendar.current.component(.hour, from: timestamp) }

    var weekdayName: String {
        let index = max(0, min(Calendar.current.weekdaySymbols.count - 1, weekdayIndex - 1))
        return Calendar.current.weekdaySymbols[index]
    }

    func apply(_ result: HealthCaptureResult) {
        healthStatus = result.status
        healthStatusMessage = result.message
        guard let snapshot = result.snapshot else { return }
        bodyMassKg = snapshot.bodyMassKg
        bloodGlucoseMgPerDL = snapshot.bloodGlucoseMgPerDL
        stepsToday = snapshot.stepsToday
        activeEnergyKcalToday = snapshot.activeEnergyKcalToday
        exerciseMinutesToday = snapshot.exerciseMinutesToday
        sleepHoursLastNight = snapshot.sleepHoursLastNight
        restingHeartRateBpm = snapshot.restingHeartRateBpm
        recentHeartRateAverageBpm = snapshot.recentHeartRateAverageBpm
        workoutsLast24h = snapshot.workoutsLast24h
        waterMlToday = snapshot.waterMlToday
        caffeineMgToday = snapshot.caffeineMgToday
        dietaryEnergyKcalToday = snapshot.dietaryEnergyKcalToday
        proteinGramsToday = snapshot.proteinGramsToday
    }

    func finalizeCapture() {
        captureCompletedAt = .now
        switch healthStatus {
        case .captured:
            captureStatus = .complete
        case .unavailable:
            captureStatus = .partial
        case .failed:
            captureStatus = .failed
        case .pending:
            captureStatus = .partial
        }
    }
}
