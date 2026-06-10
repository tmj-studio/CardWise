#!/usr/bin/env python3
"""Classify changes between two cards.json files as SAFE or SUSPICIOUS.

Usage: python3 scripts/diff_cards.py OLD NEW

Prints a markdown summary. Exit: 0 = SAFE-only (or no changes),
2 = contains SUSPICIOUS changes, 1 = error.
"""
import json
import sys

FEE_SUSPICIOUS_RATIO = 0.25
CREDIT_SUSPICIOUS_RATIO = 0.50


def _by_id(items):
    return {x.get("id"): x for x in items or []}


def classify(old, new):
    safe, susp = [], []
    oc, nc = _by_id(old.get("cards")), _by_id(new.get("cards"))
    for cid in nc.keys() - oc.keys():
        susp.append(f"card ADDED: {cid}")
    for cid in oc.keys() - nc.keys():
        susp.append(f"card REMOVED: {cid}")
    for cid in oc.keys() & nc.keys():
        o, n = oc[cid], nc[cid]
        of, nf = o.get("annualFee", 0), n.get("annualFee", 0)
        if of != nf:
            if (of > 0 and abs(nf - of) / of > FEE_SUSPICIOUS_RATIO) or (of > 0) != (nf > 0):
                susp.append(f"{cid}: annualFee {of} -> {nf} (>25% or sign change)")
            else:
                safe.append(f"{cid}: annualFee {of} -> {nf}")
        orw = {r.get("category"): r for r in o.get("categoryRewards") or []}
        nrw = {r.get("category"): r for r in n.get("categoryRewards") or []}
        for cat in orw.keys() | nrw.keys():
            om = (orw.get(cat) or {}).get("multiplier")
            nm = (nrw.get(cat) or {}).get("multiplier")
            if om == nm:
                continue
            if nm == 0 or (om is not None and nm is None):
                susp.append(f"{cid}: reward {cat} {om}x -> {nm}")
            else:
                safe.append(f"{cid}: reward {cat} {om}x -> {nm}x")
        ocr, ncr = _by_id(o.get("credits")), _by_id(n.get("credits"))
        for crid in ncr.keys() - ocr.keys():
            safe.append(f"{cid}: credit ADDED {crid}")
        for crid in ocr.keys() - ncr.keys():
            susp.append(f"{cid}: credit REMOVED {crid}")
        for crid in ocr.keys() & ncr.keys():
            oa, na = ocr[crid].get("amount", 0), ncr[crid].get("amount", 0)
            if oa != na:
                if oa > 0 and abs(na - oa) / oa > CREDIT_SUSPICIOUS_RATIO:
                    susp.append(f"{cid}: credit {crid} amount {oa} -> {na} (>50%)")
                else:
                    safe.append(f"{cid}: credit {crid} amount {oa} -> {na}")
            if ocr[crid].get("cadence") != ncr[crid].get("cadence"):
                susp.append(f"{cid}: credit {crid} cadence "
                            f"{ocr[crid].get('cadence')} -> {ncr[crid].get('cadence')}")
    return {"safe": safe, "suspicious": susp}


def main():
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    with open(sys.argv[1]) as f:
        old = json.load(f)
    with open(sys.argv[2]) as f:
        new = json.load(f)
    r = classify(old, new)
    if not r["safe"] and not r["suspicious"]:
        print("No card data changes.")
        sys.exit(0)
    print("## Card data changes\n")
    if r["suspicious"]:
        print("### ⚠️ SUSPICIOUS (review before merging)\n")
        for s in r["suspicious"]:
            print(f"- {s}")
        print()
    if r["safe"]:
        print("### SAFE\n")
        for s in r["safe"]:
            print(f"- {s}")
    sys.exit(2 if r["suspicious"] else 0)


if __name__ == "__main__":
    main()
