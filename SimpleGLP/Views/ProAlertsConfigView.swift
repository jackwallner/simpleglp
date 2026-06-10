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
                            if newValue {
                                await requestPermissionsIfNeeded()
                            }
                            await applyAlertSettings()
                        }
                    }
            } footer: {
                Text("When enabled, the app analyzes your shot history and notifies you about upcoming dose days.")
            }

            Section("Status") {
                ProAlertStatusRow(icon: notificationIcon, title: "Notifications", value: notificationLabel)
                Button {
                    Task { await sendTestAlert() }
                } label: {
                    Label("Send Test Alert", systemImage: "paperplane.fill")
                }
                .disabled(!prefs.alertsEnabled)
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
        .task { await refreshPermissionStatuses() }
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
        case .authorized, .provisional, .ephemeral: return "Ready"
        case .denied: return "Off in Settings"
        case .notDetermined: return "Needs permission"
        @unknown default: return "Unknown"
        }
    }

    private func refreshPermissionStatuses() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    private func applyAlertSettings() async {
        await ProactiveAlertsEngine.schedulePatternAlertsIfEnabled(in: modelContext)
    }

    private func requestPermissionsIfNeeded() async {
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
        await refreshPermissionStatuses()
    }

    private func sendTestAlert() async {
        let center = UNUserNotificationCenter.current()
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else {
            testAlertMessage = "Notifications are not enabled. Open iPhone Settings to allow them."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Test Simple GLP Alert"
        content.body = "Notifications are working. Real alerts fire when patterns are detected."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "glp-test-\(UUID().uuidString)", content: content, trigger: nil)
        do {
            try await center.add(request)
            testAlertMessage = "Test alert sent."
        } catch {
            testAlertMessage = "Could not send test alert."
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
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
