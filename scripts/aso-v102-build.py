#!/usr/bin/env python3
"""Build v1.0.2 metadata: capture-surface subtitle + drug-indexing keywords, per locale.

Strategy (see aso-plan.md + 2026-06-29 per-region SERP research):
- Name: keep existing localized "Simple GLP / GLP-1 Shot Tracker" (untouched).
- Subtitle: capture-surface wedge ("GLP1 <shot> · Widget & Watch"), localized. This is
  conversion copy; no market is won on a drug-name subtitle (every competitor stuffs them).
- Keywords: reuse the proven native pool, but drop `peptide` (wrong SERP) and let all four
  drug brands index now that they no longer sit in the subtitle (dedup previously ate them).
- Description / promotional_text: untouched.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
sys.path.insert(0, str(Path(__file__).parent))

from aso_apply_locale_optimizations import (  # noqa: E402
    KEYWORDS,
    dedupe_keywords,
    trim_keywords,
    trim_subtitle,
)

# Capture-surface subtitle per locale. Pattern: "GLP1 <shot/injection> · Widget & Watch".
# Drug names deliberately NOT here (they index in keywords); subtitle sells the wedge.
SUB: dict[str, str] = {
    "en-US": "GLP1 Shot · Widget & Watch",
    "en-GB": "GLP1 Jab · Widget & Watch",
    "en-AU": "GLP1 Jab · Widget & Watch",
    "en-CA": "GLP1 Shot · Widget & Watch",
    "de-DE": "GLP1 Spritze · Widget & Watch",
    "fr-FR": "Injection GLP1 · Widget+Watch",
    "fr-CA": "Injection GLP1 · Widget+Watch",
    "es-ES": "Inyección GLP1 · Widget+Watch",
    "es-MX": "Inyección GLP1 · Widget+Watch",
    "ca": "Injecció GLP1 · Widget+Watch",
    "it": "Iniezione GLP1 · Widget+Watch",
    "pt-BR": "Aplicação GLP1 · Widget+Watch",
    "pt-PT": "Injeção GLP1 · Widget & Watch",
    "nl-NL": "GLP1 Prik · Widget & Watch",
    "pl": "Zastrzyk GLP1 · Widget+Watch",
    "sv": "GLP1 Spruta · Widget & Watch",
    "da": "GLP1 Stik · Widget & Watch",
    "no": "GLP1 Sprøyte · Widget+Watch",
    "fi": "GLP1 Pisto · Widget & Watch",
    "cs": "GLP1 Injekce · Widget+Watch",
    "sk": "GLP1 Injekcia · Widget+Watch",
    "hu": "GLP1 Injekció · Widget+Watch",
    "ro": "Injecție GLP1 · Widget+Watch",
    "hr": "GLP1 Injekcija · Widget",
    "el": "Ένεση GLP1 · Widget & Watch",
    "tr": "GLP1 İğne · Widget & Watch",
    "ru": "GLP1 Укол · Виджет и Watch",
    "uk": "GLP1 Укол · Віджет і Watch",
    "ja": "GLP1注射 · ウィジェットとWatch",
    "ko": "GLP1 주사 · 위젯과 워치",
    "zh-Hans": "GLP1注射 · 小组件与手表",
    "zh-Hant": "GLP1注射 · 小工具與手錶",
    "ar-SA": "حقن GLP1 · ودجت وساعة",
    "he": "זריקת GLP1 · ווידג'ט ושעון",
    "hi": "GLP1 इंजेक्शन · विजेट और वॉच",
    "th": "ฉีด GLP1 · วิดเจ็ตและ Watch",
    "vi": "Tiêm GLP1 · Widget & Watch",
    "id": "Suntik GLP1 · Widget & Watch",
    "ms": "Suntik GLP1 · Widget & Watch",
    "bn-BD": "GLP1 ইনজেকশন · উইজেট ও Watch",
    "gu-IN": "GLP1 ઇન્જેક્શન · વિજેટ",
    "kn-IN": "GLP1 ಚುಚ್ಚುಮದ್ದು · ವಿಜೆಟ್",
    "ml-IN": "GLP1 കുത്തിവയ്പ്പ് · വിജറ്റ്",
    "mr-IN": "GLP1 इंजेक्शन · विजेट, वॉच",
    "or-IN": "GLP1 ଇଞ୍ଜେକ୍ସନ · ୱିଜେଟ",
    "pa-IN": "GLP1 ਟੀਕਾ · ਵਿਜੇਟ ਤੇ ਵਾਚ",
    "ta-IN": "GLP1 ஊசி · விட்ஜெட், வாட்ச்",
    "te-IN": "GLP1 ఇంజెక్షన్ · విడ్జెట్",
    "ur-PK": "GLP1 انجکشن · وجیٹ اور واچ",
    "sl-SI": "GLP1 Injekcija · Widget",
}

# Standalone "peptide" tokens to drop from the keyword pool (wrong SERP cluster).
PEPTIDE = {
    "peptide", "peptid", "péptido", "peptídeo", "pèptid", "peptida", "peptidi",
    "peptyd", "πεπτιδ", "пептид", "ペプチド", "펩타이드", "肽", "ببتيد", "פפטיד",
    "पेप्टाइड", "เปปไทด์", "পেপটাইড", "પેપટાઇડ", "ಪೆಪ್ಟೈಡ್", "പെപ്റ്റൈഡ്",
    "ପେପଟାଇଡ୍", "ਪੇਪਟਾਈਡ", "பெப்டைடு", "పెప్టైడ్", "پیپٹائڈ",
}


def drop_peptide(csv: str) -> str:
    return ",".join(t for t in csv.split(",") if t.strip().lower() not in PEPTIDE)


def dedupe_against_subtitle(csv: str, subtitle: str) -> str:
    """Unicode-aware dedup: drop keyword tokens already present in the subtitle.

    The repo's dedupe_keywords only matches [a-z0-9]+, so non-Latin scripts
    (Arabic, CJK, Indic, Thai, Greek, Cyrillic) leak duplicates. Here we drop any
    keyword token that appears as a substring of the subtitle (case-insensitive).
    """
    sub = subtitle.lower()
    kept = []
    for raw in csv.split(","):
        t = raw.strip()
        if t and t.lower() not in sub:
            kept.append(t)
    return ",".join(kept)


def main() -> None:
    report: dict = {}
    skipped = []
    for loc_dir in sorted(p for p in META.iterdir() if p.is_dir() and p.name != "review_information"):
        loc = loc_dir.name
        name = (loc_dir / "name.txt").read_text(encoding="utf-8").strip() if (loc_dir / "name.txt").exists() else ""
        if loc not in SUB:
            skipped.append(loc)
            continue
        sub = trim_subtitle(SUB[loc])
        raw_kw = drop_peptide(KEYWORDS.get(loc, ""))
        kw = dedupe_against_subtitle(dedupe_keywords(name, sub, raw_kw), f"{name} {sub}")
        kw = trim_keywords(kw)
        old_sub = (loc_dir / "subtitle.txt").read_text(encoding="utf-8").strip() if (loc_dir / "subtitle.txt").exists() else ""
        old_kw = (loc_dir / "keywords.txt").read_text(encoding="utf-8").strip() if (loc_dir / "keywords.txt").exists() else ""
        (loc_dir / "subtitle.txt").write_text(sub + "\n", encoding="utf-8")
        (loc_dir / "keywords.txt").write_text(kw + "\n", encoding="utf-8")
        report[loc] = {
            "name": name,
            "subtitle": {"old": old_sub, "new": sub, "len": len(sub)},
            "keywords": {"old": old_kw, "new": kw, "len": len(kw)},
        }
    out = ROOT / "scripts" / "aso-v102-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Built {len(report)} locales -> {out}")
    if skipped:
        print(f"SKIPPED (no SUB entry): {', '.join(skipped)}")


if __name__ == "__main__":
    main()
