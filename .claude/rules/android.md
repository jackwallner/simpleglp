---
paths: ["android/**", "scripts/sync-android-content.py", "scripts/verify-android-artifacts.py"]
---

# Simple GLP Android

Native Kotlin/Compose port in `android/`. Package and namespace
`com.jackwallner.glp`; version name 1.2.2, version code 2. The iOS app remains
the specification. Do not change iOS source while fixing Android.

## Core contracts

- `ScheduleEngine.nextDue` is the sole next-dose calculation. Daily plans match
  by calendar day (3-hour on-schedule window); other cadences match the nearest
  slot (18-hour on-schedule window, 4-day match radius), except that a weekly or
  longer dose within 4 days after an unclaimed slot belongs to that missed slot
  (iOS since 2026-10-30; Android still needs the port). Dose steps apply from the
  start of their day. Advance calendar days, preserving local wall time through DST.
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
- Rating ask (`ReviewPrompts`/`ReviewPolicy`): Play card only, about 3.5s after
  a logged dose or CSV export, from the 2nd launch, 30-day cooldown, One Tap or
  Settings in front with nothing presented. Only an open notification
  permission dialog blocks it; reminders-off users are still asked. A blocked
  ask stays pending. "Rate Simple GLP" opening the listing ends the asks;
  feedback never does.
- Trial pitch (`TrialOfferSheet`, `TrialOfferPolicy`): one-shot, after the
  first logged dose (4s), for existing users on Home (3s) and on Patterns (the
  second touch). Requires resolved entitlements, no active or lapsed Pro, a
  yearly package with a Play free phase, and a clear screen; never under
  `uitesting`. Marked seen when presented.
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

## Play reviewer unlock

Long-press Settings > Support > Version opens a masked Password-keyboard dialog
(autocorrect off). The code's SHA-256 is compared with `PLAY_REVIEW_CODE_SHA256`
(ignored `local.properties` into `BuildConfig`; never the plaintext). A match
stores the digest as `reviewAccessDigest` in the `reviewAccess` preferences
(separate from tracker data, so Delete all data keeps it) and unlocks Pro for
that install only (`ReviewAccess`, applied in `StoreService.apply` so a
customer-info refresh keeps it). No purchase is written, and changing the
digest revokes every earlier grant. `validateReleaseConfiguration` fails
without a valid digest; generate it with `printf '%s' CODE | shasum -a 256`.
Tests: `ReviewAccessTest` (JVM) and `ReviewerUnlockTest` (device, pass a
throwaway code as `-Pandroid.testInstrumentationRunnerArguments.reviewCode=...`
with its digest in `local.properties`; never a real code). Without that
argument the connected test fails by design, so filter it out of routine runs
or supply a throwaway code.

## Fleet Pro runs (jmbp / jmbp2)

Fleet shift runs work directly on the assigned Pro with the checked-in wrapper:
`JAVA_HOME=~/jdks/temurin-17/Contents/Home ANDROID_SERIAL=emulator-5574
./gradlew --max-workers=1 -Dorg.gradle.jvmargs=-Xmx1536m <tasks>` from
`android/`. On jmbp2 (8 GB, Intel) the only AVD is `agent-emu-1` (API 36 Play
image, serial `emulator-5574`); boot it headless with `-no-window -no-audio
-no-boot-anim -no-metrics -no-snapshot-save -gpu swiftshader_indirect` and stop
it with `adb -s emulator-5574 emu kill`. A full connected run takes about 12
minutes there. Its mobile data was found off (no default network, RevenueCat
unreachable); `adb -s emulator-5574 shell svc data enable` restores it. The AVD
gets one vCPU and a software GPU there, so frame timing (1.8 fps measured
2026-10-20) says nothing about the app; native cadence needs the Air motion
task. jmbp2's `scrcpy` wrapper points at a missing binary; record with
`adb shell screenrecord` and analyze with `fleet-record60.py verify`.

Debug Test Store products are `monthly`, `yearly`, `lifetime` (simulated
$79.99/yr, no trial phase). `StoreService` accepts those IDs only with a
`test_` key; the purchase dialog's "Test valid purchase" unlocks Pro with no
charge.

## Remote emulator only

Host `jackwallner@192.168.4.25`, strict SSH host checking, SDK
`/Users/jackwallner/Library/Android/sdk`, Intel x86_64 API 36 Play image.
Temporary AVD `simpleglp_agent_test`, serial `emulator-5574`. Coordinate with
other agents first. Do not target `small_phone`, `bridge_agent_test`, or an
unqualified ADB device. No local emulator, no ADB forwarding.

Builds and tests use `fm-gradle <tasks>` from `android/`, never `./gradlew` on
the Air. It runs on the Pro with its JDK 17, syncs the source with a debug-only
`local.properties` (no Play key or signing credentials) and forwards
`ANDROID_SERIAL`, so connected tests need no hand sync.

Check readiness:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 '/Users/jackwallner/Library/Android/sdk/platform-tools/adb devices -l; /Users/jackwallner/Library/Android/sdk/platform-tools/adb -s emulator-5574 shell getprop sys.boot_completed'
```

Boot only when the device is not already running:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 'nohup /Users/jackwallner/Library/Android/sdk/emulator/emulator -avd simpleglp_agent_test -port 5574 -no-window -no-audio -no-boot-anim -no-metrics -no-snapshot-save > /tmp/simpleglp-agent-emulator.log 2>&1 < /dev/null &'
```

Run connected tests from `android/` with a 1536 MiB Gradle heap:

```sh
ANDROID_SERIAL=emulator-5574 fm-gradle --max-workers=1 -Dorg.gradle.jvmargs=-Xmx1536m connectedDebugAndroidTest
```

Confirm the XML/HTML report contains a nonzero executed count.
Do not accept a successful Gradle exit with zero tests.

Shutdown only this test device:

```sh
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes jackwallner@192.168.4.25 '/Users/jackwallner/Library/Android/sdk/platform-tools/adb -s emulator-5574 emu kill; /Users/jackwallner/Library/Android/sdk/platform-tools/adb devices -l'
```

Remove only the temporary Simple GLP AVD when finished. Preserve every existing Play AVD and account.

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
The Play app, products and drafts exist (see Play staging below). Listing copy, Data safety, app content answers, product
and base-plan IDs and the remaining Console steps are in
`project-docs/android/play-listing.md`; `docs/privacy-policy.html` has an
Android section that must be published before the Play record points at it.
External upload PKCS12, encrypted backup, and app-specific Play SDK key are
configured locally. Production billing, store pricing, license-tester
purchases/restore, service-account package access, and final Play declarations
remain unverified.

## Play staging, 2026-10-21

Play app 4973861751220811917 (Draft). vc1 1.2.2 drafts on internal and
production; products `com.jackwallner.glp.pro.{monthly,yearly,lifetime}`
active. RevenueCat Play products (project `proja722b48d`, app
`app3610516bb2`) are attached to `GLP Pro` and the three packages; the
lifetime is non-consumable. All App content is saved, data safety included
(purchase history and device ID, App functionality). The reviewer unlock shipped
in code on 2026-10-21 with versionCode 2. Left: choose the real review code,
put its SHA in the Air's `local.properties`, rebuild and upload vc2, enter the
code in the Play app access instructions, then Send for review in its pacing
slot.
