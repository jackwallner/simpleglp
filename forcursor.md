# Simple GLP — Handoff

## What’s done

- **XcodeGen project** (`project.yml`): iOS app, widget, watch, tests. SPM includes RevenueCat only (native paywall).
- **Release scripts**: `scripts/testflight.sh`, `upload-testflight.sh`, `upload-testflight-api.sh`, `fastlane/Fastfile`, `AppStoreUploadOptions.plist`, `ExportOptions-AppStore.plist`.
- **Target resources**: Info.plists, entitlements, privacy manifests, asset catalogs for app/widget/watch.
- **Shared storage**: `SharedGLP/GLPAppGroup.swift` with app group `group.com.jackwallner.glp`.
- **Data layer**: `GLPModels.swift` with `ShotEvent`, `MedicationPlan`, `DoseStep`, and `HealthSnapshot`. `GLPModelStore.swift` sets up SwiftData with app-group fallback.
- **Schedule engine**: `ScheduleEngine.swift` maps shot timestamps to expected dose windows.
- **Health capture**: `HealthKitService.swift` reads weight, glucose, activity, sleep, heart, workouts, water, caffeine, nutrition.
- **One-tap coordinator**: `ShotCaptureCoordinator.swift` saves immediately, enriches async, supports undo, and handles widget/watch pending events.
- **Reminders**: `ReminderService.swift` schedules next-shot notifications.
- **Pro alerts engine**: `ProactiveAlertsEngine.swift` analyzes weekday timing patterns and schedules local notifications.
- **RevenueCat**: `StoreService.swift`, `Products.storekit` with Simple GLP product IDs.
- **App shell**: `SimpleGLPApp.swift`, `RootTabView.swift`, `SharedViews.swift`.

## What’s done (continued)

- **Screens**: Onboarding, Home, LogHub, History, Insights, Settings, SimplePaywallView, ProAlertsConfig.
- **Widget**: `SimpleGLPWidget.swift` + `LogShotIntent.swift` one-tap AppIntent.
- **Watch**: `SimpleGLPWatchApp.swift`, `WatchRootView.swift`, `WatchConnectivityController.swift`.
- **PhoneWatchSession**: `PhoneWatchSession.swift` handles incoming watch log requests.
- **Import/export**: `ExportService.swift` and `ImportService.swift`.
- **Tests**: `SimpleGLPTests.swift`.

## Build status

- **Project generated**: `xcodegen generate` completes and writes `SimpleGLP.xcodeproj`.
- **Build verified**: `xcodebuild -project SimpleGLP.xcodeproj -scheme SimpleGLP -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- **Tests verified**: `xcodebuild test -project SimpleGLP.xcodeproj -scheme SimpleGLP -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO` passes.

## Known todos before a real build

1. **RevenueCat key**: Configured in `SimpleGLP/Services/StoreService.swift`.
2. **App icons**: Add images to `SimpleGLP/Assets.xcassets/AppIcon.appiconset` and watch equivalent, or the build will warn.
3. **Signing**: Ensure `com.jackwallner.glp`, `com.jackwallner.glp.widget`, and `com.jackwallner.glp.watch` bundle IDs plus `group.com.jackwallner.glp` app group are registered in your Apple Developer account. `DEVELOPMENT_TEAM` is already set to `YXG4MP6W39`.
4. **TestFlight**: To upload, run `./scripts/testflight.sh` from the repo root. Requires Xcode signed into App Store Connect.
5. **Swift 6 / iOS 17**: The project uses Swift 6 and targets iOS 17.0+ / watchOS 10.0+.

## Next concrete step

Open `SimpleGLP.xcodeproj` in Xcode, configure signing/app groups in the Apple Developer account, then run the app on device before TestFlight.
