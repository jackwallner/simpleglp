# Localization & ASO — Simple GLP

## Native copy (50 ASC locales)

All App Store metadata locales use **native** `name`, `subtitle`, `keywords`, and `description` — not English seeded copies.

### Indian subcontinent (11 locales)

Each locale has its **own script** for the full description (not shared Hindi):

| Locale | Script |
|--------|--------|
| hi | Hindi (Devanagari) |
| bn-BD | Bengali |
| ta-IN | Tamil |
| te-IN | Telugu |
| mr-IN | Marathi |
| gu-IN | Gujarati |
| kn-IN | Kannada |
| ml-IN | Malayalam |
| pa-IN | Punjabi (Gurmukhi) |
| or-IN | Odia |
| ur-PK | Urdu |

Source: `scripts/locale_packs/india.py`

| Source | Purpose |
|--------|---------|
| `scripts/locale_packs/` | Per-region translation packs |
| `scripts/aso-localize-all-locales.py` | Applies packs → `fastlane/metadata/<locale>/` |
| `scripts/aso-localize-report.json` | Char counts after apply |

Re-apply after editing packs:

```bash
python3 scripts/aso-localize-all-locales.py
```

## Backups

| Path | When |
|------|------|
| `fastlane/metadata.bak.20260525-190714/` | Initial ASC pull |
| `fastlane/metadata.bak.pre-upload-20260525-190926/` | Pre first upload |
| `fastlane/metadata.bak.pre-upload-*` | Latest pre-upload before localized push |

Restore:

```bash
./scripts/restore-appstore-metadata.sh --list
./scripts/restore-appstore-metadata.sh fastlane/metadata.bak.<timestamp>
```

## Upload localized metadata

```bash
source ~/.baseball_credentials
./scripts/asc-finish-missed.sh
```

API pass updates **keywords + description** for all locales; deliver (2.234+) updates **appInfo** name/subtitle when review contact fields are valid.
