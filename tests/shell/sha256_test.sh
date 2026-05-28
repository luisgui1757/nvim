#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"

TMP_ROOT="$REPO_ROOT/tests/.cache/sha256-test"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

fixture="$TMP_ROOT/fixture.txt"
printf 'dotfiles\n' > "$fixture"

verify_sha256 "$fixture" "8c8a4ede42708041bc21d37211a9b00dabe1578f31e86893071a5040af5cd6a8"
if verify_sha256 "$fixture" "0000000000000000000000000000000000000000000000000000000000000000"; then
    echo "FAIL: verify_sha256 accepted an incorrect digest"
    exit 1
fi

echo "OK"
