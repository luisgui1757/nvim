#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
FRAGMENT="$REPO_ROOT/windows-terminal/settings.fragment.jsonc"

if grep -Eq '"action"[[:space:]]*:[[:space:]]*"closeTab".*"keys"[[:space:]]*:[[:space:]]*"ctrl\+w"' "$FRAGMENT"; then
    echo "FAIL: ctrl+w must not be bound to closeTab"
    exit 1
fi

grep -Eq '"action"[[:space:]]*:[[:space:]]*"closeTab".*"keys"[[:space:]]*:[[:space:]]*"ctrl\+shift\+w"' "$FRAGMENT"
grep -Eq '"command"[[:space:]]*:[[:space:]]*"closePane".*"keys"[[:space:]]*:[[:space:]]*"ctrl\+alt\+w"' "$FRAGMENT"

echo "OK"
