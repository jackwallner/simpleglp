import Foundation
import HealthKit

actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var hasRequestedAuthorization = false

    private static func buildReadTypes() -> Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
        ]

        let optionalIDs: [HKQuantityTypeIdentifier] = [
            .dietaryWater,
            .dietaryCaffeine,
            .dietaryEnergyConsumed,
            .dietaryProtein,
        ]
        for id in optionalIDs {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        return types
    }

    private let readTypes: Set<HKObjectType>

    private init() {
        readTypes = Self.buildReadTypes()
    }

    func prepareAuthorizationDuringOnboarding() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
        hasRequestedAuthorization = true
    }

    func captureSnapshot(at date: Date) async -> HealthCaptureResult {
        if AppEnvironment.isUITesting {
            return HealthCaptureResult(
                status: .captured,
                message: nil,
                snapshot: HealthSnapshot(
                    bodyMassKg: 92.5,
                    bloodGlucoseMgPerDL: 96,
                    stepsToday: 4200,
                    activeEnergyKcalToday: 480,
                    exerciseMinutesToday: 24,
                    sleepHoursLastNight: 7.1,
                    restingHeartRateBpm: 62,
                    recentHeartRateAverageBpm: 76,
                    workoutsLast24h: 1,
                    waterMlToday: 900,
                    caffeineMgToday: 120,
                    dietaryEnergyKcalToday: 1300,
                    proteinGramsToday: 72
                )
            )
        }

        guard GLPOnboardingStore.healthContextEnabled else {
            return HealthCaptureResult(
                status: .unavailable,
                message: "Health context is turned off. You can enable it in Settings.",
                snapshot: nil
            )
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthCaptureResult(status: .unavailable, message: "Health data is not available on this device.", snapshot: nil)
        }

        await synchronizeReadAuthorizationForCapture()
        let snapshot = await loadSnapshotWithRetry(at: date)
        let status: CaptureSourceStatus = snapshot.hasMeaningfulValue ? .captured : .unavailable
        return HealthCaptureResult(status: status, message: status == .captured ? nil : "No Health context was available for this shot.", snapshot: snapshot)
    }

    private func synchronizeReadAuthorizationForCapture() async {
        guard !hasRequestedAuthorization else { return }
        let status: HKAuthorizationRequestStatus = await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                continuation.resume(returning: status)
            }
        }
        switch status {
        case .shouldRequest:
            try? await store.requestAuthorization(toShare: [], read: readTypes)
            hasRequestedAuthorization = true
        case .unnecessary, .unknown:
            hasRequestedAuthorization = true
        @unknown default:
            hasRequestedAuthorization = true
        }
    }

    private func loadSnapshotWithRetry(at date: Date) async -> HealthSnapshot {
        let first = await loadSnapshotOnce(at: date)
        if first.hasMeaningfulValue { return first }
        try? await Task.sleep(for: .milliseconds(1200))
        return await loadSnapshotOnce(at: date)
    }

    private func loadSnapshotOnce(at date: Date) async -> HealthSnapshot {
        let dayStart = Calendar.current.startOfDay(for: date)

        async let bodyMass = optionalLatestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo), lookbackDays: 30, relativeTo: date)
        async let glucose = optionalLatestQuantity(identifier: .bloodGlucose, unit: HKUnit.gramUnit(with: .milli).unitDivided(by: .liter()), lookbackDays: 7, relativeTo: date)
        async let steps = optionalCumulativeSum(identifier: .stepCount, unit: .count(), start: dayStart, end: date)
        async let activeEnergy = optionalCumulativeSum(identifier: .activeEnergyBurned, unit: .kilocalorie(), start: dayStart, end: date)
        async let exercise = optionalCumulativeSum(identifier: .appleExerciseTime, unit: .minute(), start: dayStart, end: date)
        async let sleep = optionalSleepHoursBefore(date: date)
        async let restingHeartRate = optionalLatestQuantity(identifier: .restingHeartRate, unit: .count().unitDivided(by: .minute()), lookbackDays: 7, relativeTo: date)
        async let recentHeartRate = optionalAverageQuantity(identifier: .heartRate, unit: .count().unitDivided(by: .minute()), start: date.addingTimeInterval(-6 * 3600), end: date)
        async let workouts = optionalWorkoutCount(start: date.addingTimeInterval(-24 * 3600), end: date)
        async let water = optionalCumulativeSum(identifier: .dietaryWater, unit: .literUnit(with: .milli), start: dayStart, end: date)
        async let caffeine = optionalCumulativeSum(identifier: .dietaryCaffeine, unit: .gramUnit(with: .milli), start: dayStart, end: date)
        async let energyConsumed = optionalCumulativeSum(identifier: .dietaryEnergyConsumed, unit: .kilocalorie(), start: dayStart, end: date)
        async let protein = optionalCumulativeSum(identifier: .dietaryProtein, unit: .gram(), start: dayStart, end: date)

        return await HealthSnapshot(
            bodyMassKg: bodyMass,
            bloodGlucoseMgPerDL: glucose,
            stepsToday: steps.map { Int($0.rounded()) },
            activeEnergyKcalToday: activeEnergy,
            exerciseMinutesToday: exercise,
            sleepHoursLastNight: sleep,
            restingHeartRateBpm: restingHeartRate,
            recentHeartRateAverageBpm: recentHeartRate,
            workoutsLast24h: workouts,
            waterMlToday: water,
            caffeineMgToday: caffeine,
            dietaryEnergyKcalToday: energyConsumed,
            proteinGramsToday: protein
        )
    }

    private func optionalCumulativeSum(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func optionalAverageQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, stats, _ in
                continuation.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func optionalLatestQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, lookbackDays: Int, relativeTo date: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: date) ?? date.addingTimeInterval(Double(-lookbackDays) * 86400)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: date, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func optionalSleepHoursBefore(date: Date) async -> Double? {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: date) ?? date.addingTimeInterval(-18 * 3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: date, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let total = samples?
                    .compactMap { $0 as? HKCategorySample }
                    .filter { sample in
                        if #available(iOS 16.0, *) {
                            return sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                                || sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
                                || sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                                || sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
                        } else {
                            return sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue
                        }
                    }
                    .reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: total.map { $0 / 3600 })
            }
            store.execute(query)
        }
    }

    private func optionalWorkoutCount(start: Date, end: Date) async -> Int? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples?.count)
            }
            store.execute(query)
        }
    }
}
