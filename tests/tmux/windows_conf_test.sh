#!/usr/bin/env bash
# Static guards for the Windows-only psmux overlay.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

WIN_CONF="$REPO_ROOT/tmux/tmux.windows.conf"

require_line() {
    local pattern=$1 message=$2
    if ! grep -Eq "$pattern" "$WIN_CONF"; then
        echo "FAIL: $message"
        exit 1
    fi
}

require_line '^bind-key[[:space:]]+-n[[:space:]]+C-j[[:space:]]+send-keys[[:space:]]+F8$' \
    'tmux.windows.conf must translate C-j to F8 for lazygit inside psmux'
require_line '^bind-key[[:space:]]+-n[[:space:]]+C-k[[:space:]]+send-keys[[:space:]]+F7$' \
    'tmux.windows.conf must translate C-k to F7 for lazygit inside psmux'

if ! grep -Eq "tmux\\\\tmux\.windows\.conf" "$REPO_ROOT/bootstrap.ps1"; then
    echo "FAIL: bootstrap.ps1 must symlink tmux.windows.conf on Windows"
    exit 1
fi

if grep -Eq 'tmux[\\/]tmux\.windows\.conf|\.tmux\.windows\.conf' "$REPO_ROOT/bootstrap.sh"; then
    echo "FAIL: bootstrap.sh must not symlink tmux.windows.conf on Unix/WSL"
    exit 1
fi

echo "OK"
