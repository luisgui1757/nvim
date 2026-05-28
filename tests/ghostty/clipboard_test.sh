#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

grep -E "^clipboard-read\s*=\s*ask" "$REPO_ROOT/ghostty/config" >/dev/null
grep -E "^clipboard-write\s*=\s*allow" "$REPO_ROOT/ghostty/config" >/dev/null

echo "OK"
