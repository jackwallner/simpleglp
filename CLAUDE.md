# Simple GLP — Project Guide

GLP-1 shot tracker: log the injection, see the schedule and the next dose, and
read back patterns from what was logged. XcodeGen project/scheme: `SimpleGLP`,
sim lease owner `simpleglp`. App Store ID `6770137909`.

## Tech Stack
- Swift 6 / SwiftUI (strict concurrency)
- HealthKit (read), WidgetKit, watchOS companion, local notifications
- XcodeGen (`project.yml`). Targets: iOS 17+, watchOS
- RevenueCat, gate is `StoreService.isProUnlocked`

## Targets / bundle IDs
- `SimpleGLP` — `com.jackwallner.glp`
- `SimpleGLPWidget` — `.widget`
- `SimpleGLPWatch` — `.watch`
- `SimpleGLPTests` — `.tests`, `SimpleGLPUITests` — `.uitests`
- App Group: `group.com.jackwallner.glp`

## Architecture
`SharedGLP/` is the small module the phone, watch and widget all compile:
`GLPAppGroup`, `RecentShotsStore`, `ReviewPromptTracker`, `AppStoreReviewLinks`.
Anything a glance surface needs has to live there or reach it through the App
Group.

`SimpleGLP/` is the phone app:
- `Models/` — `GLPModels`, `ProAlertPreferences`
- `Services/`
  - `ShotCaptureCoordinator` — the log path every surface goes through
  - `GLPModelStore`, `PlanStore`, `ScheduleEngine` — the dose plan, its cadence,
    and the next-dose arithmetic
  - `ReminderService`, `ProactiveAlertsEngine` — local notifications
  - `HealthKitService` — the optional Health reads behind Insights
  - `ExportService` / `ImportService`, `StoreService`, `PhoneWatchSession`,
    `DiagnosticsService`, `ConversionDiagnostics`
- `Views/` — `RootTabView`, `HomeView`, `HistoryView`, `InsightsView`,
  `OnboardingView`, `SimplePaywallView`, `TrialOfferSheet`, `SettingsView`,
  `ProAlertsConfigView`
- `Utilities/` — `AppTheme`, `AppEnvironment`, `PaywallScreenshotMode`

## Rules that hold everywhere
- **Free vs Pro.** Logging a shot, the schedule, history and Insights are free;
  Insights simply needs `ProactiveAlertsEngine.minimumSampleSize` shots before it
  says anything. Pro (`StoreService.isProUnlocked`) is what opens Proactive
  Alerts, reached from the Insights row and from Settings. Products:
  subscriptions `com.jackwallner.glp.pro.monthly` /
  `.pro.yearly` plus the non-consumable `.pro.lifetime`
  (`SimpleGLP/Services/Products.storekit`).
- **Never present a promo or trial sheet before entitlements resolve.**
  `RootTabView` gates every sheet on resolved entitlements and `!isProUnlocked`,
  because a recent purchase can flip Pro a beat after launch and pull a sheet out
  from under the layout.
- **This is a medication tracker, not medical advice.** It records what the user
  says they injected and when. Never phrase a schedule, a reminder or an insight
  as a dosing recommendation (App Review 1.4.1).
- **Review funnel:** `ReviewPromptTracker.recordPositiveMoment()` after a logged
  shot (`ShotCaptureCoordinator`) and from Settings. App Store ID above.
- **`scripts/aso-apply-locale-optimizations.py` is stale and renames the app.**
  Do not run it blindly; read it first and prefer the current ASC upload flow.
  Keyword reasoning lives in `aso-plan.md`.

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing,
review funnel, gotchas): always-loaded global CLAUDE.md + the `ios-dev` skill.
