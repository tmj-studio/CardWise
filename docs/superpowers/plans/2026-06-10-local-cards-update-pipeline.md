# 本機卡片資料自動更新流程(A2)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 卡片資料庫每週在 Mac mini 上以本機 claude(訂閱)自動研究更新、經確定性驗證與 SAFE/SUSPICIOUS 分類後開 PR;任何人 push 壞的 cards.json 都會被 pre-push hook 擋下。

**Architecture:** 三支 stdlib-only Python 腳本(驗證器、diff 分類器、由 bash 協調器串起),pre-push hook 與週更流程共用驗證器;mini 上用 launchd 排程、`claude -p` headless 研究、`gh pr create` 出 PR。main 受保護,所以「上線」永遠是一個等使用者 admin-merge 的 PR。

**Tech Stack:** Python 3.12(stdlib only)/ bash / git hooks(core.hooksPath)/ launchd / claude CLI 2.1.170 / gh CLI。

對應 spec:`docs/superpowers/specs/2026-06-10-local-cards-update-pipeline-design.md`。

---

## 檔案結構

- Create `scripts/validate_cards.py` — 確定性驗證器(Task 1)
- Create `scripts/tests/test_validate_cards.py` — unittest(Task 1)
- Create `scripts/diff_cards.py` — SAFE/SUSPICIOUS 分類器(Task 2)
- Create `scripts/tests/test_diff_cards.py` — unittest(Task 2)
- Create `scripts/hooks/pre-push` + `scripts/install-hooks.sh`(Task 3)
- Create `scripts/update_cards.sh` — mini 協調器(Task 4)
- Create `scripts/launchd/studio.tmj.cardwise.cards-update.plist`(Task 5)
- Task 5/6 在 mini 上部署與端到端驗證(ssh alias `mini`)

測試指令:`python3 -m unittest discover -s scripts/tests -v`(stdlib,無相依)。
Task 1∥2 可平行;3、4 依賴 1(與 2);5、6 依賴 4。

---

## Task 1: validate_cards.py(TDD)

- [ ] **Step 1: 失敗測試** — Create `scripts/tests/test_validate_cards.py`:
```python
import json, sys, unittest, tempfile, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from validate_cards import validate  # noqa: E402

def wrap(cards, version=5):
    return {"version": version, "updatedAt": "2026-06-10", "cards": cards}

def card(**kw):
    c = {"id": "x-1", "name": "X", "issuer": "X", "network": "visa", "annualFee": 95,
         "rewardType": "cashback", "baseReward": 1, "baseIsPercentage": True,
         "categoryRewards": [], "imageColor": "#000000"}
    c.update(kw); return c

class TestValidate(unittest.TestCase):
    def test_valid_passes(self):
        self.assertEqual(validate(wrap([card()])), [])

    def test_missing_field_fails(self):
        c = card(); del c["name"]
        self.assertTrue(any("name" in e for e in validate(wrap([c]))))

    def test_bad_cadence_and_category(self):
        c = card(credits=[{"id": "c1", "description": "d", "amount": 10,
                           "cadence": "weekly", "category": "dining"}])
        self.assertTrue(any("cadence" in e for e in validate(wrap([c]))))
        c2 = card(credits=[{"id": "c2", "description": "d", "amount": 10,
                            "cadence": "monthly", "category": "nope"}])
        self.assertTrue(any("category" in e for e in validate(wrap([c2]))))

    def test_credit_amount_bounds(self):
        c = card(credits=[{"id": "c3", "description": "d", "amount": 0, "cadence": "monthly"}])
        self.assertTrue(validate(wrap([c])))
        c2 = card(annualFee=95, credits=[{"id": "c4", "description": "d",
                                          "amount": 1000, "cadence": "annual"}])
        self.assertTrue(any("3x" in e for e in validate(wrap([c2]))))

    def test_duplicate_ids(self):
        self.assertTrue(any("duplicate" in e.lower()
                            for e in validate(wrap([card(), card()]))))
        c = card(credits=[{"id": "dup", "description": "d", "amount": 1, "cadence": "monthly"},
                          {"id": "dup", "description": "d", "amount": 1, "cadence": "monthly"}])
        self.assertTrue(any("duplicate" in e.lower() for e in validate(wrap([c]))))

    def test_zero_multiplier_rejected(self):
        c = card(categoryRewards=[{"category": "dining", "multiplier": 0,
                                   "isPercentage": True, "cap": None, "capPeriod": None}])
        self.assertTrue(any("multiplier" in e for e in validate(wrap([c]))))

    def test_version_must_increase(self):
        self.assertTrue(any("version" in e.lower()
                            for e in validate(wrap([card()], version=3), old_version=3)))
        self.assertEqual(validate(wrap([card()], version=4), old_version=3), [])

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 跑測試確認失敗** — `python3 -m unittest discover -s scripts/tests -v`,Expected: ImportError(validate_cards 不存在)。

- [ ] **Step 3: 實作** — Create `scripts/validate_cards.py`:
```python
#!/usr/bin/env python3
"""Deterministic validator for CardWise/Resources/cards.json (stdlib only).

Usage:
  python3 scripts/validate_cards.py [path] [--against GIT_REF]
Exit 0 = valid; 1 = problems (printed one per line).
--against checks that `version` strictly increased vs that ref's copy.
"""
import argparse, json, subprocess, sys

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
    p = argparse.ArgumentParser()
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
```

- [ ] **Step 4: 跑測試確認通過**,再拿真檔驗收:`python3 scripts/validate_cards.py && echo OK` → OK。

- [ ] **Step 5: Commit** — `git add scripts/validate_cards.py scripts/tests/test_validate_cards.py && git commit -m "feat(pipeline): deterministic cards.json validator"`

---

## Task 2: diff_cards.py(TDD)

- [ ] **Step 1: 失敗測試** — Create `scripts/tests/test_diff_cards.py`:
```python
import sys, os, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from diff_cards import classify  # noqa: E402

def card(cid="x", fee=95, rewards=None, credits=None):
    return {"id": cid, "name": cid, "annualFee": fee,
            "categoryRewards": rewards or [], "credits": credits or []}

def wrap(cards):
    return {"version": 1, "updatedAt": "2026-06-10", "cards": cards}

class TestClassify(unittest.TestCase):
    def test_no_change(self):
        r = classify(wrap([card()]), wrap([card()]))
        self.assertFalse(r["safe"]); self.assertFalse(r["suspicious"])

    def test_small_fee_change_is_safe(self):
        r = classify(wrap([card(fee=100)]), wrap([card(fee=110)]))
        self.assertTrue(r["safe"]); self.assertFalse(r["suspicious"])

    def test_big_fee_change_is_suspicious(self):
        r = classify(wrap([card(fee=100)]), wrap([card(fee=200)]))
        self.assertTrue(r["suspicious"])

    def test_card_added_or_removed_is_suspicious(self):
        self.assertTrue(classify(wrap([card("a")]), wrap([card("a"), card("b")]))["suspicious"])
        self.assertTrue(classify(wrap([card("a"), card("b")]), wrap([card("a")]))["suspicious"])

    def test_multiplier_to_zero_is_suspicious(self):
        old = card(rewards=[{"category": "dining", "multiplier": 3}])
        new = card(rewards=[{"category": "dining", "multiplier": 0}])
        self.assertTrue(classify(wrap([old]), wrap([new]))["suspicious"])

    def test_credit_added_is_safe_removed_is_suspicious(self):
        cr = {"id": "c1", "description": "d", "amount": 10, "cadence": "monthly"}
        self.assertTrue(classify(wrap([card()]), wrap([card(credits=[cr])]))["safe"])
        self.assertTrue(classify(wrap([card(credits=[cr])]), wrap([card()]))["suspicious"])

    def test_credit_amount_swing_is_suspicious(self):
        a = {"id": "c1", "description": "d", "amount": 10, "cadence": "monthly"}
        b = dict(a, amount=20)
        self.assertTrue(classify(wrap([card(credits=[a])]), wrap([card(credits=[b])]))["suspicious"])

if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 跑測試確認失敗**(ImportError)。

- [ ] **Step 3: 實作** — Create `scripts/diff_cards.py`:
```python
#!/usr/bin/env python3
"""Classify changes between two cards.json files as SAFE or SUSPICIOUS.

Usage: python3 scripts/diff_cards.py OLD NEW
Prints a markdown summary. Exit: 0 = SAFE-only (or no changes),
2 = contains SUSPICIOUS changes, 1 = error.
"""
import json, sys

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
            if of > 0 and abs(nf - of) / of > FEE_SUSPICIOUS_RATIO or (of > 0) != (nf > 0):
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
```

- [ ] **Step 4: 跑測試確認通過**(兩個測試檔一起:`python3 -m unittest discover -s scripts/tests -v`)。

- [ ] **Step 5: Commit** — `git add scripts/diff_cards.py scripts/tests/test_diff_cards.py && git commit -m "feat(pipeline): SAFE/SUSPICIOUS diff classifier"`

---

## Task 3: pre-push hook + 安裝器

- [ ] **Step 1: hook** — Create `scripts/hooks/pre-push`(`chmod +x`):
```bash
#!/bin/sh
# Blocks pushes that modify CardWise/Resources/cards.json with invalid data.
# Installed via scripts/install-hooks.sh (git config core.hooksPath scripts/hooks).
CARDS="CardWise/Resources/cards.json"
ZERO=0000000000000000000000000000000000000000
while read -r _local_ref local_sha _remote_ref remote_sha; do
    [ "$local_sha" = "$ZERO" ] && continue            # branch deletion
    if [ "$remote_sha" = "$ZERO" ]; then range_base="origin/main"; else range_base="$remote_sha"; fi
    if git diff --name-only "$range_base" "$local_sha" 2>/dev/null | grep -qx "$CARDS"; then
        echo "pre-push: validating $CARDS ..." >&2
        if ! python3 scripts/validate_cards.py "$CARDS" --against "$range_base"; then
            echo "pre-push: BLOCKED — fix cards.json (or bump version) and retry." >&2
            exit 1
        fi
    fi
done
exit 0
```

- [ ] **Step 2: 安裝器** — Create `scripts/install-hooks.sh`(`chmod +x`):
```bash
#!/bin/sh
# One-time per clone: route git hooks to the repo's versioned hooks dir.
set -e
cd "$(git rev-parse --show-toplevel)"
chmod +x scripts/hooks/* 2>/dev/null || true
git config core.hooksPath scripts/hooks
echo "hooks installed (core.hooksPath -> scripts/hooks)"
```

- [ ] **Step 3: 驗證擋/放行**(模擬 stdin,不真的 push):
```bash
bash scripts/install-hooks.sh
# 放行:目前 cards.json 合法且 version 已高於 origin/main 上一版?在本分支沒改 cards.json 時 hook 直接略過:
echo "refs/heads/x $(git rev-parse HEAD) refs/heads/x $(git rev-parse origin/main)" | sh scripts/hooks/pre-push; echo "exit=$?"
# 擋下:故意弄壞一份再測
python3 - <<'PY'
import json; p="CardWise/Resources/cards.json"; d=json.load(open(p))
d["cards"][0]["credits"]=[{"id":"bad","description":"d","amount":-5,"cadence":"weekly"}]
json.dump(d, open(p,"w"))
PY
git stash -q -- CardWise/Resources/cards.json 2>/dev/null || true  # (改用工作樹測試時 hook 比較的是 commit;簡化:直接對檔案跑 validator)
python3 scripts/validate_cards.py; echo "validator exit=$? (expect 1)"
git checkout -q -- CardWise/Resources/cards.json
```
Expected:略過時 exit=0;壞檔 validator exit=1。

- [ ] **Step 4: Commit** — `git add scripts/hooks/pre-push scripts/install-hooks.sh && git commit -m "feat(pipeline): pre-push validation hook"`

---

## Task 4: update_cards.sh(協調器,含 --dry-run)

- [ ] **Step 1: 實作** — Create `scripts/update_cards.sh`(`chmod +x`):
```bash
#!/bin/bash
# Weekly card-data refresh. Runs on the Mac mini via launchd (or manually).
#   ./scripts/update_cards.sh [--dry-run]
# --dry-run: skip claude + push/PR; apply a synthetic SAFE edit to exercise the pipeline.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
CARDS="CardWise/Resources/cards.json"
DATE=$(date +%Y%m%d)
BRANCH="data/cards-update-$DATE"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
log() { echo "[update-cards $(date '+%F %T')] $*"; }

log "syncing main"
git fetch origin
git checkout -q -B "$BRANCH" origin/main
cp "$CARDS" /tmp/cards-before.json

if [ "$DRY" = "1" ]; then
    log "dry-run: applying synthetic edit"
    python3 - <<'PY'
import json
p = "CardWise/Resources/cards.json"
d = json.load(open(p))
d["version"] += 1
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
else
    log "running claude research pass"
    claude -p --permission-mode acceptEdits "You are updating $CARDS, the bundled credit-card \
reward database of the CardWise iOS app (format: {version, updatedAt, cards:[...]}). \
Research CURRENT (this year) terms for the cards already in the file and fix anything stale: \
annualFee, categoryRewards multipliers, and 'credits' (dollar statement credits only — \
{id, description, amount, cadence(monthly|quarterly|semiannual|annual), category(optional, \
must be an existing SpendingCategory raw value already used in the file)}). Rules: change \
ONLY values you can verify from issuer pages or reputable sources; if unsure leave the value \
alone; do NOT add or remove cards; do NOT invent credits; keep ids stable; finally increment \
top-level 'version' by 1 and set 'updatedAt' to today (YYYY-MM-DD). Edit the file in place. \
If after research nothing needs changing, change nothing (do not bump version)."
fi

if git diff --quiet -- "$CARDS"; then
    log "no changes; done"
    git checkout -q origin/main 2>/dev/null || true
    git branch -q -D "$BRANCH" 2>/dev/null || true
    exit 0
fi

log "validating"
if ! python3 scripts/validate_cards.py "$CARDS" --against origin/main; then
    log "validation FAILED — discarding changes"
    git checkout -q -- "$CARDS"
    exit 1
fi

log "classifying diff"
SUMMARY=$(python3 scripts/diff_cards.py /tmp/cards-before.json "$CARDS") && CLASS=0 || CLASS=$?
[ "$CLASS" = "1" ] && { log "differ errored"; exit 1; }
if [ "$CLASS" = "2" ]; then TITLE="⚠️ data: weekly card update (NEEDS REVIEW)"; else TITLE="data: weekly card update (SAFE)"; fi
log "classification: $TITLE"

if [ "$DRY" = "1" ]; then
    log "dry-run: would commit to $BRANCH and open PR titled: $TITLE"
    echo "$SUMMARY"
    git checkout -q -- "$CARDS"
    git checkout -q origin/main 2>/dev/null || true
    git branch -q -D "$BRANCH" 2>/dev/null || true
    exit 0
fi

git add "$CARDS"
git commit -q -m "data: weekly card update ($DATE)"
git push -q -u origin "$BRANCH"
gh pr create --title "$TITLE" --body "$SUMMARY

Automated weekly update from the Mac mini pipeline (claude subscription, validated + classified).
Merge to publish — the app picks it up on next launch via the remote catalog." \
    $( [ "$CLASS" = "2" ] && echo --label needs-review ) || true
log "PR opened"
```

- [ ] **Step 2: dry-run 驗收**(本機即可):`bash scripts/update_cards.sh --dry-run`
Expected:`no changes`?不——合成編輯會 bump version ⇒ 走到 validating→classifying→`would commit ... (SAFE)`,結束後工作樹乾淨(`git status` 無殘留)。

- [ ] **Step 3: Commit** — `git add scripts/update_cards.sh && git commit -m "feat(pipeline): weekly update orchestrator with dry-run"`

---

## Task 5: launchd plist + mini 部署

- [ ] **Step 1: plist** — Create `scripts/launchd/studio.tmj.cardwise.cards-update.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>studio.tmj.cardwise.cards-update</string>
    <key>ProgramArguments</key><array>
        <string>/bin/bash</string>
        <string>/Users/moltbot/CardWise-data/scripts/update_cards.sh</string>
    </array>
    <key>WorkingDirectory</key><string>/Users/moltbot/CardWise-data</string>
    <key>StartCalendarInterval</key><dict>
        <key>Weekday</key><integer>1</integer>
        <key>Hour</key><integer>9</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>StandardOutPath</key><string>/Users/moltbot/CardWise-data/update.log</string>
    <key>StandardErrorPath</key><string>/Users/moltbot/CardWise-data/update.log</string>
    <key>EnvironmentVariables</key><dict>
        <key>PATH</key><string>/Users/moltbot/.local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    </dict>
</dict></plist>
```
Commit:`git add scripts/launchd/ && git commit -m "feat(pipeline): launchd schedule for weekly card update"`

- [ ] **Step 2: 先把分支推上去 + 開 PR + merge**(腳本要進 main,mini 的 clone 才抓得到)— 照本 repo 慣例:push 分支、`gh pr create`、使用者 admin-merge。

- [ ] **Step 3: mini 部署**(merge 後;ssh alias `mini`):
```bash
ssh mini 'set -e
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
  gh auth status || { echo "NEED gh auth on mini"; exit 1; }
  [ -d ~/CardWise-data ] || git clone https://github.com/tmj-studio/CardWise.git ~/CardWise-data
  cd ~/CardWise-data && git pull
  gh auth setup-git
  cp scripts/launchd/studio.tmj.cardwise.cards-update.plist ~/Library/LaunchAgents/
  launchctl unload ~/Library/LaunchAgents/studio.tmj.cardwise.cards-update.plist 2>/dev/null || true
  launchctl load ~/Library/LaunchAgents/studio.tmj.cardwise.cards-update.plist
  launchctl list | grep cardwise && echo DEPLOYED'
```
Expected:`DEPLOYED`。若 `NEED gh auth on mini` → 請使用者在 mini 上跑一次 `gh auth login`。

---

## Task 6: 端到端驗證

- [ ] **Step 1: mini 上 dry-run** — `ssh mini 'export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"; cd ~/CardWise-data && bash scripts/update_cards.sh --dry-run'`,Expected:走完 validate+classify、無殘留。
- [ ] **Step 2: mini 上真跑一次**(等同每週一的執行)— `ssh mini '... bash scripts/update_cards.sh'`,Expected:claude 研究後若有變動 → PR 出現(`gh pr list`);無變動 → `no changes`。兩者皆算通過。
- [ ] **Step 3: 記錄** — 在記憶中記下 mini 部署位置/排程,完成 A2。
