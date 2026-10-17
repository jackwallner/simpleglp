---
paths: ["android/**", "scripts/sync-android-content.py", "scripts/verify-android-artifacts.py"]
---

# Simple GLP Android

Native Kotlin/Compose port in `android/`. Package and namespace
`com.jackwallner.glp`; version name 1.2.2, version code 1. The iOS app remains
the specification. Do not change iOS source while fixing Android.

## Core contracts

- `ScheduleEngine.nextDue` is the sole next-dose calculation. Daily plans match
  by calendar day (3-hour on-schedule window); other cadences match the nearest
  slot (18-hour on-schedule window, 4-day match radius). Advance calendar days,
  preserving local wall time through DST.
- Logging, reminders, in-app pill countdown plus wait-complete notification,
  streak, History, and Patterns are free. Patterns need 5 logs. Supply/refill
  tracking, the ongoing Lock Screen pill countdown notification, and Proactive Alerts
  require `StoreService.isPro`.
- Weekly hands-free duplicates are blocked within 12 hours, daily duplicates
  on the same calendar day. Log earlier is explicit history entry and can
  record another dose. Never recommend a medication, dose, or timing.
- Supply is derived from the last refill timestamp and logs since then. Undo
  and delete restore the count. Countdown reads the latest real past log and
  the current pill plan; undo/delete/edit/plan changes reschedule notifications.
- Export/import matches iOS's 23 CSV columns, quoting, and additive merge.
  Imports retain all health context strings and all existing event IDs.
  Imported entries get new IDs because the iOS CSV has no UUID column.
- Run `python3 scripts/sync-android-content.py` after medication catalog edits.
  It compiles the actual iOS enums to a JVM parity fixture. Tests compare every
  name, form, strength, wait default, and custom flag.

## Billing and release

RevenueCat project `proja722b48d`, Play app `app3610516bb2`.
Entitlement `GLP Pro` (legacy fallbacks `SimpleGLPPro`, `pro`). Product IDs:
`com.jackwallner.glp.pro.monthly`, `.yearly`, `.lifetime`. Same default offering
package types as iOS; Play subscription IDs get monthly/yearly base plans.
Pricing and any trial phase come from RevenueCat, never hardcoded.

Ignored `android/local.properties` holds SDK/key/signing configuration. Debug
requires a Test Store `test_` key to enable billing; no key keeps free tracking
usable. Release validation rejects missing Play `goog_` key and external upload
signing. `qa` is the optimized release source with debug signing, no billing
key, and no test hooks. Never use a production Play key in routine tests.

## Remote emulator only

Host `jackwallner@192.168.4.25`, strict SSH host checking, SDK
`/Users/jackwallner/Library/Android/sdk`, Intel x86_64 API 36 Play image.
Temporary AVD `simpleglp_agent_test`, serial `emulator-5574`. Coordinate with
other agents first. Do not target `small_phone`, `bridge_agent_test`, or an
unqualified ADB device. No local emulator, no ADB forwarding.

JDK 17 is required. Keep a verified temporary Temurin 17 runtime at
`/Users/jackwallner/simpleglp-agent-test/jdk/Contents/Home` on Pro, then set
`JAVA_HOME` to that path. The temporary runtime is removed after testing. Sync source excluding `build/`,
`.gradle/`, `local.properties`, and all signing credentials. Create remote
`local.properties` containing only `sdk.dir=/Users/jackwallner/Library/Android/sdk`.

Check readiness:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 '/Users/jackwallner/Library/Android/sdk/platform-tools/adb devices -l; /Users/jackwallner/Library/Android/sdk/platform-tools/adb -s emulator-5574 shell getprop sys.boot_completed'
```

Boot only when the device is not already running:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 'nohup /Users/jackwallner/Library/Android/sdk/emulator/emulator -avd simpleglp_agent_test -port 5574 -no-window -no-audio -no-boot-anim -no-metrics -no-snapshot-save > /tmp/simpleglp-agent-emulator.log 2>&1 < /dev/null &'
```

Run remote connected tests from the synchronized Android directory, with
`ANDROID_SERIAL=emulator-5574`, `--no-daemon --max-workers=1` and a 1536 MiB
Gradle heap. Confirm the XML/HTML report contains a nonzero executed count.
Do not accept a successful Gradle exit with zero tests.

Shutdown only this test device:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 '/Users/jackwallner/Library/Android/sdk/platform-tools/adb -s emulator-5574 emu kill; /Users/jackwallner/Library/Android/sdk/platform-tools/adb devices -l'
```

Remove only the temporary Simple GLP AVD and synchronized source/runtime when
finished. Preserve every existing Play AVD and account.

## Platform gaps and Play state

Apple Health auto-read is unavailable in this version. The UI says so; imported
health context is preserved and shown. Patterns still provides dose adherence,
streak, median pill time, and shot weekday statistics without health access.
No Health Connect permission is requested. Wear OS and widgets are omitted in
this first Android build. The Live Activity equivalent is a Pro-only ongoing
notification with a countdown chronometer and timeout at the shared wait
deadline. Undo/delete/plan changes and resolved Pro loss cancel it. Its public
Lock Screen content contains only the generic timer and deadline. The in-app
timer and completion notification remain free.

RevenueCat Play app is registered in the existing GLP project. Android and iOS
platform filters are registered in `~/.rc-clean/apps.json` and synced to MBP.
No Play Console app, product, track, upload, or submission has been created.
External upload PKCS12, encrypted backup, and app-specific Play SDK key are
configured locally. Production billing, store pricing, license-tester
purchases/restore, service-account package access, and final Play declarations
remain unverified. This session is builds/testing only.
