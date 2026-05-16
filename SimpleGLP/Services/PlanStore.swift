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
}
