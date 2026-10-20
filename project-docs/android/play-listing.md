# Simple GLP: Google Play listing, policy answers and products

Prepared 2026-10-20 from the Android build's actual behavior (code, merged
manifest and connected tests). Nothing here has been entered in Play Console.
No Play app record exists yet.

## Store listing

- **App name (30):** `Simple GLP: GLP-1 Dose Tracker`
- **Short description (80):** `Log a GLP-1 shot or daily pill in one tap. Wait timer, reminders and history.`
- **Category:** Medical. Tags: medication tracker, health.
- **Contact email:** jackwallner@gmail.com. Website: https://jackwallner.github.io/simpleglp/
- **Privacy policy:** https://jackwallner.github.io/simpleglp/privacy-policy.html
  (the Android section in `docs/privacy-policy.html` must be published first).

Full description (no prices, no em dashes, no brand-name claims):

```text
Simple GLP is a fast, private way to log your GLP-1 medication, whether it's a weekly shot or a daily pill. It's free, needs no account, and takes a minute to set up.

ONE TAP TO LOG
Open the app and tap once. Your dose is timestamped instantly. Add the dose, injection site, notes and symptoms afterward if you want, or log a dose you took earlier at the real time.

WEEKLY SHOTS
Pick your medication or add your own, then set your dose plan, weekday and time. Simple GLP marks each shot early, on time or late and reminds you before the next one.

DAILY PILLS
One tap logs today's pill and starts a wait timer you set to match your prescriber's instructions, with a notification when it's done. A daily reminder skips days you've already logged, and a streak and month view show how the routine is going.

FREE, WITH NO ACCOUNT
Logging, reminders, history, the pill wait timer and Patterns are free and stay free. No sign-up, no login, no email.

PRIVATE BY DESIGN
No accounts. No ads. No analytics. Your dose history stays on your device. Export or import a CSV whenever you like.

SIMPLE GLP PRO (OPTIONAL)
Pro adds the pill wait countdown as a Lock Screen notification, supply tracking with a refill heads-up before you run out, and missed-dose and timing alerts. Subscribe in the app and cancel anytime in Google Play.

NOT A MEDICAL DEVICE
Simple GLP records what you tell it you took and when. It does not provide medical advice, dosing instructions, diagnosis or treatment recommendations. Always follow your prescriber's guidance.
```

The iOS listing names specific medications. The Play copy leaves brand names
out on purpose for the account's first health app; adding them is Jack's call.
The iOS copy's widget, Apple Watch and Apple Health lines are omitted because
the Android build has none of them.

## Graphics

- 512 x 512 icon: export from `android/app/src/main/res/drawable/app_icon.png`.
- 1024 x 500 feature graphic: not yet made.
- Phone screenshots: raw debug captures from this run live in
  `project-docs/android/screenshots/`. They need the 1080 x 1920 composite
  (`~/mahj/scripts/play_screenshot_compositor.py`, on the Air) and status-bar
  demo mode before upload. Never use a Pro screen unlocked by a debug hook as a
  store image without labeling it as the Pro feature.

## App content answers

| Form | Answer | Evidence |
| --- | --- | --- |
| Privacy policy | URL above | Android section added in `docs/privacy-policy.html` |
| Ads | No ads | No ad SDK; `AD_ID` absent (connected test) |
| App access | All functionality available without login | No accounts |
| Content rating (IARC) | Reference/health utility; no violence, sexuality, gambling, user content, or location sharing. Digital purchases: yes | App behavior |
| Target audience | 18 and over | Prescription medication tracker |
| News app | No | |
| Government app | No | |
| Financial features | None | |
| Health apps declaration | Medication and treatment management (tracker). Not a medical device. No Health Connect access | `PlatformBoundaryTests` asserts no `android.permission.health.*` |
| Data safety | See below | |

### Data safety

Device-only data is not "collected". Dose history, plan, notes, symptoms and
imported health context never leave the device; `allowBackup` is off, so they
are not in Google cloud backup either (connected test).

The only off-device transfer is RevenueCat, and only in builds configured with
a Play SDK key:

| Data type | Collected | Shared | Purpose | Optional |
| --- | --- | --- | --- | --- |
| Financial info: Purchase history | Yes (RevenueCat) | No (service provider) | App functionality (entitlement) | Required for purchases |
| Device or other IDs: anonymous RevenueCat app user ID | Yes | No | App functionality | Required for purchases |

- Encrypted in transit: yes (HTTPS).
- Deletion: users can request deletion of the anonymous purchase record by
  email; local data is deleted in Settings > Delete all data or by uninstalling.
- Check RevenueCat's current Play Data safety guide when filling the form in
  case it lists more fields for the installed SDK version (10.23.2).

## Products (create in Play, then map in RevenueCat)

RevenueCat project `proja722b48d`, Play app `app3610516bb2`, entitlement
`GLP Pro`, offering `default` with the same `$rc_monthly`, `$rc_annual` and
`$rc_lifetime` packages as iOS.

| Play product | Type | Base plan / offer | RevenueCat product ID |
| --- | --- | --- | --- |
| `com.jackwallner.glp.pro.monthly` | Subscription | base plan `monthly` (P1M, auto-renewing) + offer `free-trial` (P1W free, new customers) | `com.jackwallner.glp.pro.monthly:monthly` |
| `com.jackwallner.glp.pro.yearly` | Subscription | base plan `yearly` (P1Y, auto-renewing) + offer `free-trial` (P1W free, new customers) | `com.jackwallner.glp.pro.yearly:yearly` |
| `com.jackwallner.glp.pro.lifetime` | One-time product | none | `com.jackwallner.glp.pro.lifetime` |

Prices: copy the live App Store Connect USD base prices (the StoreKit test
config lists 9.99 / 39.99 / 89.99, which may not match production) and review
Play's generated local prices against the iOS PPP plan before activating. The
app never hardcodes a price; the paywall and trial sheet read RevenueCat.

## Remaining Play Console steps (need Jack's Chrome)

1. Create the app record `com.jackwallner.glp` (Simple GLP, app, free with
   in-app purchases) in the E3 Apps account.
2. Publish the Android privacy-policy section.
3. Fill App content using the table above, including the Health apps
   declaration.
4. Upload the signed AAB (Air release worker) to internal testing; add license
   testers.
5. Create and activate the three products above; grant the RevenueCat service
   account access to the new app; import products in RevenueCat and attach them
   to `GLP Pro` and the `default` offering packages.
6. License-tester purchase and restore on the internal track; confirm the trial
   sheet shows the Play trial and the entitlement in RevenueCat.
7. Review the pre-launch report, then production with managed publishing off,
   paced after the account's previous production review completes.
