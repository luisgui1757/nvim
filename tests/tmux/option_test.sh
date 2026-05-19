#!/usr/bin/env bash
# Boot a session and check that the options we care about really apply.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "skipped: tmux not installed"
    exit 0
fi

session_name="dotfiles-opt-$$"
sock_name="dotfiles-opt-$$"

cleanup() {
    tmux -L "$sock_name" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

tmux -L "$sock_name" -f "$REPO_ROOT/tmux/tmux.conf" \
    new-session -d -s "$session_name" 'sleep 30'

show() { tmux -L "$sock_name" show-options -gv "$1" 2>&1; }

check() {
    local opt="$1" want="$2"
    local got
    got="$(show "$opt")"
    if [[ "$got" != "$want" ]]; then
        echo "FAIL: $opt = '$got' (want '$want')"
        exit 1
    fi
    echo "  $opt = $got"
}

check focus-events on
check mouse on
check escape-time 10
check history-limit 50000

# Prefix isn't shown by show-options; verify via list-keys instead.
if ! tmux -L "$sock_name" list-keys -T prefix >/dev/null 2>&1; then
    echo "FAIL: tmux list-keys failed"; exit 1
fi
prefix=$(tmux -L "$sock_name" display-message -p "#{prefix}")
if [[ "$prefix" != "C-Space" ]]; then
    echo "FAIL: prefix = '$prefix' (want 'C-Space')"
    exit 1
fi
echo "  prefix = $prefix"
echo "OK"
