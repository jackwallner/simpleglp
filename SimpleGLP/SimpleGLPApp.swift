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
        ReviewPromptTracker.recordAppLaunch()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let mode = PaywallScreenshotMode.current {
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
}

private struct SimpleGLPRootContent: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var shotCoordinator: ShotCaptureCoordinator
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                shotCoordinator.ingestPendingWidgetShot(in: modelContext)
                shotCoordinator.enrichPendingCapturesIfNeeded(in: modelContext)
            }
        }
    }
}
