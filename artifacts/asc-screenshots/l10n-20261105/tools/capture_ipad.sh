#!/usr/bin/env bash
# Capture the iPad (13-inch) raws for the App Store set, one GitHub simulator launch per locale.
# Usage: capture_ipad.sh [locale ...]   (default: all twelve live-screenshot locales)
# Raws land in KIT/raw/<locale>/ipad/<scene>.png. Existing raws are reused unless GH_SIM_FORCE=1.
set -uo pipefail

KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(git -C "$KIT" rev-parse --show-toplevel)"
cd "$ROOT"

lang_of() {
  case "$1" in
    en-US) echo "(en) en_US";; pt-BR) echo "(pt-BR) pt_BR";; de-DE) echo "(de) de_DE";; hu) echo "(hu) hu_HU";;
    zh-Hant) echo "(zh-Hant) zh_TW";; tr) echo "(tr) tr_TR";; es-ES) echo "(es) es_ES";; pl) echo "(pl) pl_PL";;
    es-MX) echo "(es-MX) es_MX";; fr-FR) echo "(fr) fr_FR";; ru) echo "(ru) ru_RU";; it) echo "(it) it_IT";;
    *) echo "unknown locale $1" >&2; return 1;;
  esac
}
SCENES=(
  "01-know-when-your-next-shot-is-due|-GLPDuoScreen oneTap"
  "02-log-a-shot-in-one-tap|-GLPDuoScreen history"
  "03-review-a-recorded-shot|-GLPDuoScreen history -GLPScreenshotDetails"
  "04-see-how-your-timing-holds|-GLPDuoScreen patterns -GLPScreenshotPro"
  "05-set-a-schedule-that-fits|-GLPScreenshotPlan"
  "06-confirm-a-completed-shot|-GLPScreenshotConfirmation"
  "07-tune-proactive-alerts|-GLPScreenshotAlerts -GLPScreenshotPro"
)
locales=("$@")
((${#locales[@]})) || locales=(en-US pt-BR de-DE hu zh-Hant tr es-ES pl es-MX fr-FR ru it)

for locale in "${locales[@]}"; do
  read -r languages apple_locale <<<"$(lang_of "$locale")" || continue
  last=7; [[ "$locale" == hu || "$locale" == ru ]] && last=6
  names=()
  id_file="$(mktemp)"
  gh_args=(launch --scheme SimpleGLP --device "iPad Pro 13-inch (M5)" --wait 14 --record-seconds 1
           --args "-uitesting -GLPScreenshotSeed" --id-file "$id_file")
  for entry in "${SCENES[@]:0:last}"; do
    scene="${entry%%|*}"; args="${entry#*|}"
    [[ -f "$KIT/raw/$locale/ipad/$scene.png" && "${GH_SIM_FORCE:-}" != 1 ]] && continue
    names+=("$scene")
    gh_args+=(--screen "-AppleLanguages $languages -AppleLocale $apple_locale $args")
  done
  ((${#names[@]})) || { echo "$locale: raws current"; continue; }
  echo "$locale: launching ${#names[@]} scenes"
  gh-sim "${gh_args[@]}" || echo "$locale: gh-sim exited nonzero" >&2
  run_id="$(cat "$id_file")"
  [[ -n "$run_id" ]] || { echo "$locale: no run id" >&2; continue; }
  shots="$HOME/.gh-sim/results/$run_id/shots"
  mkdir -p "$KIT/raw/$locale/ipad"
  i=0
  for scene in "${names[@]}"; do
    i=$((i + 1))
    shot=$(ls "$shots"/screen$i-*.png 2>/dev/null | head -1)
    if [[ -n "$shot" ]]; then cp "$shot" "$KIT/raw/$locale/ipad/$scene.png"; else echo "$locale: missing $scene" >&2; fi
  done
  echo "$locale: done ($run_id)"
done
echo ALLDONE
