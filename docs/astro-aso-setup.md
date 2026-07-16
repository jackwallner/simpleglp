# Astro ASO setup — Simple GLP (US, prelaunch)

> **Repeat this setup:** follow [Astro setup process](~/ios/aso/astro-setup-process.md) and say **"go"**.

Last synced: **2026-05-26** (50-locale **native** metadata + ASC draft upload)

**Localization:** [`localization-aso.md`](localization-aso.md) · [Phase B report](archive/aso/2026-05/astro-phase-b-report.md)

**Strategy doc:** [`aso-keyword-strategy.md`](aso-keyword-strategy.md) — attack/siege mix, ASC copy, screenshots.

## App

| Field | Value |
|-------|-------|
| Astro app name | **SimpleGLP** (temporary, prelaunch) |
| Astro app ID | `105` |
| App Store Connect name | Easy GLP - Simple GLP1 Tracker |
| Bundle ID | `com.jackwallner.glp` |
| ASC internal ID | `6770137909` |
| Primary store in Astro | `us` |
| App Store status | **Prepare for Submission** (not live yet — rankings will show 1000 until indexed) |

## Live ASC metadata (en-US, pulled via fastlane)

| Field | Value |
|-------|-------|
| **Name** | `Easy GLP - GLP-1 Shot Tracker` (29/30) |
| **Subtitle** | `One-Tap Widget · Watch Log` (28/30) |
| **Keywords** | `ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose` (96/100, comma-only) |

Source files: `fastlane/metadata/en-US/{name,subtitle,keywords}.txt`

Backup before pull: `fastlane/metadata.bak.20260525-082114/`

## Astro tags

| Tag | Color | Use for |
|-----|-------|---------|
| `asc-field` | blue | Tokens from the 100-char ASC keyword field |
| `priority` | red | Terms to optimize first once live |
| `phrase` | green | Multi-word search phrases |

Tagging via MCP is slow; tag high-priority terms in the Astro UI when convenient.

## Keywords in Astro (~116 tracked, 107 curated)

- **Curated list:** `scripts/astro-keywords-us.json`
- **Buckets:** `scripts/astro-keyword-buckets.json` (attack / siege / mid / ignore)

**Attack highlights (pop/diff):** `peptide tracker` 40/21, `shotsy` 55/38, `glp1 tracker` 30/51, `dose log` 5/7, brand terms Mounjaro/Zepbound/Ozempic.

**Siege (field only):** `health`, `weight loss`, `weight loss tracker`, `tracker`, `weight`.

## Rankings (expected prelaunch)

All keywords currently rank **#1000** — normal before the app is live on the App Store. Re-check **7–14 days after** first public release.

## Clean up in Astro UI (optional)

During automated setup, extra temporary apps may have been created while matching ASC name:

- **Easy GLP - Simple GLP1 Tracker** (app `109`) — duplicate; safe to delete if you only use **SimpleGLP**
- **Temporary App 110** — stray duplicate from MCP tests

**Prune pass (2026-05-26):** If US still shows junk (`health app`, `weight loss tracker`, `headache tracker`, `calorie counter`), delete manually in Astro — MCP `remove_keywords` returned HTTP 500 for US batch.

Astro MCP has no delete-app tool — remove stray apps in the Astro app.

## When the app goes live

1. In Astro, add or link the **public App Store app** (track ID from iTunes once listed).
2. Update `scripts/.astro-app.json` with the new numeric `appId`.
3. Re-run `./scripts/sync-astro-keywords.sh` if needed.
4. Remove the temporary **SimpleGLP** entry if Astro duplicates tracking.

## Weekly routine (~10 min)

1. Open Astro → **SimpleGLP** → US
2. Sort by **rank change** — note anything that moved up with popularity ≥ 5
3. Anything stuck at **1000** for 2+ weeks after launch → deprioritize or remove
4. After ASC metadata changes, wait 7–14 days then re-check
5. Compare rank trends vs. Shotsy, MeAgain, Glapp (top competitors in category)

## Re-sync after ASC edits

```bash
./scripts/pull-appstore-metadata.sh   # refresh fastlane/metadata (uses --app_version 1.0)
# Edit scripts/astro-keywords-us.json if you change the phrase list
./scripts/sync-astro-keywords.sh    # push new terms into Astro (uses scripts/.astro-app.json)
```

## Suggested ASC experiments (post-launch)

- **Subtitle** — currently empty; try e.g. `Private one-tap GLP-1 shot log` (30 chars)
- **Keywords** — test `widget,watch,healthkit,dose,reminder,private` swaps once you have rank data
- **Name** — ASC uses "Easy GLP - Simple GLP1 Tracker"; align marketing site if you rebrand

## MCP / AI prompts (Astro must be running)

- "List SimpleGLP US keywords where rank improved and popularity ≥ 10"
- "Which GLP-1 tracker keywords rank under 100 for competitor apps?"
- "Suggest 10 new phrases from our description that we are not tracking yet"
