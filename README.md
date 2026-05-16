# Simple GLP

Simple GLP is a private, one-tap GLP-1 shot tracker for iPhone, Apple Watch, and widgets.

## What It Does

- Log a GLP-1 shot with one tap from the app, widget, or watch.
- Save medication, dose, schedule, injection site, notes, and symptoms.
- Read optional HealthKit context like weight, glucose, activity, sleep, heart rate, workouts, water, caffeine, calories, and protein.
- Keep all shot and Health context data on device using SwiftData and an App Group.
- Offer optional Simple GLP Pro proactive alerts through RevenueCat and Apple in-app purchases.

## Tech

- Swift 6
- SwiftUI
- SwiftData
- HealthKit
- WidgetKit
- App Intents
- WatchConnectivity
- RevenueCat
- XcodeGen

## Build

```bash
xcodegen generate
xcodebuild -project SimpleGLP.xcodeproj -scheme SimpleGLP -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Legal

The public landing page, privacy policy, terms, and support pages live in `docs/` for GitHub Pages.
