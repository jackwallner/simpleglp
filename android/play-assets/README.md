# Simple GLP: Google Play listing text

Title, short and full description per locale live in `metadata/android/<locale>/`
(fastlane supply layout). `en-US` mirrors the live Play listing, except the
"Made for Android" line, which drops Apple product names to follow the house rule.

Locales (50): en-US (default), en-GB/AU/CA/IN, de-DE, fr-FR/CA, es-ES/419/US,
pt-BR/PT, it-IT, nl-NL, sv-SE, no-NO, da-DK, fi-FI, pl-PL, cs-CZ, sk, sl, hr,
hu-HU, ro, el-GR, tr-TR, ru-RU, uk, ar, iw-IL, hi-IN, bn-BD, mr-IN, ta-IN,
te-IN, kn-IN, ml-IN, id, ms, ms-MY, th, vi, ja-JP, ko-KR, zh-CN/TW/HK, ca.

- Search terms come from the matching iOS `fastlane/metadata/<locale>` name,
  subtitle and keywords. Titles keep "Simple GLP" plus the local GLP-1 log or
  tracker phrase; short descriptions open with it.
- Drug brand names stay out of Play copy (trademark risk); the generic names
  semaglutide and tirzepatide appear in the descriptions.
- Every non-English description says the app itself is in English (the Android
  app is not localized).
- No prices, no em dashes, no Apple wording, no promo words in titles, no
  treat/cure/diagnose claims. A schedule, reminder or countdown is never a
  dosing recommendation.

Check with `python3 scripts/validate-play-listing.py` (exit 0 = all 50 pass).
Graphics stay in the root `play-assets/` folder and are en-US only.
