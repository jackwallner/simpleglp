# Astro global ASO — Phase B report (Simple GLP)

**Date:** 2026-05-26  
**App:** SimpleGLP (Astro `105`) · ASC **Easy GLP - Simple GLP1 Tracker** · `com.jackwallner.glp`  
**Pipeline:** `astro-global-aso-go-2026.md` + **true multi-language** pass

---

## Backups

| Path | When |
|------|------|
| `fastlane/metadata.bak.20260525-190714/` | ASC pull (start) |
| `fastlane/metadata.bak.pre-upload-20260525-190926/` | Pre first optimized upload |
| `fastlane/metadata.bak.pre-upload-*` (latest) | Pre localized upload |

---

## True multi-language (50 ASC locales)

| Field | Status |
|-------|--------|
| `name.txt` | Native per locale (≤30 chars) |
| `subtitle.txt` | Native per locale (≤30 chars) |
| `keywords.txt` | Native + brand terms; deduped vs name/subtitle (≤100) |
| `description.txt` | **Full native body** (not English seed) |

**Source:** `scripts/locale_packs/` → `scripts/aso-localize-all-locales.py`  
**Report:** `scripts/aso-localize-report.json`

### Sample (before → after description)

| Locale | Before | After |
|--------|--------|-------|
| de-DE | English ASC seed | German full description |
| fr-FR | English | French |
| ja | English | Japanese |
| ar-SA | English | Arabic |
| hi | English | Hindi |
| bn-BD | Hindi (shared) | **Bengali** |
| te-IN | Tamil (wrong) | **Telugu** |
| ur-PK | Hindi (shared) | **Urdu** |

### Indian subcontinent (11 locales)

Each has a **unique native-script** full description in `scripts/locale_packs/india.py` (not shared Hindi).

### en-US highlights

| Field | Value | Len |
|-------|-------|----:|
| Name | Easy GLP - GLP-1 Shot Tracker | 29 |
| Subtitle | One-Tap Widget · Watch Log | 28 |
| Keywords | ozempic,wegovy,mounjaro,zepbound,semaglutide,tirzepatide,peptide,reminder,injection,private,dose | 96 |

---

## ASC upload (draft **1.0**)

| Method | Result |
|--------|--------|
| `asc-upload-metadata.sh` (API) | **Success** — all **50** locales: keywords + **native description** |
| `upload-appstore-metadata.sh` (deliver) | **Success** (2026-05-26) — all 50 version locales + appInfo after review phone restored |

**State:** `scripts/.asc-state.json` → `draftVersion: 1.0`, **50** version + appInfo localizations.

**User action:** Attach a build in ASC and submit **1.0** to ship localized metadata.

---

## Astro stores (91)

| Item | Status |
|------|--------|
| `astro-sync-all-stores.sh` | **Done** — 91/91 (`_summary.json` `storeCount: 91`) |
| `astro-prune-all-stores.sh` | **Done** (2026-05-26) — most stores clean; **US** remove hit MCP HTTP 500 (retry in Astro UI: drop `health app`, `weight loss tracker`, `headache tracker`, etc.) |
| `astro-tier1-second-pass.py` | **Run** — no new suggestions (prelaunch / MCP 500 on some stores) |

Logs: `scripts/astro-prune-all-stores.log`, `scripts/astro-tier1-second-pass.log`

Re-sync after ASC copy changes:

```bash
./scripts/astro-sync-all-stores.sh
```

---

## go refine

Calendar **14 days after** first live release → re-pull → rank-based tune → upload again.
