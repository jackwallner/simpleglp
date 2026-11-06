---
paths:
  - "fastlane/screenshots/**"
  - "artifacts/asc-screenshots/**"
  - "SimpleGLP/**"
---

# App Store screenshots

## Localized store sets

- Capture English and all target locales in one GitHub simulator test job with
  `artifacts/asc-screenshots/l10n-20261105/tools/capture.sh`. No arguments capture
  English plus all targets; locale arguments select exactly those locales.
  `GH_SIM_SCENES` can limit a repair run to space-separated scene basenames.
  The UI test reads `capture-locales.json`, relaunches once per scene, waits 14
  seconds for first-render settling, and writes raw
  scenes under `KIT/raw/`. `gh-sim launch` timed out during setup for this app;
  the test adapter took 10m39s for the 14-scene validation pass. Exported PNGs
  use UUID filenames, so resolve them through `attachments/manifest.json`.
- Run `artifacts/asc-screenshots/l10n-20261105/tools/compose.sh` after capture.
  It replaces the phone screens, renders translated headers and extra frame copy,
  runs the OCR gate, writes comparison sheets to `KIT/sheets/`, and copies only
  the configured root PNG frames into each target `fastlane/screenshots/` folder.
- The seven live phone frames share one device layout. History, Insights, dose
  details, the medication plan editor, the confirmation state, and Pro alerts
  use DEBUG launch arguments. The displayed app content remains real SwiftUI.
- For this refresh, normalized cross-correlation could not match the current app
  screens to the older English set. `locate.py --bezel --radius` found the shared
  phone bounds consistently, so `frames.json` uses that fallback geometry.
- The composer uses the live background and a clean interpolated header region.
  Add compositor text to `extra_text` in `frames.json`, with translations in
  `copy/headers.json` under `<frame>#<key>`. Do not place decorations across the
  header without a clean plate.
