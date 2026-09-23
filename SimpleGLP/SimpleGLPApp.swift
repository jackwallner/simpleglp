import SwiftData
import SwiftUI
import UserNotifications

@main
struct SimpleGLPApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var shotCoordinator = ShotCaptureCoordinator()
    @StateObject private var storeService = StoreService.shared

    init() {
        StoreService.shared.start()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-GLPScreenshotPro") {
            StoreService.shared.setLocalOverride(isPro: true)
        }
        #endif
        ReviewPromptTracker.recordAppLaunch()
        ConversionDiagnostics.recordAppOpen()
        #if DEBUG
        if RevenueCatProbe.isEnabled {
            // Same entry point the real paywall screens call, so what this
            // proves is the actual path and not a parallel one.
            StoreService.shared.trackPaywallImpression(id: RevenueCatProbe.impressionID)
            if RevenueCatProbe.wantsPurchase {
                Task {
                    await StoreService.shared.fetchProducts()
                    // Logged rather than asserted: when the Test Store sheet
                    // never appears, this separates "nothing came back" from
                    // "purchase threw".
                    NSLog("RCPROBE packages=%d", StoreService.shared.products.count)
                    guard let package = StoreService.shared.products.first else { return }
                    do {
                        let state = try await StoreService.shared.purchase(package)
                        NSLog("RCPROBE purchase outcome=%@", String(describing: state))
                    } catch {
                        NSLog("RCPROBE purchase error=%@", String(describing: error))
                    }
                }
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-GLPScreenshotAlerts") {
                NavigationStack {
                    ProAlertsConfigView()
                }
                .environmentObject(shotCoordinator)
                .environmentObject(storeService)
            } else if let mode = PaywallScreenshotMode.current {
                PaywallScreenshotHarness(mode: mode)
                    .environmentObject(shotCoordinator)
                    .environmentObject(storeService)
            } else {
                SimpleGLPRootContent()
                    .environmentObject(shotCoordinator)
                    .environmentObject(storeService)
            }
            #else
            SimpleGLPRootContent()
                .environmentObject(shotCoordinator)
                .environmentObject(storeService)
            #endif
        }
        .modelContainer(GLPModelStore.sharedModelContainer)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let backgroundShotCoordinator = ShotCaptureCoordinator()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderService.registerCategories()
        DiagnosticsService.shared.start()
        let fallbackCoordinator = backgroundShotCoordinator
        PhoneWatchSession.shared.start()
        PhoneWatchSession.shared.onWatchRequestedCapture = { date, eventID in
            let context = ModelContext(GLPModelStore.sharedModelContainer)
            fallbackCoordinator.captureShot(in: context, tapDate: date, eventID: eventID)
        }
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let tappedAt = Date()
        // UNNotificationContent is immutable, so handing it to the main actor is safe.
        nonisolated(unsafe) let sendableContent = content
        let done = UncheckedCompletion(completionHandler)
        Task { @MainActor in
            switch action {
            case ReminderService.tookItAction:
                let context = GLPModelStore.sharedModelContainer.mainContext
                // A stale reminder for a dose already logged elsewhere must not double it.
                if DoseRoutineService.alreadyLogged(at: tappedAt, in: context) == nil {
                    self.backgroundShotCoordinator.captureShot(in: context, tapDate: tappedAt, deferHealthContext: true)
                }
                await DoseRoutineService.settleBackgroundLog(in: context)
            case ReminderService.snoozeAction:
                await ReminderService.snooze(sendableContent)
            default:
                break
            }
            done.call()
        }
    }
}

/// Carries a UIKit completion handler onto the main actor; it is only ever called once.
private struct UncheckedCompletion: @unchecked Sendable {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    func call() { handler() }
}

private struct SimpleGLPRootContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var shotCoordinator: ShotCaptureCoordinator
    @EnvironmentObject private var store: StoreService
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding || AppEnvironment.bypassOnboarding {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            PlanStore.migrateLegacySchedules(in: modelContext)
            PhoneWatchSession.shared.start()
            PhoneWatchSession.shared.onWatchRequestedCapture = { date, eventID in
                shotCoordinator.captureShot(in: modelContext, tapDate: date, eventID: eventID)
            }
            shotCoordinator.ingestPendingWidgetShot(in: modelContext)
            shotCoordinator.enrichPendingCapturesIfNeeded(in: modelContext)
            DoseRoutineService.refresh(in: modelContext, mayPrompt: false)
            #if DEBUG
            SimpleGLPScreenshotData.seedIfRequested(in: modelContext)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                shotCoordinator.ingestPendingWidgetShot(in: modelContext)
                shotCoordinator.enrichPendingCapturesIfNeeded(in: modelContext)
                DoseRoutineService.refresh(in: modelContext, mayPrompt: false)
            }
        }
        .onChange(of: store.hasResolvedEntitlements) { _, _ in
            Task { await DoseRoutineService.rescheduleReminders(in: modelContext, mayPrompt: false) }
        }
        .onChange(of: store.isProUnlocked) { _, _ in
            DoseRoutineService.startLiveActivityIfWaiting(in: modelContext)
            Task { await DoseRoutineService.rescheduleReminders(in: modelContext, mayPrompt: false) }
        }
    }
}

#if DEBUG
private enum SimpleGLPScreenshotData {
    static func seedIfRequested(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-GLPScreenshotSeed") else { return }

        let existingEvents = (try? context.fetch(FetchDescriptor<ShotEvent>())) ?? []
        existingEvents.forEach(context.delete)
        let existingPlans = (try? context.fetch(FetchDescriptor<MedicationPlan>())) ?? []
        existingPlans.forEach(context.delete)

        let now = Date()
        if ProcessInfo.processInfo.arguments.contains("-GLPScreenshotPill") {
            seedPill(in: context, now: now)
            return
        }
        let plan = MedicationPlan(
            medication: .mounjaro,
            doseMg: 5.0,
            scheduleStartDate: Calendar.current.date(byAdding: .day, value: -56, to: now) ?? now,
            preferredHour: 8,
            preferredMinute: 30,
            intervalDays: 7,
            reminderEnabled: true
        )
        context.insert(plan)

        let calendar = Calendar.current
        for index in 0..<8 {
            guard let timestamp = calendar.date(byAdding: .day, value: -(index * 7 + 1), to: now) else { continue }
            let event = ShotEvent(
                timestamp: timestamp,
                medicationName: plan.displayMedicationName,
                doseMg: plan.doseMg,
                scheduledDate: timestamp,
                scheduleStatus: .onSchedule,
                minutesFromSchedule: 0
            )
            event.captureStatus = .complete
            event.captureCompletedAt = timestamp.addingTimeInterval(60)
            event.healthStatus = .captured
            event.injectionSite = InjectionSite.allCases[index % InjectionSite.allCases.count]
            event.userNotes = index == 0 ? "Felt steady after the dose" : nil
            event.nausea = index % 3
            event.appetite = 2 + (index % 3)
            event.foodNoise = 1 + (index % 2)
            event.wellbeing = 3 + (index % 3)
            event.bodyMassKg = 88.4 - Double(index) * 0.35
            event.stepsToday = 7_400 + index * 380
            event.activeEnergyKcalToday = 420 + Double(index * 18)
            event.sleepHoursLastNight = 7.1 + Double(index % 3) * 0.3
            context.insert(event)
        }

        try? context.save()
    }

    /// A Wegovy pill user eleven days in, with today's pill logged ten minutes ago so Home
    /// shows the running wait.
    private static func seedPill(in context: ModelContext, now: Date) {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -20, to: now) ?? now
        let plan = MedicationPlan(
            medication: .wegovyPill,
            doseMg: 4,
            scheduleStartDate: start,
            preferredHour: calendar.component(.hour, from: now.addingTimeInterval(-15 * 60)),
            preferredMinute: calendar.component(.minute, from: now.addingTimeInterval(-15 * 60)),
            intervalDays: 1,
            waitMinutes: 30,
            reminderEnabled: true
        )
        plan.supplyCount = 30
        plan.supplyUpdatedAt = calendar.date(byAdding: .day, value: -22, to: now)
        context.insert(plan)
        var logged: [ShotEvent] = []
        let offsets = [0] + Array(1...11) + [13, 14, 15, 17, 18, 19]
        for offset in offsets.reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let timestamp = offset == 0 ? now.addingTimeInterval(-10 * 60) : day.addingTimeInterval(TimeInterval((offset % 4) * 9 * 60) - 20 * 60)
            let match = ScheduleEngine.match(timestamp: timestamp, plan: plan, existingEvents: logged)
            let event = ShotEvent(
                timestamp: timestamp,
                medicationName: plan.displayMedicationName,
                doseMg: match.doseMg,
                scheduledDate: match.scheduledDate,
                scheduleStatus: match.status,
                minutesFromSchedule: match.minutesFromSchedule
            )
            event.captureStatus = .complete
            event.healthStatus = .captured
            context.insert(event)
            logged.append(event)
        }
        try? context.save()
    }
}
#endif
