import Foundation
import SwiftData

@MainActor
enum PlanStore {
    static func currentPlan(in context: ModelContext) -> MedicationPlan? {
        var descriptor = FetchDescriptor<MedicationPlan>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    static func ensurePlan(in context: ModelContext) -> MedicationPlan {
        if let plan = currentPlan(in: context) {
            return plan
        }
        let plan = MedicationPlan()
        context.insert(plan)
        try? context.save()
        return plan
    }

    /// Migrate any legacy plans to the unified anchor model. Idempotent and cheap — safe to
    /// run on every launch; only writes when a plan's anchor actually changes.
    static func migrateLegacySchedules(in context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? []
        let changed = plans.reduce(false) { $0 || $1.normalizeScheduleAnchor() }
        if changed { try? context.save() }
    }
}
