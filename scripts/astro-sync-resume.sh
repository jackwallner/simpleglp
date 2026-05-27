#!/bin/bash
# Resume Astro sync for stores missing astro-keywords-by-store/<code>.json
set -euo pipefail
cd "$(dirname "$0")/.."
export PYTHONUNBUFFERED=1

python3 <<'PY'
import json, subprocess, sys, time
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, "scripts")
from astro_mcp import ping

ROOT = Path(".")
STORES_JSON = ROOT / "scripts/astro-stores-2026.json"
OUT_DIR = ROOT / "scripts/astro-keywords-by-store"
CONFIG = ROOT / "scripts/.astro-app.json"

stores = [s["code"] for s in json.loads(STORES_JSON.read_text())["stores"]]
done = {p.stem for p in OUT_DIR.glob("*.json") if p.stem != "_summary"}
remaining = [s for s in stores if s not in done]
failed: list[str] = []

print(f"resume: {len(remaining)} stores ({len(done)} already have json)", flush=True)

for i, store in enumerate(remaining, 1):
    ok = False
    for attempt in range(8):
        if not ping():
            time.sleep(6)
            continue
        print(f"[{i}/{len(remaining)}] {store} attempt {attempt+1}", flush=True)
        r = subprocess.run(
            [sys.executable, "scripts/astro-sync-all-stores.py", "--store", store],
            cwd=ROOT,
        )
        if r.returncode == 0:
            ok = True
            break
        time.sleep(10)
    if not ok:
        failed.append(store)
        print(f"FAILED {store}", flush=True)
    time.sleep(2)

# Full summary pass (all 91 stores in plan)
if ping():
    subprocess.run([sys.executable, "scripts/astro-sync-all-stores.py", "--dry-run"], cwd=ROOT)
    # Regenerate _summary from on-disk json + one MCP-free plan build
    summary = {
        "syncedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "appId": json.loads(CONFIG.read_text()).get("appId"),
        "storeCount": len(stores),
        "stores": {},
        "failed": failed,
    }
    for code in stores:
        p = OUT_DIR / f"{code}.json"
        if p.exists():
            data = json.loads(p.read_text())
            summary["stores"][code] = {
                "keywordCount": data.get("keywordCount", 0),
                "locales": data.get("locales", []),
            }
        else:
            summary["stores"][code] = {"missing": True}
    (OUT_DIR / "_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"summary: {len([c for c in stores if (OUT_DIR/f'{c}.json').exists()])}/{len(stores)} json files", flush=True)

print("failed:", failed, flush=True)
sys.exit(1 if failed else 0)
PY
