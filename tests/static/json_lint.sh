#!/usr/bin/env bash
# Validate every JSON / JSONC file in the repo.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# Standard JSON files: lazy-lock.json, claude/settings.json, etc.
json_files=$(find "$REPO_ROOT" -type f -name "*.json" -not -path "*/.git/*" -not -name "*.tmp")
if command -v jq >/dev/null 2>&1; then
    fail=0
    for f in $json_files; do
        if ! jq empty "$f" 2>err; then
            echo "FAIL: $f"; cat err; fail=1
        fi
    done
    [[ -e err ]] && rm err
    [[ "$fail" -ne 0 ]] && exit 1
else
    echo "skipped json: jq not installed"
fi

# JSONC: strip // line comments and run through jq.
jsonc_files=$(find "$REPO_ROOT" -type f -name "*.jsonc" -not -path "*/.git/*")
if command -v jq >/dev/null 2>&1; then
    fail=0
    for f in $jsonc_files; do
        # Strip both // line comments and /* block */ comments before parsing.
        if ! sed -E 's|//[^"]*$||g' "$f" | jq empty 2>err; then
            echo "FAIL (jsonc): $f"; cat err; fail=1
        fi
    done
    [[ -e err ]] && rm err
    [[ "$fail" -ne 0 ]] && exit 1
fi

echo "OK"
