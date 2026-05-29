#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

files=$(find "$REPO_ROOT" -type f -name "*.toml" -not -path "*/.git/*" -not -path "*/tests/.cache/*")
[[ -z "$files" ]] && { echo "no toml files"; exit 0; }

if command -v taplo >/dev/null 2>&1; then
    for f in $files; do taplo lint "$f"; done
    echo "OK (taplo)"
    exit 0
fi
if command -v python3 >/dev/null 2>&1; then
    for f in $files; do
        python3 - "$f" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as fh:
    tomllib.load(fh)
PY
    done
    echo "OK (python tomllib)"
    exit 0
fi
echo "skipped: no toml parser available"
