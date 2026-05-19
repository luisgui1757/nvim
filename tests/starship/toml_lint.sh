#!/usr/bin/env bash
# Lint the starship toml — parse-check only. Uses taplo if available, else
# python's tomllib.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if command -v taplo >/dev/null 2>&1; then
    taplo lint "$REPO_ROOT/starship/starship.toml"
    echo "OK (taplo)"
    exit 0
fi
if command -v python3 >/dev/null 2>&1; then
    python3 - <<PY
import sys, tomllib
with open("$REPO_ROOT/starship/starship.toml", "rb") as f:
    tomllib.load(f)
print("OK (python tomllib)")
PY
    exit 0
fi
echo "skipped: neither taplo nor python3 available"
