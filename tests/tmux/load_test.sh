#!/usr/bin/env bash
# Start a detached tmux session using our conf, then tear it down.
# Any syntax error in tmux.conf causes new-session to fail.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "skipped: tmux not installed"
    exit 0
fi

session_name="dotfiles-test-$$"
sock_name="dotfiles-test-$$"

cleanup() {
    tmux -L "$sock_name" kill-server >/dev/null 2>&1 || true
}
trap cleanup EXIT

tmux -L "$sock_name" -f "$REPO_ROOT/tmux/tmux.conf" \
    new-session -d -s "$session_name" 'sleep 30'

if ! tmux -L "$sock_name" has-session -t "$session_name" 2>/dev/null; then
    echo "FAIL: session did not start"
    exit 1
fi
echo "OK"
