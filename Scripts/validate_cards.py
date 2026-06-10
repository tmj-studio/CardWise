#!/usr/bin/env python3
"""Deterministic validator for CardWise/Resources/cards.json (stdlib only).

Usage:
  python3 scripts/validate_cards.py [path] [--against GIT_REF]

Exit 0 = valid; 1 = problems (printed one per line to stderr).
--against checks that `version` strictly increased vs that ref's copy.
"""
import argparse
import json
import subprocess
import sys

CADENCES = {"monthly", "quarterly", "semiannual", "annual"}
CATEGORIES = {
    "dining", "grocery", "gas", "travel", "streaming", "drugstore", "homeImprovement",
    "entertainment", "onlineShopping", "transit", "utilities", "wholesale", "paypal",
    "amazon", "fitness", "phone", "internet", "shipping", "advertising", "officeSupplies",
    "evCharging", "apple", "wholeFoods", "target", "walmart", "macys", "kohls", "gap",
    "nordstrom", "electronics", "hotels", "airlines", "disney", "other",
}
NETWORKS = {"visa", "mastercard", "amex", "discover"}
REWARD_TYPES = {"cashback", "points", "miles"}
CARD_REQUIRED = ["id", "name", "issuer", "network", "annualFee", "rewardType",
                 "baseReward", "baseIsPercentage", "categoryRewards", "imageColor"]
DEFAULT_PATH = "CardWise/Resources/cards.json"


def validate(data, old_version=None):
    errs = []
    if not isinstance(data, dict):
        return ["top level must be an object {version, updatedAt, cards}"]
    if not isinstance(data.get("version"), int):
        errs.append("version must be an int")
    if not isinstance(data.get("updatedAt"), str):
        errs.append("updatedAt must be a string")
    cards = data.get("cards")
    if not isinstance(cards, list) or not cards:
        return errs + ["cards must be a non-empty list"]
    if old_version is not None and isinstance(data.get("version"), int) \
            and data["version"] <= old_version:
        errs.append(f"version {data['version']} must be > previous {old_version}")

    card_ids, credit_ids = set(), set()
    for i, c in enumerate(cards):
        where = f"cards[{i}] ({c.get('id', '?')})"
        for f in CARD_REQUIRED:
            if f not in c:
                errs.append(f"{where}: missing field '{f}'")
        cid = c.get("id")
        if cid:
            if cid in card_ids:
                errs.append(f"{where}: duplicate card id")
            card_ids.add(cid)
        if c.get("network") not in NETWORKS:
            errs.append(f"{where}: bad network {c.get('network')!r}")
        if c.get("rewardType") not in REWARD_TYPES:
            errs.append(f"{where}: bad rewardType {c.get('rewardType')!r}")
        fee = c.get("annualFee")
        if not isinstance(fee, (int, float)) or fee < 0:
            errs.append(f"{where}: annualFee must be >= 0")
        for r in c.get("categoryRewards") or []:
            if r.get("category") not in CATEGORIES:
                errs.append(f"{where}: reward bad category {r.get('category')!r}")
            m = r.get("multiplier")
            if not isinstance(m, (int, float)) or m <= 0:
                errs.append(f"{where}: reward multiplier must be > 0")
        for cr in c.get("credits") or []:
            crid = cr.get("id")
            if not crid:
                errs.append(f"{where}: credit missing id")
            elif crid in credit_ids:
                errs.append(f"{where}: duplicate credit id '{crid}'")
            else:
                credit_ids.add(crid)
            if not cr.get("description"):
                errs.append(f"{where}: credit '{crid}' missing description")
            if cr.get("cadence") not in CADENCES:
                errs.append(f"{where}: credit '{crid}' bad cadence {cr.get('cadence')!r}")
            cat = cr.get("category")
            if cat is not None and cat not in CATEGORIES:
                errs.append(f"{where}: credit '{crid}' bad category {cat!r}")
            amt = cr.get("amount")
            if not isinstance(amt, (int, float)) or amt <= 0:
                errs.append(f"{where}: credit '{crid}' amount must be > 0")
            elif isinstance(fee, (int, float)) and fee > 0 and amt > 3 * fee:
                errs.append(f"{where}: credit '{crid}' amount {amt} exceeds 3x annual fee {fee}")
    return errs


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("path", nargs="?", default=DEFAULT_PATH)
    p.add_argument("--against", help="git ref whose copy must have a lower version")
    a = p.parse_args()
    with open(a.path) as f:
        data = json.load(f)
    old_version = None
    if a.against:
        try:
            blob = subprocess.run(["git", "show", f"{a.against}:{DEFAULT_PATH}"],
                                  capture_output=True, text=True, check=True).stdout
            old = json.loads(blob)
            old_version = old["version"] if isinstance(old, dict) else None
        except subprocess.CalledProcessError:
            print(f"note: {a.against} has no {DEFAULT_PATH}; skipping version check",
                  file=sys.stderr)
    errs = validate(data, old_version=old_version)
    for e in errs:
        print(f"cards.json: {e}", file=sys.stderr)
    sys.exit(1 if errs else 0)


if __name__ == "__main__":
    main()
