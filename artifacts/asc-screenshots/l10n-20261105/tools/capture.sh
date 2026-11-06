#!/usr/bin/env bash
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(git -C "$KIT" rev-parse --show-toplevel)"
cd "$ROOT"

declare -a requested=("$@")
if ((${#requested[@]})); then
  declare -a locales=("${requested[@]}")
else
  declare -a locales=("en-US")
  while IFS= read -r locale; do locales+=("$locale"); done < <(
    python3 - "$KIT/app.json" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    print(item["store_locale"])
PY
  )
fi

python3 - "$KIT/app.json" "$ROOT/SimpleGLPUITests/capture-locales.json" "${locales[@]}" <<'PY'
import json, os, sys
packet = json.load(open(sys.argv[1], encoding="utf-8"))
requested = sys.argv[3:]
all_scenes = [
    "01-know-when-your-next-shot-is-due",
    "02-log-a-shot-in-one-tap",
    "03-review-a-recorded-shot",
    "04-see-how-your-timing-holds",
    "05-set-a-schedule-that-fits",
    "06-confirm-a-completed-shot",
    "07-tune-proactive-alerts",
]
requested_scenes = set(os.environ.get("GH_SIM_SCENES", "").split())
scenes = [scene for scene in all_scenes if not requested_scenes or scene in requested_scenes]
if requested_scenes - set(all_scenes):
    raise SystemExit(f"unknown screenshot scenes: {sorted(requested_scenes - set(all_scenes))}")

locales = []
for locale in requested:
    if locale == "en-US":
        locales.append({
            "storeLocale": "en-US",
            "language": "en",
            "appleLanguages": "(en)",
            "appleLocale": "en_US",
        })
        continue
    target = next((item for item in packet["targets"] if item["store_locale"] == locale), None)
    if target is None:
        raise SystemExit(f"unknown target locale: {locale}")
    locales.append({
        "storeLocale": target["store_locale"],
        "language": target["lang"],
        "appleLanguages": target["apple_languages"],
        "appleLocale": target["apple_locale"],
    })
if not locales:
    raise SystemExit("at least one locale is required")
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    json.dump({"locales": locales, "scenes": scenes}, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
PY

run_id="${GH_SIM_RUN_ID:-}"
if [[ -z "$run_id" ]]; then
  id_file="$(mktemp)"
  trap 'rm -f "$id_file"' EXIT
  gh-sim test --scheme SimpleGLPUITests \
    --only SimpleGLPUITests/LocalizedStoreScreenshotTests/testLocalizedStoreScreenshots \
    --device "iPhone 17 Pro Max" --id-file "$id_file"
  run_id="$(cat "$id_file")"
fi
attachments="$HOME/.gh-sim/results/$run_id/attachments"

python3 - "$KIT" "$attachments" "${locales[@]}" <<'PY'
import json, shutil, sys
from pathlib import Path

kit = Path(sys.argv[1])
attachments = Path(sys.argv[2])
locales = sys.argv[3:]
capture = json.loads((kit.parent.parent.parent / "SimpleGLPUITests/capture-locales.json").read_text(encoding="utf-8"))
selected_scenes = set(capture["scenes"])
frames = [
    "01-know-when-your-next-shot-is-due.png",
    "02-log-a-shot-in-one-tap.png",
    "03-review-a-recorded-shot.png",
    "04-see-how-your-timing-holds.png",
    "05-set-a-schedule-that-fits.png",
    "06-confirm-a-completed-shot.png",
    "07-tune-proactive-alerts.png",
]
manifest = json.loads((attachments / "manifest.json").read_text(encoding="utf-8"))
items = [attachment for test in manifest for attachment in test["attachments"]]
for locale in locales:
    destination = kit / "raw" / locale / "phone"
    destination.mkdir(parents=True, exist_ok=True)
    for frame in frames:
        scene = Path(frame).stem
        if scene not in selected_scenes:
            continue
        matches = [
            item for item in items
            if item["suggestedHumanReadableName"].startswith(f"{locale}__{scene}_")
        ]
        if len(matches) != 1:
            raise SystemExit(f"expected one attachment for {locale}__{scene}, found {len(matches)}")
        shutil.copyfile(attachments / matches[0]["exportedFileName"], destination / frame)
print(f"captured {len(locales) * len(selected_scenes)} phone screens from gh-sim attachments")
PY
