#!/bin/sh
# One-time per clone: route git hooks to the repo's versioned hooks dir.
set -e
cd "$(git rev-parse --show-toplevel)"
chmod +x scripts/hooks/* 2>/dev/null || true
git config core.hooksPath scripts/hooks
echo "hooks installed (core.hooksPath -> scripts/hooks)"
