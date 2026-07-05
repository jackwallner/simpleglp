#!/usr/bin/env python3
"""Align Simple GLP subscription prices with Vitals' regional curve.

Vitals uses tiered emerging-market discounts. GLP mirrors that shape, scaled to
its US base (yearly $19.99 / monthly $2.99 vs Vitals $14.99 / $1.99).

Usage:
  python3 scripts/asc-mirror-vitals-pricing.py --dry-run
  python3 scripts/asc-mirror-vitals-pricing.py --apply
  python3 scripts/asc-mirror-vitals-pricing.py --apply --tiers-only
"""
from __future__ import annotations

import argparse
import sys
import time
from datetime import date, timedelta

sys.path.insert(0, "scripts")
from asc_lib import ASCClient, bearer_token, list_all, load_credentials

VITALS_TIERS: dict[str, tuple[float, float]] = {
    "IND": (4.99, 0.69),
    "PAK": (4.99, 0.69),
    "BGD": (4.99, 0.69),
    "IDN": (4.99, 0.69),
    "VNM": (4.99, 0.69),
    "PHL": (4.99, 0.69),
    "EGY": (4.99, 0.69),
    "NGA": (4.99, 0.69),
    "TUR": (7.99, 0.99),
    "BRA": (7.99, 0.99),
    "MEX": (7.99, 0.99),
    "COL": (7.99, 0.99),
    "CHL": (7.99, 0.99),
    "THA": (7.99, 0.99),
    "MYS": (7.99, 0.99),
    "POL": (7.99, 0.99),
    "HUN": (7.99, 0.99),
    "ROU": (7.99, 0.99),
    "ZAF": (7.99, 0.99),
    "RUS": (7.99, 0.99),
    "SAU": (11.99, 1.49),
    "ARE": (11.99, 1.49),
    "CZE": (11.99, 1.49),
    "CHN": (11.99, 1.49),
}

TERRITORY_CURRENCY = {
    "IND": "INR", "PAK": "PKR", "BGD": "BDT", "IDN": "IDR", "VNM": "VND", "PHL": "PHP",
    "EGY": "EGP", "NGA": "NGN", "TUR": "TRY", "BRA": "BRL", "MEX": "MXN", "COL": "COP",
    "CHL": "CLP", "THA": "THB", "MYS": "MYR", "POL": "PLN", "HUN": "HUF", "ROU": "RON",
    "ZAF": "ZAR", "RUS": "RUB", "SAU": "SAR", "ARE": "AED", "CZE": "CZK", "CHN": "CNY",
    "USA": "USD",
}

FX = {
    "INR": 0.012, "PKR": 0.0036, "BDT": 0.0082, "IDR": 0.000062, "VND": 0.0000395,
    "PHP": 0.0173, "EGP": 0.020, "NGN": 0.00065, "TRY": 0.029, "BRL": 0.20, "MXN": 0.049,
    "COP": 0.00024, "CLP": 0.0011, "THB": 0.029, "MYR": 0.22, "PLN": 0.25, "HUF": 0.0028,
    "RON": 0.22, "ZAR": 0.055, "RUB": 0.011, "SAR": 0.27, "AED": 0.27, "CZK": 0.044,
    "CNY": 0.14, "USD": 1.0,
}

GLP_SUBS = [("6776424866", "Yearly", 0), ("6776425244", "Monthly", 1)]
VIT_SUBS = [("6767107405", "Yearly", 0), ("6767107539", "Monthly", 1)]
GLP_US = (19.99, 2.99)
VIT_US = (14.99, 1.99)
YR_RATIO = GLP_US[0] / VIT_US[0]
MO_RATIO = GLP_US[1] / VIT_US[1]
SCHEDULED_START = (date.today() + timedelta(days=2)).isoformat()


def scaled_tier_targets() -> dict[str, tuple[float, float]]:
    return {t: (y * YR_RATIO, m * MO_RATIO) for t, (y, m) in VITALS_TIERS.items()}


def price_points(client: ASCClient, sub_id: str, terr: str) -> list[tuple[float, float, str]]:
    r = client.get(f"/subscriptions/{sub_id}/pricePoints?filter[territory]={terr}&limit=200")
    ccy = TERRITORY_CURRENCY.get(terr, "USD")
    fx = FX.get(ccy, 1.0)
    pts = [(float(p["attributes"]["customerPrice"]) * fx, float(p["attributes"]["customerPrice"]), p["id"]) for p in r["data"]]
    pts.sort()
    return pts


def pick_price_point(pts: list[tuple[float, float, str]], target_usd: float) -> tuple[str, float] | None:
    if not pts:
        return None
    eligible = [x for x in pts if x[0] <= target_usd]
    pick = eligible[-1] if eligible else pts[0]
    return pick[2], pick[1]


def current_price(client: ASCClient, sub_id: str, terr: str) -> float | None:
    r = client.get(f"/subscriptions/{sub_id}/prices?filter[territory]={terr}&include=subscriptionPricePoint&limit=5")
    data = r.get("data", [])
    included = {x["id"]: x for x in r.get("included", [])}
    if not data:
        return None
    pp = (data[-1].get("relationships", {}).get("subscriptionPricePoint") or {}).get("data")
    if pp and pp["id"] in included:
        return float(included[pp["id"]]["attributes"]["customerPrice"])
    return None


def create_price(client: ASCClient, sub_id: str, terr: str, pp_id: str) -> None:
    client.post(
        "/subscriptionPrices",
        {
            "data": {
                "type": "subscriptionPrices",
                "attributes": {"preserveCurrentPrice": True, "startDate": SCHEDULED_START},
                "relationships": {
                    "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                    "territory": {"data": {"type": "territories", "id": terr}},
                    "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}},
                },
            }
        },
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--tiers-only", action="store_true", help="Only the 26 Vitals tier territories")
    args = parser.parse_args()
    if not args.dry_run and not args.apply:
        parser.error("pass --dry-run or --apply")

    client = ASCClient(bearer_token(*load_credentials()))
    tiers = scaled_tier_targets()
    territories = sorted(tiers) if args.tiers_only else sorted(t["id"] for t in list_all(client, "/territories?limit=200"))

    # Cache vitals prices for tier + ratio territories.
    vit_cache: dict[tuple[str, str], float] = {}
    for terr in set(territories) | {"USA"}:
        for vit_id, _, _ in VIT_SUBS:
            cp = current_price(client, vit_id, terr)
            if cp is not None:
                vit_cache[(vit_id, terr)] = cp
        time.sleep(0.05)

    ladder_cache: dict[tuple[str, str], list] = {}

    def target_usd(terr: str, idx: int) -> float:
        vit_id = VIT_SUBS[idx][0]
        vit_local = vit_cache.get((vit_id, terr))
        ratio = YR_RATIO if idx == 0 else MO_RATIO
        if vit_local is not None:
            fx = FX.get(TERRITORY_CURRENCY.get(terr, "USD"), 1.0)
            return vit_local * fx * ratio
        if terr in tiers:
            return tiers[terr][idx]
        return GLP_US[idx]

    changes = []
    for terr in territories:
        for glp_id, label, idx in GLP_SUBS:
            key = (glp_id, terr)
            if key not in ladder_cache:
                ladder_cache[key] = price_points(client, glp_id, terr)
            target = target_usd(terr, idx)
            picked = pick_price_point(ladder_cache[key], target)
            if picked is None:
                continue
            pp_id, new_local = picked
            cur = current_price(client, glp_id, terr)
            if cur is not None and abs(cur - new_local) < 0.001:
                continue
            # Emerging-market pass: only lower prices, never raise them.
            if args.tiers_only and cur is not None and new_local > cur:
                continue
            changes.append((terr, label, glp_id, cur or 0.0, new_local, target, pp_id))

    print(f"Planned changes: {len(changes)} (start {SCHEDULED_START}, tiers_only={args.tiers_only})")
    for row in changes[:30]:
        terr, label, _, cur, new, target, _ = row
        print(f"  {terr:4} {label:7} {cur:>12} -> {new:>12}  (<= ${target:.2f})")
    if len(changes) > 30:
        print(f"  ... +{len(changes) - 30} more")

    if args.dry_run:
        return

    ok = 0
    for terr, label, glp_id, _, new, _, pp_id in changes:
        try:
            create_price(client, glp_id, terr, pp_id)
            ok += 1
            print(f"  applied {terr} {label} -> {new}")
        except Exception as e:
            print(f"  FAIL {terr} {label}: {str(e)[:160]}")
        time.sleep(0.2)
    print(f"Applied {ok}/{len(changes)}.")


if __name__ == "__main__":
    main()
