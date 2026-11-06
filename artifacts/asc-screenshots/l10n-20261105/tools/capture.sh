#!/usr/bin/env bash
set -euo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(git -C "$KIT" rev-parse --show-toplevel)"
cd "$ROOT"

declare -a locales=("$@")
if ((${#locales[@]} == 0)); then
  locales=("en-US")
  while IFS= read -r locale; do locales+=("$locale"); done < <(
    python3 - "$KIT/app.json" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding="utf-8"))["targets"]:
    print(item["store_locale"])
PY
  )
fi

plan_file="$(mktemp)"
id_file="$(mktemp)"
trap 'rm -f "$plan_file" "$id_file"' EXIT

python3 - "$KIT/app.json" "$plan_file" "${locales[@]}" <<'PY'
import json, os, sys

packet = json.load(open(sys.argv[1], encoding="utf-8"))
all_scenes = [
    "01-know-when-your-next-shot-is-due",
    "02-log-a-shot-in-one-tap",
    "03-review-a-recorded-shot",
    "04-see-how-your-timing-holds",
    "05-set-a-schedule-that-fits",
    "06-confirm-a-completed-shot",
    "07-tune-proactive-alerts",
]
scene_arguments = {
    "01-know-when-your-next-shot-is-due": ["-GLPDuoScreen", "oneTap"],
    "02-log-a-shot-in-one-tap": ["-GLPDuoScreen", "history"],
    "03-review-a-recorded-shot": ["-GLPDuoScreen", "history", "-GLPScreenshotDetails"],
    "04-see-how-your-timing-holds": ["-GLPDuoScreen", "patterns", "-GLPScreenshotPro"],
    "05-set-a-schedule-that-fits": ["-GLPScreenshotPlan"],
    "06-confirm-a-completed-shot": ["-GLPScreenshotConfirmation"],
    "07-tune-proactive-alerts": ["-GLPScreenshotAlerts", "-GLPScreenshotPro"],
}
requested_scenes = set(os.environ.get("GH_SIM_SCENES", "").split())
scenes = [scene for scene in all_scenes if not requested_scenes or scene in requested_scenes]
if requested_scenes - set(all_scenes):
    raise SystemExit(f"unknown screenshot scenes: {sorted(requested_scenes - set(all_scenes))}")

locale_data = []
for name in sys.argv[3:]:
    if name == "en-US":
        locale_data.append({"store_locale": name, "apple_languages": "(en)", "apple_locale": "en_US"})
        continue
    target = next((item for item in packet["targets"] if item["store_locale"] == name), None)
    if target is None:
        raise SystemExit(f"unknown target locale: {name}")
    locale_data.append(target)
if not locale_data:
    raise SystemExit("at least one locale is required")

entries = []
raw_root = os.path.join(os.path.dirname(sys.argv[1]), "raw")
reuse = os.environ.get("GH_SIM_FORCE") not in {"1", "true"}
for locale in locale_data:
    for scene in scenes:
        destination = os.path.join(raw_root, locale["store_locale"], "phone", f"{scene}.png")
        if reuse and os.path.isfile(destination):
            continue
        args = [
            "-AppleLanguages",
            locale["apple_languages"],
            "-AppleLocale",
            locale["apple_locale"],
            *scene_arguments[scene],
        ]
        entries.append({"locale": locale["store_locale"], "scene": scene, "args": " ".join(args)})
with open(sys.argv[2], "w", encoding="utf-8") as stream:
    json.dump(entries, stream, ensure_ascii=False, indent=2)
    stream.write("\n")
print(f"queued {len(entries)} scenes; reused {len(locale_data) * len(scenes) - len(entries)} current raws")
PY

pending_count="$(python3 - "$plan_file" <<'PY'
import json, sys
print(len(json.load(open(sys.argv[1], encoding="utf-8"))))
PY
)"
if [[ "$pending_count" == "0" ]]; then
  echo "all configured raws are current"
  exit 0
fi

declare -a gh_args=(
  launch
  --scheme SimpleGLP
  --device "iPhone 17 Pro Max"
  --wait 14
  --record-seconds 1
  --args "-uitesting -GLPScreenshotSeed"
  --id-file "$id_file"
)
while IFS= read -r args; do gh_args+=(--screen "$args"); done < <(python3 - "$plan_file" <<'PY'
import json, sys
for entry in json.load(open(sys.argv[1], encoding="utf-8")):
    print(entry["args"])
PY
)

gh_sim_status=0
gh-sim "${gh_args[@]}" || gh_sim_status=$?
run_id="$(cat "$id_file")"
if [[ -z "$run_id" ]]; then exit "$gh_sim_status"; fi
shots="$HOME/.gh-sim/results/$run_id/shots"

python3 - "$KIT" "$plan_file" "$shots" "$run_id" <<'PY'
import json, shutil, sys
from pathlib import Path

kit, plan_file, shots, run_id = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
entries = json.loads(plan_file.read_text(encoding="utf-8"))
missing = []
copied = 0
for index, entry in enumerate(entries, 1):
    matches = sorted(shots.glob(f"screen{index}-*.png"))
    if len(matches) != 1:
        missing.append(f"{entry['locale']} {entry['scene']} (screen {index}: found {len(matches)})")
        continue
    capture = matches[0]
    if not capture.is_file():
        missing.append(f"{entry['locale']} {entry['scene']} (missing {capture})")
        continue
    destination = kit / "raw" / entry["locale"] / "phone" / f"{entry['scene']}.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(capture, destination)
    copied += 1
print(f"copied {copied}/{len(entries)} phone screens from gh-sim launch {run_id}")
if missing:
    print("missing captures: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)
PY
if ((gh_sim_status != 0)); then exit "$gh_sim_status"; fi
