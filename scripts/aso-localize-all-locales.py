#!/usr/bin/env python3
"""Write native name, subtitle, keywords, and description for every fastlane locale."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
META = ROOT / "fastlane/metadata"
sys.path.insert(0, str(Path(__file__).parent))

from locale_packs import ALL_PACKS  # noqa: E402
from aso_apply_locale_optimizations import (  # noqa: E402
    KEYWORDS,
    dedupe_keywords,
    trim_keywords,
    trim_name,
    trim_subtitle,
)


def indexed_terms(name: str, subtitle: str) -> set[str]:
    text = f"{name} {subtitle}".lower()
    terms: set[str] = set()
    for w in re.findall(r"[a-z0-9]+", text, flags=re.I):
        if len(w) >= 2:
            terms.add(w)
    return terms


def main() -> None:
    report: dict = {}
    for loc, pack in sorted(ALL_PACKS.items()):
        loc_dir = META / loc
        if not loc_dir.is_dir():
            continue
        name = trim_name(pack["name"])
        subtitle = trim_subtitle(pack["subtitle"])
        raw_kw = pack.get("keywords") or KEYWORDS.get(loc, "")
        keywords = trim_keywords(dedupe_keywords(name, subtitle, raw_kw))
        description = pack["description"].strip() + "\n"

        (loc_dir / "name.txt").write_text(name + "\n", encoding="utf-8")
        (loc_dir / "subtitle.txt").write_text(subtitle + "\n", encoding="utf-8")
        (loc_dir / "keywords.txt").write_text(keywords + "\n", encoding="utf-8")
        (loc_dir / "description.txt").write_text(description, encoding="utf-8")

        report[loc] = {
            "name_len": len(name),
            "subtitle_len": len(subtitle),
            "keywords_len": len(keywords),
            "description_chars": len(description),
        }

    out = ROOT / "scripts" / "aso-localize-report.json"
    out.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Localized {len(report)} locales → {out}")

    over = []
    for loc, r in report.items():
        if r["name_len"] > 30:
            over.append(f"{loc}/name")
        if r["subtitle_len"] > 30:
            over.append(f"{loc}/subtitle")
        if r["keywords_len"] > 100:
            over.append(f"{loc}/keywords")
    if over:
        print("OVER LIMIT:", ", ".join(over))
        sys.exit(1)


if __name__ == "__main__":
    main()
