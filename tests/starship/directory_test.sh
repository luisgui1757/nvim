#!/usr/bin/env bash
# Regression guard: the directory module shows the FULL current path, not a
# truncated "last N folders" stub. We set truncation_length = 0 (no limit) and
# truncate_to_repo = false (don't collapse to the git-repo root); home still
# contracts to ~. Without these, deep/home paths show only a fragment.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TOML="$REPO_ROOT/starship/starship.toml"

# Static guards -- clear failure if someone re-enables truncation.
grep -qE '^truncation_length[[:space:]]*=[[:space:]]*0([[:space:]]|$)' "$TOML" \
    || { echo "FAIL: starship.toml truncation_length is not 0 (path would be truncated)"; exit 1; }
grep -qE '^truncate_to_repo[[:space:]]*=[[:space:]]*false([[:space:]]|$)' "$TOML" \
    || { echo "FAIL: starship.toml is missing truncate_to_repo = false (collapses to repo root)"; exit 1; }

# Dynamic guard -- render a path deeper than the old length (3) and assert every
# component survives. Only runs when starship is installed.
if ! command -v starship >/dev/null 2>&1; then
    echo "skipped dynamic render: starship not installed (static checks passed)"
    exit 0
fi

base="$(mktemp -d)"
trap 'rm -rf "$base"' EXIT
deep="$base/lvl1/lvl2/lvl3/lvl4"
mkdir -p "$deep"
out=$(cd "$deep" && STARSHIP_CONFIG="$TOML" starship module directory 2>&1)
if ! grep -q "lvl1/lvl2/lvl3/lvl4" <<<"$out"; then
    echo "FAIL: directory module truncated a 4-deep path (expected the full path)"
    echo "got: $out"
    exit 1
fi
echo "OK"
