# Simple GLP Android port verification

The native Kotlin/Compose implementation covers weekly shots and daily pills,
custom shot cadences, medication/dose editing and scheduled dose changes, one-tap and
backdated logging, symptoms and notes, injection site, history editing/deletion,
undo, pill waits, local reminders and notification actions, calendar adherence,
free Patterns, Pro supply/refill tracking and proactive alerts, appearance,
feedback, and additive iOS-compatible CSV export/import. First run follows the
six iOS stages: welcome, medication, schedule, reminders, optional context,
and membership. Drafts survive recreation and back navigation; the fixed
Continue and free exit controls remain accessible. Settings retains its own
plan editor. Pills always use a daily cadence.

Persistence is local SharedPreferences with synchronous checked writes. Failed
reads preserve the original bytes and show a recovery message. No health data
is sent to RevenueCat. Billing is disabled when no valid platform-appropriate
local key is supplied. Debug/Test Store and release/Play keys are separated.
Optimized QA builds use release source and no test unlock hooks.

## Intentional platform differences

- Apple Health auto-read is unavailable; the interface says so. All 17 optional
  CSV context columns, including symptoms, are preserved on import/export.
- Watch and widgets are omitted for v1. A Pro-only ongoing notification replaces
  the iOS Lock Screen/Dynamic Island running countdown. It uses the shared wait
  deadline, native chronometer countdown, and a system timeout. Undo/delete/plan
  changes and resolved entitlement loss cancel it. The in-app countdown and
  completion notification remain free.
- Android reminders are inexact and can be delayed by battery management. No
  exact-alarm permission is requested.
- CSV import assigns new event IDs, matching iOS. Existing IDs stay untouched.
- No store listing, upload or submission was requested for this session.

## Verification

Commands use JDK 17, one Gradle worker, and a 1536 MiB heap. Device
verification runs only over strict SSH on the MacBook Pro. Debug uses the
RevenueCat Test Store key; production Play credentials never run on an
emulator.

The compiled iOS medication fixture and 42 JVM parity/regression tests pass
(42 executed, zero failures/errors/skips). Coverage includes daily and weekly
matching, DST, Swift rounding boundaries, duplicates, waits, medication/plan
changes, supply/undo, 23-column CSV context preservation/merge, and persistence.

The final debug APK passes 16 instrumented tests on the temporary API 36
MacBook Pro device (199.609 seconds, zero failures). These exercise shot/pill
first run and free exit, member onboarding, saved drafts and fixed CTA/footer
frames, log/undo, duplicate protection, keyboard entry, edit persistence, plan
changes, delete/countdown cancellation, free supply gating, Pro supply/undo,
and real system notification countdown flags, deadline, timeout, and removal.
The final palette correction is included in this APK.

Real-device captures were inspected in [light mode](screenshots/home-light.png),
[dark mode with active pill wait](screenshots/pill-dark.png),
[first-run welcome](screenshots/onboarding-welcome.png), and
[unavailable-offering membership step](screenshots/onboarding-membership.png).
They use synthetic debug fixtures. They are verification captures, not store
marketing assets. The membership step retains a free exit and does not invent
pricing or a trial while no valid offering is available. The
[native countdown capture](screenshots/pro-countdown-notification.png) shows
the actual silent system notification with a running chronometer and generic
deadline. GMS warning cards belong to the temporary emulator, where Google
services were disabled to avoid resource contention. They are unrelated to
app behavior.

An app-specific RevenueCat Play SDK key and external upload signing key are
configured in ignored local properties. RevenueCat Play registration uses the
existing GLP project, with rc-clean platform filters synced to MBP. Play billing
is not represented by the isolated QA build, and no purchases were started.

## Signed artifacts

Final build command (successful in 8 minutes 35 seconds):

```sh
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home ./android/gradlew -p android assembleRelease bundleRelease assembleQa bundleQa --no-daemon --max-workers=1 -Dorg.gradle.jvmargs=-Xmx1536m
```

Release and QA lint-vital tasks pass. The optimized QA APK (2,742,509 bytes)
and AAB (4,825,596 bytes) contain no SDK key and no debug launch hooks. They
use release source and R8 with debug signing for isolated emulator testing.
The optimized QA APK was installed only on the MBP device. Existing pill data
loaded, and One Tap, History, Patterns, and Settings all rendered through real
navigation. AndroidRuntime reported zero fatal exception blocks for the app.

The upload-signed release APK and AAB pass signature and ZIP integrity checks.
The APK also passes `zipalign -c -P 16 4`. Both artifacts contain four native
libraries with all ELF load alignments at least 16 KiB. DEX inspection finds
one app-specific Play SDK key, no Test Store/iOS/secret key, and no debug
launch hooks. Package `com.jackwallner.glp`, version code 1, name 1.2.2, minimum
API 26, target/compile API 36. No health, location, storage, or exact-alarm
permission is present.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `android/app/build/outputs/apk/release/app-release.apk` | 3,184,878 | `2f7a663f52d956df38ff9e996253a26d31439227bc5df8eeb67a5b88fdaf7bbb` |
| `android/app/build/outputs/bundle/release/app-release.aab` | 6,114,386 | `eef43e39ede8da0468a21b31d72c52717993f645a19a7466768776115f9dcb05` |

The upload certificate SHA-256 is
`37b9612caab36efac3c56f551fc3cc7e4613bb8d8284d0717dddbe29c9125c2d`.
Signing material and SDK configuration remain outside source control.

The temporary MBP emulator was shut down after QA. Its serial and qemu
process were confirmed absent before removing only the Simple GLP AVD,
synchronized source, and temporary JDK. Other AVDs and accounts were preserved.

## 2026-10-20 fleet shift (jmbp2)

Source `0cbd5e6`, JDK 17, `./gradlew --max-workers=1 -Dorg.gradle.jvmargs=-Xmx1536m`
on jmbp2 against `agent-emu-1` (API 36 Play image).

- Ported from iOS: the one-shot trial offer sheet (first dose, existing user,
  Patterns), the rating ask for reminders-off users with a pending blocked ask,
  and the medical disclaimer fixed above the onboarding trial CTA.
- Fixed: debug Test Store plans were filtered out, so the paid path could not
  run; History cards and switch tracks used Material's lavender containers.
- JVM: 56 tests (42 parity, 14 prompt policy), 0 failures. Lint: 0 errors.
- Connected: 21 tests (16 tracker smoke, 3 trial sheet, 2 platform boundary),
  0 failures. Baseline on the unchanged port: 16/16.
- Test Store purchase on device: cancel shows the retry message; "Test valid
  purchase" unlocks Pro ("Pro is active", Supply opens). No real charge.
- Network: offline, the membership step offers "See Pro plans" with no price
  and logging stays free; online, Test Store plans load with price and renewal
  terms. No Health Connect, location, storage, exact-alarm or ad-ID permission;
  backup disabled.
- Motion: a recorded pill-log task measured 1.8 fps and 109 ms median frame
  time on this host, which runs the AVD on one vCPU with a software GPU. That
  is a host limit, not an app measurement; native cadence is left to the Air
  motion task.
