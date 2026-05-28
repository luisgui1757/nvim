#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"

uname() {
    case "${1:-}" in
        -s) printf '%s\n' "Darwin" ;;
        *) command uname "$@" ;;
    esac
}

have() {
    if [[ "$1" == "ghostty" ]]; then return 1; fi
    command -v "$1" >/dev/null 2>&1
}

YES_ALL=1
DRY_RUN=1
output="$(install_ghostty_macos)"

[[ "$output" == *"brew install --cask ghostty"* ]]

echo "OK"
