---
paths:
  - "SimpleGLP/**"
  - "SharedGLP/**"
  - "SimpleGLPWidget/**"
  - "SimpleGLPWatch/**"
  - "Tools/Localization/**"
---

# Simple GLP localization

The app, widgets, Live Activity, Watch app, App Intents, and notifications ship
in English plus pt-BR, tr, es, pl, zh-Hant, ru, hu, it, de, and fr.

## Setup

- `SharedGLP/Localizable.xcstrings` is compiled by the app, widget, and Watch
  targets through the shared source folder. XcodeGen 2.39+ reads its languages
  into `knownRegions`. Every target Info.plist lists `CFBundleLocalizations`.
- `SimpleGLP/InfoPlist.xcstrings` localizes HealthKit permission explanations.
- `python3 Tools/Localization/check.py` checks source strings, language
  coverage, and format placeholders without Xcode.
- `SimpleGLPTests/LocalizationTests.swift` verifies language bundles and
  Russian and Polish plural selection.

## Copy and stored values

- SwiftUI text literals are catalog keys. Copy held in models, notifications,
  App Intents, and other `String` values uses `String(localized:)`.
- Translate complete sentences. Branch for different dose forms instead of
  joining translated fragments. Use plural variations for counted labels.
- Medication names and Health status messages saved in English stay unchanged
  in storage. Translate known values when displaying them. User-entered names
  and notes pass through as written.
- Keep `Simple GLP`, medication brand names, product identifiers, storage keys,
  analytics names, and notification identifiers unchanged.
- Use Foundation formatters for dates, times, numbers, units, durations, and
  currency. Trial durations come from StoreKit metadata, never parsed copy.
- Do not imply a dosing recommendation or medical outcome. Follow the
  prescriber's instructions and preserve the complete medical disclaimer.

## Proving a change

Run `python3 Tools/Localization/check.py`, then the public-repository `gh-sim`
test and screenshot workflows. Use `-AppleLanguages`, `-AppleLocale`, seeded
data (`-GLPScreenshotSeed`, optionally `-GLPScreenshotPill`),
`-PaywallSnapshot trial`, and `-GLPScreenshotWidget` for the Lock Screen widget
view. StoreKit prices come from the scheme's `Products.storekit` configuration.
