#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"

TMP_ROOT="$REPO_ROOT/tests/.cache/require-downloader-test"
rm -rf "$TMP_ROOT"
mkdir -p "$TMP_ROOT"
trap 'rm -rf "$TMP_ROOT"' EXIT

uname() {
    case "${1:-}" in
        -s) printf '%s\n' "Linux" ;;
        *) command uname "$@" ;;
    esac
}

curl_installed=0
pm_install_calls=0
have() {
    case "$1" in
        curl) [[ "$curl_installed" -eq 1 ]] ;;
        *) command -v "$1" >/dev/null 2>&1 ;;
    esac
}

pm_install() {
    pm_install_calls=$((pm_install_calls + 1))
    printf '%s\n' "$*" >> "$TMP_ROOT/pm_install.log"
    curl_installed=1
}

PM=apt
DRY_RUN=0

require_downloader
require_downloader

if [[ "$pm_install_calls" -ne 1 ]]; then
    echo "FAIL: expected one pm_install call, got $pm_install_calls" >&2
    exit 1
fi

if [[ "$(cat "$TMP_ROOT/pm_install.log")" != "curl ca-certificates" ]]; then
    echo "FAIL: expected pm_install curl ca-certificates" >&2
    cat "$TMP_ROOT/pm_install.log" >&2
    exit 1
fi

echo "OK"
