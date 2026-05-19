#!/usr/bin/env bash
# Assert the zshrc produces a duplicate-free PATH.
set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
    echo "skipped: zsh not installed"
    exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

# Inject some pre-existing PATH dupes that the zshrc should collapse.
out=$(HOME="$TMP_HOME" PATH="/opt/homebrew/bin:/usr/local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH" \
    zsh -i -c "source $REPO_ROOT/shells/zshrc && print -r -- \$PATH" 2>&1)
# Split on : and count duplicates
dupes=$(printf '%s\n' "$out" | tr ':' '\n' | sort | uniq -d | wc -l | tr -d ' ')
if [[ "$dupes" -ne 0 ]]; then
    echo "FAIL: PATH contains $dupes duplicate entries"
    printf '%s\n' "$out" | tr ':' '\n' | sort | uniq -d
    exit 1
fi
echo "OK"
