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

/// How a medication is taken. Drives the vocabulary ("shot" vs "pill"), the default
/// cadence, and whether logging starts a wait-before-eating countdown.
enum DoseForm: String, Codable, CaseIterable, Identifiable, Sendable {
    case injection
    case pill

    var id: String { rawValue }

    var symbolName: String { self == .pill ? "pills.fill" : "syringe.fill" }
    var logButtonTitle: String {
        String(localized: self == .pill ? "I took my pill" : "I took my shot")
    }
    var defaultIntervalDays: Int { self == .pill ? 1 : 7 }
    var defaultHour: Int { self == .pill ? 7 : 9 }
}

enum GLPMedication: String, Codable, CaseIterable, Identifiable, Sendable {
    case ozempic = "Ozempic"
    case wegovy = "Wegovy"
    case mounjaro = "Mounjaro"
    case zepbound = "Zepbound"
    case compoundedSemaglutide = "Compounded semaglutide"
    case compoundedTirzepatide = "Compounded tirzepatide"
    case other = "Other"
    case wegovyPill = "Wegovy pill"
    case foundayo = "Foundayo"
    case rybelsus = "Rybelsus"
    case otherPill = "Other pill"

    var id: String { rawValue }

    var form: DoseForm {
        switch self {
        case .wegovyPill, .foundayo, .rybelsus, .otherPill: .pill
        default: .injection
        }
    }

    var isCustom: Bool { self == .other || self == .otherPill }

    /// Stored medication names stay stable. Translate built-in labels when they are shown.
    var localizedName: String { GLPGlance.localizedMedicationName(forStoredValue: rawValue) }

    static func localizedName(forStoredValue value: String) -> String {
        guard let medication = GLPMedication(rawValue: value) else { return value }
        return medication.localizedName
    }

    static func options(for form: DoseForm) -> [GLPMedication] {
        allCases.filter { $0.form == form }
    }

    /// Strengths the product ships in, used only to fill the dose picker. The app records
    /// whatever the user says they take; it never suggests a dose.
    var standardDoseStepsMg: [Double] {
        switch self {
        case .ozempic: [0.25, 0.5, 1.0, 2.0]
        case .wegovy, .compoundedSemaglutide: [0.25, 0.5, 1.0, 1.7, 2.4]
        case .mounjaro, .zepbound, .compoundedTirzepatide: [2.5, 5.0, 7.5, 10.0, 12.5, 15.0]
        case .wegovyPill: [1.5, 4.0, 9.0, 25.0]
        case .foundayo: [0.8, 2.5, 5.5, 9.0, 14.5, 17.2]
        case .rybelsus: [1.5, 3.0, 4.0, 7.0, 9.0, 14.0]
        case .other, .otherPill: []
        }
    }

    /// Minutes the product's patient instructions ask people to wait before food, drink or
    /// other oral meds. Only a starting value for the user's own setting.
    var defaultWaitMinutes: Int {
        switch self {
        case .wegovyPill, .rybelsus: 30
        default: 0
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

    var localizedName: String {
        switch self {
        case .abdomen: String(localized: "Abdomen")
        case .leftThigh: String(localized: "Left thigh")
        case .rightThigh: String(localized: "Right thigh")
        case .leftArm: String(localized: "Left arm")
        case .rightArm: String(localized: "Right arm")
        case .other: String(localized: "Other")
        }
    }

    static func localizedName(forStoredValue value: String) -> String {
        guard let site = InjectionSite(rawValue: value) else { return value }
        return site.localizedName
    }
}

enum ScheduleMatchStatus: String, Codable, CaseIterable, Sendable {
    case onSchedule
    case early
    case late
    case extra
    case unknown

    var label: String {
        switch self {
        case .onSchedule: String(localized: "On schedule")
        case .early: String(localized: "A little early")
        case .late: String(localized: "A little late")
        case .extra: String(localized: "Manual")
        case .unknown: String(localized: "Not mapped")
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
    /// The anchor for the whole schedule: the day of the first dose. Combined with
    /// `preferredHour`/`preferredMinute` and `intervalDays` this fully describes the cadence.
    var scheduleStartDate: Date
    /// Legacy: kept in sync as the weekday of `scheduleStartDate` for back-compat, but the
    /// schedule no longer reads it — the dose day is derived from `scheduleStartDate`.
    var preferredWeekday: Int
    var preferredHour: Int
    var preferredMinute: Int
    /// Days between doses. 7 = weekly (the default). Anything else drives an "every N days"
    /// cadence anchored on `scheduleStartDate`. Defaulted for SwiftData lightweight migration.
    var intervalDays: Int = 7
    /// Minutes to count down after a pill before food and drink. 0 = no countdown.
    var waitMinutes: Int = 0
    /// Doses on hand as of `supplyUpdatedAt`. Remaining supply is derived from the shots
    /// logged since, so undo and delete never drift the count.
    var supplyCount: Int = 0
    var supplyUpdatedAt: Date?
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
        intervalDays: Int = 7,
        waitMinutes: Int = 0,
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
        self.intervalDays = intervalDays
        self.waitMinutes = waitMinutes
        self.reminderEnabled = reminderEnabled
        self.reminderLeadMinutes = reminderLeadMinutes
        self.createdAt = .now
        self.updatedAt = .now
        self.doseSteps = doseSteps
    }

    /// Cadence in days, guarded so a 0 left by an older migration never produces an
    /// infinite/degenerate schedule. Always returns at least 1.
    var cadenceDays: Int { max(1, intervalDays) }

    /// True when this plan repeats weekly.
    var isWeekly: Bool { cadenceDays == 7 }

    /// The first dose as a single date+time anchor (start day at the preferred time).
    /// Setting it decomposes back into the stored fields and keeps the legacy weekday in sync.
    var firstDoseAnchor: Date {
        get {
            let cal = Calendar.current
            let startDay = cal.startOfDay(for: scheduleStartDate)
            return cal.date(bySettingHour: preferredHour, minute: preferredMinute, second: 0, of: startDay) ?? scheduleStartDate
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute, .weekday], from: newValue)
            scheduleStartDate = newValue
            preferredHour = comps.hour ?? preferredHour
            preferredMinute = comps.minute ?? preferredMinute
            preferredWeekday = comps.weekday ?? preferredWeekday
        }
    }

    /// One-time migration from the legacy split model (separate `preferredWeekday`) to the
    /// unified anchor model: bakes the chosen weekday into `scheduleStartDate` so the schedule
    /// is fully described by start date + interval, without shifting anyone's dose day.
    /// Idempotent; returns true only when it actually changed the stored anchor.
    @discardableResult
    func normalizeScheduleAnchor(calendar: Calendar = .current) -> Bool {
        guard isWeekly else { return false }
        let startDay = calendar.startOfDay(for: scheduleStartDate)
        guard calendar.component(.weekday, from: startDay) != preferredWeekday else { return false }
        var candidate = startDay
        for _ in 0..<7 {
            if calendar.component(.weekday, from: candidate) == preferredWeekday { break }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = next
        }
        scheduleStartDate = candidate
        return true
    }

    var medication: GLPMedication {
        get { GLPMedication(rawValue: medicationRaw) ?? .other }
        set { medicationRaw = newValue.rawValue }
    }

    var form: DoseForm { medication.form }

    /// Countdown length after logging, or 0 when this plan has none.
    var effectiveWaitMinutes: Int { form == .pill ? max(0, waitMinutes) : 0 }

    var displayMedicationName: String {
        if medication.isCustom, let customMedicationName, !customMedicationName.isEmpty {
            return customMedicationName
        }
        return medication.localizedName
    }

    var storedMedicationName: String {
        if medication.isCustom, let customMedicationName, !customMedicationName.isEmpty {
            return customMedicationName
        }
        return medication.rawValue
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

    init(id: UUID = UUID(), timestamp: Date = .now, medicationName: String = "GLP-1", doseMg: Double = 0, scheduledDate: Date? = nil, scheduleStatus: ScheduleMatchStatus = .unknown, minutesFromSchedule: Int? = nil) {
        self.id = id
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

    var localizedMedicationName: String {
        GLPGlance.localizedMedicationName(forStoredValue: medicationName)
    }

    var injectionSite: InjectionSite? {
        get { injectionSiteRaw.flatMap { InjectionSite(rawValue: $0) } }
        set { injectionSiteRaw = newValue?.rawValue }
    }

    var scheduleRationale: String? {
        guard let scheduled = scheduledDate, let minutes = minutesFromSchedule else { return nil }
        switch scheduleStatus {
        case .onSchedule, .extra, .unknown: return nil
        case .early, .late: break
        }
        let absMin = abs(minutes)
        let amount: String
        if absMin >= 1440 {
            amount = GLPDurationText.format(seconds: TimeInterval(absMin * 60), units: [.day])
        } else if absMin >= 60 {
            amount = GLPDurationText.format(seconds: TimeInterval(absMin * 60), units: [.hour])
        } else {
            amount = GLPDurationText.format(seconds: TimeInterval(absMin * 60), units: [.minute])
        }
        let slot = scheduled.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return scheduleStatus == .late
            ? String(localized: "\(amount) after \(slot)")
            : String(localized: "\(amount) before \(slot)")
    }

    var weekdayIndex: Int { Calendar.current.component(.weekday, from: timestamp) }

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

enum GLPDurationText {
    static func format(seconds: TimeInterval, units: NSCalendar.Unit, style: DateComponentsFormatter.UnitsStyle = .full) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = units
        formatter.unitsStyle = style
        formatter.maximumUnitCount = 1
        formatter.calendar = Calendar.current
        return formatter.string(from: seconds) ?? ""
    }
}

enum GLPMassFormatter {
    static func milligrams(_ value: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        formatter.numberFormatter.minimumFractionDigits = 0
        formatter.numberFormatter.maximumFractionDigits = 2
        return formatter.string(from: Measurement(value: value, unit: UnitMass.milligrams))
    }
}

enum GLPHealthCopy {
    static func localizedMessage(_ message: String?) -> String? {
        guard let message else { return nil }
        switch message {
        case "Open the app to capture Health context.": return String(localized: "Open the app to capture Health context.")
        case "Health context is turned off. You can enable it in Settings.": return String(localized: "Health context is turned off. You can enable it in Settings.")
        case "Health data is not available on this device.": return String(localized: "Health data is not available on this device.")
        case "No Health context was available for this dose.": return String(localized: "No Health context was available for this dose.")
        default:
            return message
        }
    }
}
