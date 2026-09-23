import SwiftData
import SwiftUI

/// Home card for Pro supply tracking: doses left and roughly how many days that covers.
struct SupplyCard: View {
    let plan: MedicationPlan
    let doseDates: [Date]

    var body: some View {
        if let remaining = SupplyMath.remaining(plan: plan, doseDates: doseDates) {
            let low = SupplyMath.isLow(remaining: remaining, plan: plan)
            let days = SupplyMath.daysLeft(remaining: remaining, plan: plan)
            Card {
                HStack(spacing: 14) {
                    Image(systemName: low ? "exclamationmark.circle.fill" : "shippingbox.fill")
                        .font(.title2)
                        .foregroundStyle(low ? AppTheme.warm : AppTheme.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SupplyView.countLabel(remaining, form: plan.form))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(low ? "About \(days) days left. Time to line up a refill." : "About \(days) days left")
                            .font(.caption)
                            .foregroundStyle(low ? AppTheme.warm : AppTheme.muted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

/// Pro: record how many doses are on hand. Logged doses count it down, and a refill
/// reminder fires a week before it runs out.
struct SupplyView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @Query(sort: \MedicationPlan.updatedAt, order: .reverse) private var plans: [MedicationPlan]
    @State private var count = 30
    @State private var saveError: String?
    @State private var didLoad = false

    private var plan: MedicationPlan? { plans.first }
    private var form: DoseForm { plan?.form ?? .injection }

    var body: some View {
        Form {
            if let plan, let remaining = SupplyMath.remaining(plan: plan, doseDates: events.map(\.timestamp)) {
                Section("Right now") {
                    HStack {
                        Text(Self.countLabel(remaining, form: form))
                        Spacer()
                        Text("about \(SupplyMath.daysLeft(remaining: remaining, plan: plan)) days")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Stepper(value: $count, in: 0...400) {
                    HStack {
                        Text(form == .pill ? "Pills on hand" : "Doses on hand")
                        Spacer()
                        Text("\(count)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Button(plan?.supplyUpdatedAt == nil ? "Start tracking" : "I refilled: set to \(count)") { save() }
            } header: {
                Text("Refill")
            } footer: {
                Text("Every \(form.noun) you log counts down from this number. You’ll get a heads-up about \(SupplyMath.reminderLeadDays) days before you run out.")
            }
            if plan?.supplyUpdatedAt != nil {
                Section {
                    Button("Stop tracking supply", role: .destructive) { stopTracking() }
                }
            }
        }
        .navigationTitle("Supply & refills")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .alert(
            "Couldn't save",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Try again.")
        }
    }

    static func countLabel(_ remaining: Int, form: DoseForm) -> String {
        let noun = form == .pill ? (remaining == 1 ? "pill" : "pills") : (remaining == 1 ? "dose" : "doses")
        return "\(remaining) \(noun) left"
    }

    private func load() {
        guard !didLoad, let plan else { return }
        didLoad = true
        if let remaining = SupplyMath.remaining(plan: plan, doseDates: events.map(\.timestamp)), plan.supplyUpdatedAt != nil {
            count = remaining
        } else {
            count = plan.form == .pill ? 30 : 4
        }
    }

    private func save() {
        let plan = PlanStore.ensurePlan(in: modelContext)
        plan.supplyCount = count
        plan.supplyUpdatedAt = .now
        persist()
    }

    private func stopTracking() {
        guard let plan else { return }
        plan.supplyUpdatedAt = nil
        persist()
    }

    private func persist() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveError = "Your supply could not be saved. Please try again."
            return
        }
        Task { await DoseRoutineService.rescheduleReminders(in: modelContext) }
    }
}
