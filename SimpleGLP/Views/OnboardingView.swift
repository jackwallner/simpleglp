import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreService
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @AppStorage(GLPStorageKey.hasSeenTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenTrialOffer = false
    @AppStorage(GLPStorageKey.hasSeenFirstRunOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstRunOffer = false
    @State private var step = 0
    @State private var medication: GLPMedication = .ozempic
    @State private var customMedicationName = ""
    @State private var doseMg = 0.25
    @State private var useCustomDose = false
    @State private var firstDose = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now
    @State private var intervalDays = 7
    @State private var reminderEnabled = true
    @State private var reminderLeadMinutes = 0
    @State private var enableHealth = true
    @State private var isPurchasing = false
    @State private var trialError: String?
    @State private var showPaywallFallback = false
    @State private var saveError: String?

    private static let totalSteps = 6
    private var isTrialStep: Bool { step == Self.totalSteps - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    contentView
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .background(AppTheme.bg.ignoresSafeArea())
            .navigationTitle("Simple GLP")
            .navigationBarTitleDisplayMode(.inline)
        }
        // Prefetch offerings early so the trial step has live price + trial copy the
        // moment it appears (StoreService.start() also fetches; this covers a cold
        // first run where products haven't resolved yet).
        .task {
            if store.currentOffering == nil && store.products.isEmpty {
                await store.fetchProducts()
            }
        }
        // Products failing to load falls back to the full paywall rather than a dead
        // button; dismissing it still finishes onboarding.
        .fullScreenCover(isPresented: $showPaywallFallback, onDismiss: finishOnboarding) {
            SimplePaywallView(paywallImpressionId: "simpleglp_onboarding_trial")
                .environmentObject(store)
        }
        .alert(
            "Couldn't save setup",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Try again.")
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppTheme.brand : AppTheme.surfaceStroke.opacity(0.5))
                    .frame(height: 6)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            medicationStep
        case 2:
            scheduleStep
        case 3:
            reminderStep
        case 4:
            healthStep
        default:
            trialStep
        }
    }

    private func stepHeader(icon: String, iconColor: Color, title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(iconColor)
            }
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "syringe.fill",
                iconColor: AppTheme.brand,
                title: "One big button.",
                subtitle: "Tap it when you take your shot. That's it."
            )
            Text("Optional details, history, and reminders are there if you want them.")
                .font(.body)
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var medicationStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "pills.fill",
                iconColor: AppTheme.brand,
                title: "What are you taking?",
                subtitle: "Pick your medication and current dose."
            )
            VStack(spacing: 14) {
                HStack {
                    Text("Medication")
                        .font(.body)
                    Spacer()
                    Picker("Medication", selection: $medication) {
                        ForEach(GLPMedication.allCases) { med in
                            Text(med.rawValue).tag(med)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .onChange(of: medication) { _, newValue in
                    let presets = newValue.standardDoseStepsMg
                    if presets.isEmpty {
                        useCustomDose = true
                    } else if !presets.contains(doseMg) {
                        doseMg = presets.first ?? doseMg
                        useCustomDose = false
                    }
                }
                if medication == .other {
                    TextField("Medication name", text: $customMedicationName)
                        .textFieldStyle(.roundedBorder)
                }
                doseField
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var doseField: some View {
        let presets = medication.standardDoseStepsMg
        if !presets.isEmpty && !useCustomDose {
            HStack {
                Text("Current dose")
                    .font(.body)
                Spacer()
                Picker("Current dose", selection: $doseMg) {
                    ForEach(presets, id: \.self) { value in
                        Text(Self.format(value)).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            Button("Use custom dose") { useCustomDose = true }
                .font(.footnote)
        } else {
            HStack {
                Text("Current dose (mg)")
                    .font(.body)
                Spacer()
                TextField("0.25", value: $doseMg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            if !presets.isEmpty {
                Button("Use standard dose") {
                    useCustomDose = false
                    if !presets.contains(doseMg) {
                        doseMg = presets.first ?? doseMg
                    }
                }
                .font(.footnote)
            }
        }
    }

    private static func format(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: value as NSNumber) ?? "\(value)") + " mg"
    }

    private var scheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "calendar",
                iconColor: AppTheme.calm,
                title: "How often do you dose?",
                subtitle: "Set your first dose and we'll keep the rhythm from there."
            )
            VStack(alignment: .leading, spacing: 16) {
                ScheduleFields(firstDose: $firstDose, intervalDays: $intervalDays)
                    .font(.body)
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var reminderStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "bell.fill",
                iconColor: AppTheme.warm,
                title: "Reminders",
                subtitle: "A gentle nudge so a busy week doesn't push your shot."
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Remind me on shot day", isOn: $reminderEnabled)
                    .font(.body)
                if reminderEnabled {
                    Divider()
                    Stepper(value: $reminderLeadMinutes, in: 0...180, step: 15) {
                        HStack {
                            Text("Lead time")
                                .font(.body)
                            Spacer()
                            Text("\(reminderLeadMinutes) min before")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("We'll ask permission to send notifications. If you decline, reminders won't fire. You can enable them later in iOS Settings.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "heart.text.square.fill",
                iconColor: .pink,
                title: "Health context",
                subtitle: "See how each dose lands against your real data."
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Auto-capture Health context", isOn: $enableHealth)
                    .font(.body)
                Text("Simple GLP can read weight, glucose, activity, sleep, and more when you log a shot. If you skip this or deny permission, you can turn it on later in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("This adds context to your log. It isn't medical advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Sixth onboarding step: reads as the next Continue, not a paywall. Same
    /// progress capsules (6/6), mint/sage chrome, and CTA slot as steps 0-4. All
    /// trial-only content (soft "Get Started" exit, billing disclosure, error) lives
    /// in the CTA zone ABOVE the primary; the primary button stays pixel-identical to
    /// the prior Continues (Rev A zero-shift), and the Terms/Privacy/Restore footer
    /// fills the reserved slot below it.
    private var trialStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "sparkles",
                iconColor: AppTheme.brand,
                title: "Get more from every shot",
                subtitle: "Simple GLP Pro turns your logs into a clear picture of your journey."
            )
            VStack(alignment: .leading, spacing: 14) {
                trialBullet(icon: "chart.bar.xaxis", text: "See patterns across weight, dose timing, and how you feel")
                trialBullet(icon: "square.and.arrow.up", text: "Export a clean history to share at your next check-in")
                trialBullet(icon: "bell.badge", text: "Smarter reminders so a busy week never skips a shot")
                trialBullet(icon: "lock.shield", text: "Your data stays private, on your device")
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear(perform: handleTrialStepAppear)
    }

    private func trialBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.text)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Bottom bar (Rev A zero-shift CTA)

    /// Rendered on every step. The primary button's frame is pixel-identical across
    /// the flow because everything that varies sits ABOVE it (absorbed by the flexible
    /// ScrollView) and a fixed-height footer slot is reserved BELOW it on every step:
    /// real Terms/Privacy/Restore links on the trial step, the Back button on steps
    /// 1-4, an invisible placeholder on step 0.
    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Variable, trial-only content ABOVE the primary — never shifts the button.
            if isTrialStep {
                trialAboveButton
            }

            Button(action: handlePrimary) {
                Group {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(isTrialStep ? store.onboardingTrialCTALabel : "Continue")
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.brand, in: Capsule())
                .shadow(color: AppTheme.brand.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)

            // Fixed-height footer slot on EVERY step so the button never moves.
            footerSlot
                .frame(height: 22)
        }
    }

    @ViewBuilder
    private var footerSlot: some View {
        if isTrialStep {
            legalFooter
        } else if step > 0 {
            Button("Back") { step -= 1 }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .buttonStyle(.plain)
        } else {
            // Reserve the slot on step 0 so the primary button sits at the same y.
            legalFooter
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 10) {
            Link("Terms", destination: PaywallLinks.standardEULA)
            Text("·").foregroundStyle(.tertiary)
            Link("Privacy", destination: PaywallLinks.privacyPolicy)
            Text("·").foregroundStyle(.tertiary)
            Button("Restore") { Task { await store.restorePurchases() } }
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }

    /// Trial-only content that sits ABOVE the primary CTA (absorbed by the ScrollView
    /// so it never shifts the button): soft free exit, billing disclosure, error.
    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: 10) {
            // Soft free exit ABOVE the primary (Rev A: "Get Started", visually
            // secondary) so the trial button owns the Continue thumb slot.
            Button("Get Started") { finishOnboarding() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.muted)
                .buttonStyle(.plain)
                .disabled(isPurchasing)

            // No disclosure until the package (real price) loads — never a placeholder.
            if let disclosure = store.onboardingTrialDisclosureText {
                Text(disclosure)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let trialError {
                Text(trialError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func handlePrimary() {
        if isTrialStep {
            startTrialPurchase()
        } else {
            step += 1
        }
    }

    /// Stamp the post-onboarding trial surfaces as seen so neither the ~450ms
    /// first-run sheet nor the ~4s first-shot sheet double-pitches after onboarding,
    /// and report the impression once.
    private func handleTrialStepAppear() {
        hasSeenFirstRunOffer = true
        hasSeenTrialOffer = true
        store.trackPaywallImpression(id: "simpleglp_onboarding_trial", oncePerSession: true)
    }

    /// One-tap conversion: buy `onboardingTrialPackage` (monthly) in place (Apple
    /// confirm). Products failing to load presents the full paywall rather than a dead
    /// button; a successful purchase or the emergency paywall both finish onboarding.
    private func startTrialPurchase() {
        guard let package = store.onboardingTrialPackage else {
            showPaywallFallback = true
            return
        }
        trialError = nil
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                switch try await store.purchase(package) {
                case .purchased, .pending:
                    finishOnboarding()
                case .cancelled:
                    trialError = "Trial wasn't started. Tap again, or choose Get Started."
                }
            } catch {
                trialError = store.lastError ?? "Couldn't start your trial. Please try again."
            }
        }
    }

    private func finishOnboarding() {
        guard !hasCompletedOnboarding else { return }
        let trimmedCustomName = customMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard doseMg > 0 else {
            saveError = "Enter a dose greater than 0 mg."
            return
        }
        guard medication != .other || !trimmedCustomName.isEmpty else {
            saveError = "Enter the medication name."
            return
        }

        let plan = MedicationPlan(
            medication: medication,
            customMedicationName: medication == .other ? trimmedCustomName : nil,
            doseMg: doseMg,
            intervalDays: intervalDays,
            reminderEnabled: reminderEnabled,
            reminderLeadMinutes: reminderLeadMinutes
        )
        plan.firstDoseAnchor = firstDose
        modelContext.insert(plan)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(plan)
            saveError = "Your medication plan could not be saved. Please try again."
            return
        }
        GLPOnboardingStore.healthContextEnabled = enableHealth
        if enableHealth {
            Task {
                try? await HealthKitService.shared.prepareAuthorizationDuringOnboarding()
            }
        }
        if reminderEnabled {
            Task { await ReminderService.scheduleNextShotReminder(for: plan) }
        }
        // Suppress the post-onboarding trial sheets (covered on trial-step appear too,
        // but a purchase-then-finish path may not have lingered on the step).
        hasSeenFirstRunOffer = true
        hasSeenTrialOffer = true
        hasCompletedOnboarding = true
    }
}
