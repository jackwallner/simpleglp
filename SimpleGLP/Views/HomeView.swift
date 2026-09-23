import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var coordinator: ShotCaptureCoordinator
    @EnvironmentObject private var store: StoreService
    @Query(sort: \ShotEvent.timestamp, order: .reverse) private var events: [ShotEvent]
    @Query(sort: \MedicationPlan.updatedAt, order: .reverse) private var plans: [MedicationPlan]
    @AppStorage(GLPStorageKey.promptForDetails.rawValue, store: GLPAppGroup.userDefaults) private var promptForDetails = false
    @State private var showConfirmation = false
    @State private var confirmationTask: Task<Void, Never>?
    @State private var selectedEvent: ShotEvent?
    @State private var showPaywall = false
    /// Non-nil while the "when did you take it?" sheet is up, holding its starting time.
    @State private var logEarlierStart: LogEarlierStart?

    private var recentEvents: [ShotEvent] { Array(events.prefix(5)) }
    private var plan: MedicationPlan? { plans.first }
    private var form: DoseForm { plan?.form ?? .injection }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let message = coordinator.bannerMessage, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }

                if let plan, plan.form == .pill {
                    PillRoutineView(
                        plan: plan,
                        doseDates: events.map(\.timestamp),
                        isLogging: coordinator.isCapturing,
                        isPro: store.isProUnlocked,
                        onLog: logDose,
                        onLogEarlier: { logEarlierStart = LogEarlierStart(date: $0) },
                        onEditDose: editDose(on:),
                        onUpgrade: { showPaywall = true }
                    )
                } else {
                    nextShotSection
                    shotButton
                    Button("Took it earlier?") { logEarlierStart = LogEarlierStart(date: .now) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .disabled(coordinator.isCapturing || showConfirmation)
                }

                if coordinator.showUndoOption, coordinator.lastCapturedEventID != nil {
                    Button("Undo") {
                        coordinator.undoLastCapture(in: modelContext)
                        showConfirmation = false
                        confirmationTask?.cancel()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
                }

                if let plan, store.isProUnlocked, plan.supplyUpdatedAt != nil {
                    NavigationLink {
                        SupplyView()
                    } label: {
                        SupplyCard(plan: plan, doseDates: events.map(\.timestamp))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }

                recentShotsSection

                Spacer(minLength: 32)
            }
            .padding(.top, 12)
        }
        .background(AppTheme.bg.ignoresSafeArea())
        .sheet(item: $selectedEvent) { event in
            EditEventSheet(event: event)
        }
        .sheet(item: $logEarlierStart) { start in
            LogEarlierSheet(
                form: form,
                waitMinutes: plan?.effectiveWaitMinutes ?? 0,
                doseDates: events.map(\.timestamp),
                initialDate: start.date,
                onLog: logDose(at:)
            )
        }
        .sheet(isPresented: $showPaywall) {
            SimplePaywallView(paywallImpressionId: "simpleglp_lockscreen_countdown")
                .environmentObject(store)
        }
        .sensoryFeedback(.success, trigger: coordinator.lastCapturedEventID) { _, new in new != nil }
    }

    private func logDose() {
        logDose(at: nil)
    }

    private func logDose(at date: Date?) {
        let ok = coordinator.captureShot(in: modelContext, tapDate: date)
        guard ok else { return }
        triggerConfirmation()
        if promptForDetails, let id = coordinator.lastCapturedEventID {
            // The @Query array hasn't refreshed yet in this run loop turn, so
            // fetch the just-saved event straight from the context.
            var descriptor = FetchDescriptor<ShotEvent>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 1
            selectedEvent = try? modelContext.fetch(descriptor).first
        }
    }

    /// The latest dose logged on that day, opened for editing.
    private func editDose(on day: Date) {
        selectedEvent = events.first { Calendar.current.isDate($0.timestamp, inSameDayAs: day) }
    }

    private var shotButton: some View {
        Button(action: logDose) {
            ZStack {
                Circle()
                    .fill(showConfirmation ? AppTheme.brandPressed : AppTheme.brand)
                    .frame(width: 220, height: 220)
                    .shadow(color: AppTheme.brand.opacity(0.28), radius: 22, x: 0, y: 12)
                VStack(spacing: 8) {
                    Image(systemName: showConfirmation ? "checkmark.circle.fill" : "syringe.fill")
                        .font(.system(size: 44, weight: .bold))
                    Text(showConfirmation ? "Logged" : "I took my shot")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        // Stay disabled through the whole confirmation window so a second tap
        // during the "Logged" flash can't write a duplicate shot.
        .disabled(coordinator.isCapturing || showConfirmation)
        .padding(.vertical, 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showConfirmation)
    }

    @ViewBuilder
    private var recentShotsSection: some View {
        if !recentEvents.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(form == .pill ? "Recent pills" : "Last few shots")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                ForEach(recentEvents) { event in
                    Button {
                        selectedEvent = event
                    } label: {
                        RecentShotRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var nextShotSection: some View {
        if let plan, let next = ScheduleEngine.nextDue(plan: plan, events: events) {
            let isOverdue = next <= .now
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            if isOverdue {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                            }
                            Text(Self.headline(for: next))
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(isOverdue ? AppTheme.warm : AppTheme.muted)
                        Text(next, style: .date)
                            .font(.headline)
                        Text(next, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Dose")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text(DoseScheduleView.format(ScheduleEngine.dose(on: next, plan: plan)))
                            .font(.headline)
                        if let site = lastSite {
                            Text("Last site: \(site.rawValue.lowercased())")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                }
            }
            .padding(.horizontal)
        } else {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No plan yet")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text("Add your medication and schedule in Settings to see what’s next.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal)
        }
    }

    /// Where the last shot went, when it was recorded, to help with rotation.
    private var lastSite: InjectionSite? {
        guard let site = events.first?.injectionSite, site != .other else { return nil }
        return site
    }

    /// "Due today", "Tomorrow", "In 3 days", "Overdue by 2 days".
    static func headline(for next: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: next)).day ?? 0
        switch days {
        case ..<(-1): return "Overdue by \(-days) days"
        case -1: return "Overdue by 1 day"
        case 0: return "Due today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private func triggerConfirmation() {
        confirmationTask?.cancel()
        showConfirmation = true
        confirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if !Task.isCancelled { showConfirmation = false }
        }
    }
}

struct LogEarlierStart: Identifiable {
    let id = UUID()
    let date: Date
}

struct RecentShotRow: View {
    let event: ShotEvent

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.timestamp, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(event.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(event.scheduleStatus.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.14), in: Capsule())
                if let rationale = event.scheduleRationale {
                    Text(rationale)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.surfaceStroke.opacity(0.5), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch event.scheduleStatus {
        case .onSchedule: AppTheme.brand
        case .early, .late: AppTheme.warm
        case .extra, .unknown: AppTheme.muted
        }
    }
}
