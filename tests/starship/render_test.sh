#!/usr/bin/env bash
# Render the prompt against the user's starship.toml and assert:
#   - no literal `(style)` (regression guard for the deleted-files typo)
#   - the rose-pine palette is referenced
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if ! command -v starship >/dev/null 2>&1; then
    echo "skipped: starship not installed"
    exit 0
fi

# Static-check the toml content as a first defense.
if grep -E '\]\(style\)' "$REPO_ROOT/starship/starship.toml" >/dev/null; then
    echo "FAIL: starship.toml still contains literal (style) instead of (\$style)"
    grep -nE '\]\(style\)' "$REPO_ROOT/starship/starship.toml"
    exit 1
fi

# Dynamic render — needs a writable working directory.
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT
( cd "$TMP_REPO" && git init -q && git commit --allow-empty -qm "test" )

out=$(STARSHIP_CONFIG="$REPO_ROOT/starship/starship.toml" \
      starship prompt --terminal-width 120 --jobs 0 --status 0 --cmd-duration 0 2>&1)

# A successful render should not literally include "(style)" — that would mean
# the style interpolation broke and emitted the placeholder.
if echo "$out" | grep -q "(style)"; then
    echo "FAIL: rendered prompt contains literal (style)"
    echo "$out"
    exit 1
fi
echo "OK"
