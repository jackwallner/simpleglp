import SwiftData
import SwiftUI
import UserNotifications

struct ProAlertsConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var prefs = ProAlertPreferences.shared
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var testAlertMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle("Enable Proactive Alerts", isOn: $prefs.alertsEnabled)
                    .onChange(of: prefs.alertsEnabled) { _, newValue in
                        Task {
                            if newValue && !isScreenshotMode {
                                await requestPermissionsIfNeeded()
                            }
                            await applyAlertSettings()
                        }
                    }
            } footer: {
                Text(GLPAppGroup.userDefaults.bool(forKey: GLPStorageKey.isPillPlan.rawValue)
                     ? String(localized: "When enabled, you get a second nudge if today’s pill isn’t logged a few hours after its time.")
                     : String(localized: "When enabled, the app analyzes your shot history and notifies you about upcoming dose days."))
            }

            Section("Status") {
                ProAlertStatusRow(
                    icon: isScreenshotMode ? "bell.badge.fill" : notificationIcon,
                    title: String(localized: "Notifications"),
                    value: isScreenshotMode ? String(localized: "Available when enabled") : notificationLabel
                )
                if !isScreenshotMode {
                    Button {
                        Task { await sendTestAlert() }
                    } label: {
                        Label("Send Test Alert", systemImage: "paperplane.fill")
                    }
                    .disabled(!prefs.alertsEnabled)
                }
            }

            Section("Quiet hours") {
                Toggle("Don’t alert at night", isOn: $prefs.quietHoursEnabled)
                if prefs.quietHoursEnabled {
                    Stepper(value: $prefs.quietHoursStart, in: 0...23) {
                        HStack { Text("From"); Spacer(); Text(formatHour(prefs.quietHoursStart)).foregroundStyle(.secondary) }
                    }
                    Stepper(value: $prefs.quietHoursEnd, in: 0...23) {
                        HStack { Text("Until"); Spacer(); Text(formatHour(prefs.quietHoursEnd)).foregroundStyle(.secondary) }
                    }
                }
            }

            Section {
                Toggle("Predict from your patterns", isOn: $prefs.patternAlertsEnabled)
                if prefs.patternAlertsEnabled {
                    Picker("Sensitivity", selection: $prefs.patternAlertSensitivity) {
                        Text("High chance only").tag(0.0)
                        Text("Any chance").tag(1.0)
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Prediction")
            } footer: {
                Text("All analysis runs on your device.")
            }
        }
        .navigationTitle("Proactive Alerts")
        .task {
            if isScreenshotMode {
                prefs.alertsEnabled = true
                prefs.patternAlertsEnabled = true
                prefs.quietHoursEnabled = true
            }
            await refreshPermissionStatuses()
        }
        // Apply changes immediately — without this, new settings wouldn't take effect
        // until the next shot capture reschedules notifications.
        .onChange(of: prefs.patternAlertsEnabled) { _, _ in Task { await applyAlertSettings() } }
        .onChange(of: prefs.patternAlertSensitivity) { _, _ in Task { await applyAlertSettings() } }
        .onChange(of: prefs.quietHoursEnabled) { _, _ in Task { await applyAlertSettings() } }
        .onChange(of: prefs.quietHoursStart) { _, _ in Task { await applyAlertSettings() } }
        .onChange(of: prefs.quietHoursEnd) { _, _ in Task { await applyAlertSettings() } }
        .alert("Test Alert", isPresented: Binding(get: { testAlertMessage != nil }, set: { if !$0 { testAlertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testAlertMessage ?? "")
        }
    }

    private var notificationIcon: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell.fill"
        @unknown default: return "bell.fill"
        }
    }

    private var notificationLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return String(localized: "Ready")
        case .denied: return String(localized: "Off in Settings")
        case .notDetermined: return String(localized: "Needs permission")
        @unknown default: return String(localized: "Unknown")
        }
    }

    private var isScreenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-GLPScreenshotSeed")
        #else
        return false
        #endif
    }

    private func refreshPermissionStatuses() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func applyAlertSettings() async {
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: modelContext)
    }

    private func requestPermissionsIfNeeded() async {
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined {
            _ = await ReminderService.requestAuthorization()
        }
        await refreshPermissionStatuses()
    }

    private func sendTestAlert() async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = await ReminderService.requestAuthorization()
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else {
            testAlertMessage = String(localized: "Notifications are not enabled. Open iPhone Settings to allow them.")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Test Simple GLP Alert")
        content.body = String(localized: "Notifications are working. Real alerts fire when patterns are detected.")
        content.sound = .default
        let request = UNNotificationRequest(identifier: "glp-test-\(UUID().uuidString)", content: content, trigger: nil)
        do {
            try await center.add(request)
            testAlertMessage = String(localized: "Test alert sent.")
        } catch {
            testAlertMessage = String(localized: "Could not send test alert.")
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }
}

private struct ProAlertStatusRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AppTheme.brand).frame(width: 24)
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}
