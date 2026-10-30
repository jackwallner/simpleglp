import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreService
    @AppStorage(GLPStorageKey.hasCompletedOnboarding.rawValue, store: GLPAppGroup.userDefaults) private var hasCompletedOnboarding = false
    @AppStorage(GLPStorageKey.hasSeenTrialOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenTrialOffer = false
    @AppStorage(GLPStorageKey.hasSeenFirstRunOffer.rawValue, store: GLPAppGroup.userDefaults) private var hasSeenFirstRunOffer = false
    @State private var step = 0
    @State private var form: DoseForm = .injection
    @State private var medication: GLPMedication = .ozempic
    @State private var waitMinutes = 0
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
    private static let medicationStepIndex = 1

    /// Why the medication step can't be saved yet, or nil when it can.
    static func medicationProblem(medication: GLPMedication, customName: String, doseMg: Double) -> String? {
        if medication.isCustom && customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "Enter the medication name.")
        }
        if !(doseMg > 0) {
            return String(localized: "Enter a dose greater than 0 mg.")
        }
        return nil
    }

    private var medicationProblem: String? {
        Self.medicationProblem(medication: medication, customName: customMedicationName, doseMg: doseMg)
    }

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
        .onChange(of: store.isProUnlocked) { _, isPro in
            if isPro && isTrialStep { finishOnboarding() }
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
            Text(saveError ?? String(localized: "Try again."))
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
                icon: "hand.tap.fill",
                iconColor: AppTheme.brand,
                title: String(localized: "One big button."),
                subtitle: String(localized: "When you take your weekly shot or daily pill, tap once to log it.")
            )
            Text("On a pill, the same tap starts your wait-before-eating countdown. Reminders, history, and a streak are there if you want them.")
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
                title: String(localized: "What are you taking?"),
                subtitle: String(localized: "Pick how you take it, then your medication and current dose.")
            )
            HStack(spacing: 12) {
                formCard(.injection, title: String(localized: "Shot"), detail: String(localized: "Weekly or custom"))
                formCard(.pill, title: String(localized: "Pill"), detail: String(localized: "Once a day"))
            }
            VStack(spacing: 14) {
                HStack {
                    Text("Medication")
                        .font(.body)
                    Spacer()
                    MedicationPicker(medication: $medication, forms: [form])
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
                    waitMinutes = newValue.defaultWaitMinutes
                }
                if medication.isCustom {
                    TextField("Medication name", text: $customMedicationName)
                        .textFieldStyle(.roundedBorder)
                }
                doseField
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func formCard(_ option: DoseForm, title: String, detail: String) -> some View {
        let selected = form == option
        return Button {
            selectForm(option)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: option.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(selected ? .white : AppTheme.brand)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(selected ? .white : AppTheme.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.85) : AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(selected ? AppTheme.brand : AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Color.clear : AppTheme.surfaceStroke.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Switching between shot and pill resets the defaults that differ between them.
    private func selectForm(_ option: DoseForm) {
        guard form != option else { return }
        form = option
        medication = GLPMedication.options(for: option).first ?? medication
        doseMg = medication.standardDoseStepsMg.first ?? doseMg
        useCustomDose = medication.standardDoseStepsMg.isEmpty
        waitMinutes = medication.defaultWaitMinutes
        intervalDays = option.defaultIntervalDays
        firstDose = Calendar.current.date(bySettingHour: option.defaultHour, minute: 0, second: 0, of: .now) ?? firstDose
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
                TextField("", value: $doseMg, format: .number, prompt: Text(0.25, format: .number))
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
        GLPMassFormatter.milligrams(value)
    }

    @ViewBuilder
    private var scheduleStep: some View {
        if form == .pill {
            pillScheduleStep
        } else {
            shotScheduleStep
        }
    }

    private var pillScheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "sunrise.fill",
                iconColor: AppTheme.calm,
                title: String(localized: "Your daily routine"),
                subtitle: String(localized: "When you usually take it, and how long you wait before eating or drinking.")
            )
            VStack(alignment: .leading, spacing: 16) {
                DatePicker("Usual time", selection: $firstDose, displayedComponents: .hourAndMinute)
                Divider()
                WaitField(minutes: $waitMinutes)
                Text(waitMinutes > 0
                     ? String(localized: "Tapping “I took my pill” starts a \(waitMinutes)-minute countdown and pings you when it’s done. Match it to your prescriber’s instructions.")
                     : String(localized: "No countdown. Set one if your instructions include a wait before food or drink."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.body)
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var shotScheduleStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            stepHeader(
                icon: "calendar",
                iconColor: AppTheme.calm,
                title: String(localized: "How often do you dose?"),
                subtitle: String(localized: "Set your first dose and we'll keep the rhythm from there.")
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
                title: String(localized: "Reminders"),
                subtitle: form == .pill
                    ? String(localized: "A nudge each day, skipped once you've logged your pill.")
                    : String(localized: "A gentle nudge so a busy week doesn't push your shot.")
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle(form == .pill ? String(localized: "Remind me daily") : String(localized: "Remind me on shot day"), isOn: $reminderEnabled)
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
                title: String(localized: "Health context"),
                subtitle: String(localized: "See how your doses line up with your real data.")
            )
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Auto-capture Health context", isOn: $enableHealth)
                    .font(.body)
                Text("Simple GLP can read weight, glucose, activity, sleep, and more when you log a dose. If you skip this or deny permission, you can turn it on later in Settings.")
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
                title: form == .pill ? String(localized: "Make the daily routine effortless") : String(localized: "Keep your shot schedule in view"),
                subtitle: String(localized: "Simple GLP Pro takes care of the parts that are easy to forget.")
            )
            VStack(alignment: .leading, spacing: 14) {
                ForEach(ProFeatures.bullets(isPill: form == .pill), id: \.title) { bullet in
                    trialBullet(icon: bullet.icon, text: bullet.line)
                }
                trialBullet(icon: "lock.shield", text: String(localized: "Your data stays private, on your device"))
            }
            .padding(18)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                        Text(isTrialStep
                             ? (store.isPurchasePending ? String(localized: "Refresh status") : store.onboardingTrialCTALabel)
                             : String(localized: "Continue"))
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
            .disabled(isPurchasing
                      || (isTrialStep && (store.isLoadingProducts || store.isRefreshingPurchase))
                      || (step == Self.medicationStepIndex && medicationProblem != nil))

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
    /// so it never shifts the button): medical disclaimer, soft free exit, billing
    /// disclosure, error. The disclaimer lives here, not in the scrolling content,
    /// so it can never fall below the fold behind the CTA zone (App Review 1.4.1).
    @ViewBuilder
    private var trialAboveButton: some View {
        VStack(spacing: 10) {
            Text("Tracking only. Simple GLP isn't medical advice and doesn't diagnose or treat any condition.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("onboardingMedicalDisclaimer")

            // Soft free exit ABOVE the primary (Rev A: "Get Started", visually
            // secondary) so the trial button owns the Continue thumb slot.
            Button(store.isPurchasePending ? String(localized: "Continue free") : String(localized: "Get Started")) {
                ConversionDiagnostics.record(.freeVersionChosen)
                store.syncConversionAttributes()
                finishOnboarding()
            }
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

            if store.isPurchasePending {
                Text(StoreService.pendingPurchaseMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
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
        ConversionDiagnostics.record(.trialOfferReached)
        store.trackPaywallImpression(id: "simpleglp_onboarding_trial", oncePerSession: true)
    }

    /// One-tap conversion: buy the yearly trial in place (Apple confirm). Products
    /// failing to load presents the full paywall rather than a dead button; a
    /// successful purchase or the emergency paywall both finish onboarding.
    private func startTrialPurchase() {
        if store.isProUnlocked {
            finishOnboarding()
            return
        }
        if store.isPurchasePending {
            Task { await store.refreshPendingPurchaseStatus() }
            return
        }
        guard let package = store.directTrialPackage else {
            showPaywallFallback = true
            return
        }
        if store.isIntroEligibilityUnknown(package) {
            Task { await store.fetchProducts() }
            return
        }
        trialError = nil
        isPurchasing = true
        ConversionDiagnostics.record(.trialCTATapped)
        Task { @MainActor in
            defer {
                isPurchasing = false
                store.syncConversionAttributes()
            }
            do {
                switch try await store.purchase(package) {
                case .purchased:
                    finishOnboarding()
                case .pending:
                    break
                case .cancelled:
                    ConversionDiagnostics.record(.purchaseCancelled)
                    trialError = String(localized: "Trial wasn't started. Tap again, or choose Get Started.")
                }
            } catch {
                ConversionDiagnostics.record(.purchaseFailed)
                trialError = store.lastError ?? String(localized: "Couldn't start your trial. Please try again.")
            }
        }
    }

    private func finishOnboarding() {
        guard !hasCompletedOnboarding else { return }
        let trimmedCustomName = customMedicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let medicationProblem {
            // The last step has no Back, so return to the field that needs fixing.
            saveError = medicationProblem
            step = Self.medicationStepIndex
            return
        }

        let isPill = medication.form == .pill
        let plan = MedicationPlan(
            medication: medication,
            customMedicationName: medication.isCustom ? trimmedCustomName : nil,
            doseMg: doseMg,
            intervalDays: isPill ? 1 : intervalDays,
            waitMinutes: isPill ? waitMinutes : 0,
            reminderEnabled: reminderEnabled,
            reminderLeadMinutes: reminderLeadMinutes
        )
        plan.firstDoseAnchor = isPill
            ? PlanEditorView.dailyAnchor(time: firstDose, existing: .now)
            : firstDose
        modelContext.insert(plan)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(plan)
            saveError = String(localized: "Your medication plan could not be saved. Please try again.")
            return
        }
        GLPOnboardingStore.healthContextEnabled = enableHealth
        if enableHealth {
            Task {
                try? await HealthKitService.shared.prepareAuthorizationDuringOnboarding()
            }
        }
        DoseRoutineService.refresh(in: modelContext)
        // Suppress the post-onboarding trial sheets (covered on trial-step appear too,
        // but a purchase-then-finish path may not have lingered on the step).
        hasSeenFirstRunOffer = true
        hasSeenTrialOffer = true
        hasCompletedOnboarding = true
    }
}

/// The pane beside onboarding on the unfolded iPhone Duo: the One Tap button the
/// setup leads to, so the second half of the display previews the app rather
/// than sitting empty.
struct OnboardingFoldPanel: View {
    var body: some View {
        VStack(spacing: 28) {
            Circle()
                .fill(AppTheme.brand)
                .frame(width: 200, height: 200)
                .shadow(color: AppTheme.brand.opacity(0.28), radius: 22, x: 0, y: 12)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.white)
                }
            VStack(spacing: 8) {
                Text("One tap. Logged.")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text("Your next dose and your history, side by side.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.bg.ignoresSafeArea())
        .accessibilityElement(children: .combine)
    }
}
