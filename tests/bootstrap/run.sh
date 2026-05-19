#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if ! command -v bats >/dev/null 2>&1; then
    echo "skipped: bats not installed (brew install bats-core)"
    exit 0
fi
exec bats "$SCRIPT_DIR/sh_test.bats"
