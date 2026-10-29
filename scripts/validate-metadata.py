#!/usr/bin/env python3
"""Validate App Store metadata limits, whitespace, and keyword hygiene."""

import argparse
import re
import sys
import unicodedata
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
REQUIRED = tuple(LIMITS)
SEARCH_FIELDS = (
    "name.txt",
    "subtitle.txt",
    "keywords.txt",
    "promotional_text.txt",
    "description.txt",
)
TOKEN_PATTERN = re.compile(r"[^\W_]+", re.UNICODE)
HAN_PATTERN = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff]")


def normalize(token: str) -> str:
    decomposed = unicodedata.normalize("NFKD", token.casefold())
    return "".join(char for char in decomposed if not unicodedata.combining(char))


def read_value(path: Path) -> str:
    return path.read_text(encoding="utf-8").rstrip("\n") if path.exists() else ""


def validate_locale(locale_dir: Path, strict: bool) -> tuple[int, int]:
    failures = 0
    warnings = 0
    locale = locale_dir.name
    values: dict[str, str] = {}

    for filename in REQUIRED:
        path = locale_dir / filename
        value = read_value(path)
        values[filename] = value
        if not value:
            print(f"EMPTY  {locale}/{filename}")
            failures += 1
            continue

        if len(value) > LIMITS[filename]:
            print(f"OVER   {locale}/{filename}: {len(value)} > {LIMITS[filename]}")
            failures += 1

        if strict and value != value.strip():
            print(f"SPACE  {locale}/{filename}: leading or trailing whitespace")
            failures += 1

        if strict and filename in SEARCH_FIELDS and "\u2014" in value:
            print(f"DASH   {locale}/{filename}: em dash")
            failures += 1

    keywords = values.get("keywords.txt", "")
    if not keywords:
        return failures, warnings

    title = f"{values.get('name.txt', '')} {values.get('subtitle.txt', '')}"
    title_tokens = {normalize(token) for token in TOKEN_PATTERN.findall(title)}
    normalized_title = normalize(title)
    seen: set[str] = set()

    for entry in keywords.split(","):
        token = entry.strip()
        if not token:
            print(f"EMPTY  {locale}/keywords.txt: empty comma-separated keyword")
            failures += 1
            continue

        if strict and (entry != token or any(char.isspace() for char in token)):
            print(f"SPACE  {locale}/keywords.txt: keyword entries must have no spaces")
            failures += 1

        tokens = TOKEN_PATTERN.findall(token)
        if not tokens:
            print(f"EMPTY  {locale}/keywords.txt: invalid keyword {token!r}")
            failures += 1
            continue

        for raw_token in tokens:
            keyword_token = normalize(raw_token)
            if keyword_token in seen:
                print(f"DUP    {locale}/keywords.txt: repeated token {raw_token!r}")
                if strict:
                    failures += 1
                else:
                    warnings += 1
            seen.add(keyword_token)

            if keyword_token in title_tokens and len(keyword_token) > 2:
                print(f"DUP    {locale}/keywords.txt: {raw_token!r} already in name/subtitle")
                if strict:
                    failures += 1
                else:
                    warnings += 1
            elif strict and HAN_PATTERN.search(raw_token) and keyword_token in normalized_title:
                print(f"DUP    {locale}/keywords.txt: {raw_token!r} overlaps name/subtitle")
                failures += 1

    return failures, warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--locales",
        nargs="+",
        metavar="LOCALE",
        help="validate these locales strictly instead of checking every locale",
    )
    args = parser.parse_args()

    all_locale_dirs = sorted(
        path for path in ROOT.iterdir() if path.is_dir() and path.name != "review_information"
    )
    if args.locales:
        requested = set(args.locales)
        known = {path.name: path for path in all_locale_dirs}
        missing = sorted(requested - known.keys())
        if missing:
            print(f"Unknown locale(s): {', '.join(missing)}")
            return 2
        locale_dirs = [known[locale] for locale in sorted(requested)]
        strict = True
    else:
        locale_dirs = all_locale_dirs
        strict = False

    failures = 0
    warnings = 0
    for locale_dir in locale_dirs:
        locale_failures, locale_warnings = validate_locale(locale_dir, strict)
        failures += locale_failures
        warnings += locale_warnings

    print(f"\n{failures} failures, {warnings} duplicate-token warnings across {len(locale_dirs)} locales")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
