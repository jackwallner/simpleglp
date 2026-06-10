#!/usr/bin/env python3
"""Validate fastlane/metadata against ASC field limits and hygiene rules.

Checks every locale for: empty required fields, character-limit overruns
(name/subtitle <=30, keywords <=100, promotional_text <=170, description <=4000,
release_notes <=4000), and keyword characters wasted on words already indexed
from the name or subtitle.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "fastlane" / "metadata"
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}
REQUIRED = ["name.txt", "subtitle.txt", "keywords.txt", "description.txt",
            "promotional_text.txt", "release_notes.txt"]

failures = 0
warnings = 0

for locale_dir in sorted(p for p in ROOT.iterdir() if p.is_dir() and p.name != "review_information"):
    locale = locale_dir.name
    values = {}
    for fname in REQUIRED:
        f = locale_dir / fname
        text = f.read_text(encoding="utf-8").strip() if f.exists() else ""
        values[fname] = text
        if not text:
            print(f"EMPTY  {locale}/{fname}")
            failures += 1
            continue
        limit = LIMITS[fname]
        if len(text) > limit:
            print(f"OVER   {locale}/{fname}: {len(text)} > {limit}: {text[:80]!r}")
            failures += 1

    # Keyword duplication vs name/subtitle (token-level, only for scripts with spaces).
    kw = values.get("keywords.txt", "")
    if kw:
        title_tokens = set(re.split(r"[\s,·\-–—:|/&+]+", (values["name.txt"] + " " + values["subtitle.txt"]).lower()))
        title_tokens.discard("")
        for term in kw.split(","):
            for tok in re.split(r"[\s\-]+", term.strip().lower()):
                if tok and tok in title_tokens and len(tok) > 2:
                    print(f"DUP    {locale}/keywords.txt: token {tok!r} (in '{term.strip()}') already in name/subtitle")
                    warnings += 1

print(f"\n{failures} failures, {warnings} duplicate-token warnings across "
      f"{len([p for p in ROOT.iterdir() if p.is_dir()]) - 1} locales")
sys.exit(1 if failures else 0)
