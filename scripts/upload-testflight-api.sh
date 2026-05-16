#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${1:-$ROOT/build/export/SimpleGLP.ipa}"

if [[ -z "${ASC_API_KEY_ID:-}" || -z "${ASC_API_ISSUER_ID:-}" ]]; then
  echo "error: set ASC_API_KEY_ID and ASC_API_ISSUER_ID" >&2
  exit 1
fi

if [[ ! -f "$IPA" ]]; then
  echo "error: IPA not found: $IPA" >&2
  exit 1
fi

xcrun iTMSTransporter \
  -m upload \
  -apiKey "$ASC_API_KEY_ID" \
  -apiIssuer "$ASC_API_ISSUER_ID" \
  -assetFile "$IPA" \
  -distribution AppStore \
  -v informational
