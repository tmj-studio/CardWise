#!/bin/bash
# Weekly card-data refresh. Runs on the Mac mini via launchd (or manually).
#   ./Scripts/update_cards.sh [--dry-run]
# --dry-run: skip claude + push/PR; apply a synthetic SAFE edit to exercise the pipeline.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
CARDS="CardWise/Resources/cards.json"
DATE=$(date +%Y%m%d)
BRANCH="data/cards-update-$DATE"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
log() { echo "[update-cards $(date '+%F %T')] $*"; }

# Snapshot the tooling before any branch switch, so the pipeline works no matter
# what the target branch contains.
TOOLS=$(mktemp -d)
trap 'rm -rf "$TOOLS"' EXIT
cp Scripts/validate_cards.py Scripts/diff_cards.py "$TOOLS/"

log "syncing main"
git fetch origin
git checkout -q -B "$BRANCH" origin/main
cp "$CARDS" "$TOOLS/cards-before.json"

if [ "$DRY" = "1" ]; then
    log "dry-run: applying synthetic edit (version bump only)"
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
must be a SpendingCategory raw value already used elsewhere in the file)}). Rules: change \
ONLY values you can verify from issuer pages or reputable sources; if unsure leave the value \
alone; do NOT add or remove cards; do NOT invent credits; keep ids stable; finally increment \
top-level 'version' by 1 and set 'updatedAt' to today (YYYY-MM-DD). Edit the file in place. \
If after research nothing needs changing, change nothing (do not bump version)."
fi

restore_branch() {
    git checkout -q -- "$CARDS" 2>/dev/null || true
    git checkout -q - 2>/dev/null || git checkout -q main 2>/dev/null || true
    git branch -q -D "$BRANCH" 2>/dev/null || true
}

if git diff --quiet -- "$CARDS"; then
    log "no changes; done"
    restore_branch
    exit 0
fi

log "validating"
if ! python3 "$TOOLS/validate_cards.py" "$CARDS" --against origin/main; then
    log "validation FAILED — discarding changes"
    restore_branch
    exit 1
fi

log "classifying diff"
SUMMARY=$(python3 "$TOOLS/diff_cards.py" "$TOOLS/cards-before.json" "$CARDS") && CLASS=0 || CLASS=$?
if [ "$CLASS" = "1" ]; then
    log "differ errored"
    restore_branch
    exit 1
fi
if [ "$CLASS" = "2" ]; then
    TITLE="⚠️ data: weekly card update (NEEDS REVIEW)"
else
    TITLE="data: weekly card update (SAFE)"
fi
log "classification: $TITLE"

if [ "$DRY" = "1" ]; then
    log "dry-run: would commit to $BRANCH and open PR titled: $TITLE"
    echo "$SUMMARY"
    restore_branch
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
