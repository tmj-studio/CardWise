# Scripts/

Tooling around the bundled card database (`CardWise/Resources/cards.json`) plus a few
one-off asset generators. Design/spec background:
`docs/superpowers/specs/2026-06-10-local-cards-update-pipeline-design.md`.

## cards.json update pipeline

| File | Role |
|------|------|
| `update_cards.sh` | Weekly orchestrator. Creates a `data/cards-update-YYYYMMDD` branch off `origin/main`, runs a `claude -p` research pass that updates stale fees/multipliers/credits in `cards.json`, validates and diff-classifies the result, then pushes and opens a PR for **human review** (never merges itself). `--dry-run` skips claude/push and applies a synthetic edit to exercise the pipeline. |
| `validate_cards.py` | Deterministic schema/sanity validator for `cards.json` (also run `--against origin/main` to enforce version-bump rules). |
| `diff_cards.py` | Classifies a cards.json diff as SAFE (small value tweaks) or SUSPICIOUS (structural changes, card additions/removals); suspicious PRs get the `needs-review` label. |
| `hooks/pre-push` | Git hook that runs `validate_cards.py` before any push touching `cards.json`. |
| `install-hooks.sh` | Points `core.hooksPath` at `Scripts/hooks` (run once per clone). |
| `launchd/studio.tmj.cardwise.cards-update.plist` | launchd job that runs `update_cards.sh` weekly on the maintainer's Mac mini (deliberately not GitHub Actions — avoids API costs and self-hosted-runner risk). |
| `tests/` | Python unit tests for the validator and diff classifier: `python3 -m pytest Scripts/tests/` (not currently wired into CI). |

Manual run:

```bash
./Scripts/update_cards.sh --dry-run   # exercise the pipeline without claude/push
./Scripts/update_cards.sh             # real weekly update (needs `claude` and `gh` CLIs)
```

## One-off asset utilities

- `make_app_icon.py` — regenerates the app icon PNG.
- `make_appstore_shots.py` / `take_screenshots.sh` — App Store screenshot generation.

These are run manually and ad hoc; they are not part of CI or the release flow.
