#!/usr/bin/env bash
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(git -C "$KIT" rev-parse --show-toplevel)"
cd "$ROOT"

declare -a locales=("$@")
if ((${#locales[@]} == 0)); then
  while IFS= read -r locale; do locales+=("$locale"); done < <(
    python3 - "$KIT/app.json" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    print(item["store_locale"])
PY
  )
fi

for locale in "${locales[@]}"; do
  lang="$(python3 - "$KIT/app.json" "$locale" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    if item["store_locale"] == sys.argv[2]:
        print(item["lang"])
        break
PY
  )"
  [[ -n "$lang" ]] || { echo "unknown target locale: $locale" >&2; exit 2; }

  rm -f "$KIT/$locale/phone/"*.png
  python3 "$KIT/tools/reskin.py" \
    --config "$KIT/frames.json" --raw-root "$KIT/raw" --headers "$KIT/copy/headers.json" \
    --locale "$locale" --out "$KIT"
  python3 "$KIT/tools/gate.py" \
    --config "$KIT/frames.json" --raw-root "$KIT/raw" --headers "$KIT/copy/headers.json" \
    --out-root "$KIT" --locale "$locale" \
    --catalog "$ROOT/SharedGLP/Localizable.xcstrings" --lang "$lang"
  python3 "$KIT/tools/sheet.py" \
    --config "$KIT/frames.json" --locale "$locale" --out-root "$KIT" --base-label en

  destination="$ROOT/fastlane/screenshots/$locale"
  mkdir -p "$destination"
  for frame in "$KIT/$locale/phone/"*.png; do
    [[ -f "$frame" ]] || { echo "missing output frame for $locale" >&2; exit 1; }
    cp "$frame" "$destination/$(basename "$frame")"
  done
done
