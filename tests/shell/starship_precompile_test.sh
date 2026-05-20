#!/usr/bin/env bash
# Verify the zshrc precompile cache mechanism: created on first run,
# reused on second, regenerated when toml is newer.
set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
    echo "skipped: zsh not installed"
    exit 0
fi
if ! command -v starship >/dev/null 2>&1; then
    echo "skipped: starship not installed"
    exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP_HOME="$(mktemp -d)"
TMP_CONFIG="$(mktemp -d)/starship.toml"
trap 'rm -rf "$TMP_HOME" "$(dirname "$TMP_CONFIG")"' EXIT

# Copy the toml into a scratch dir so we don't dirty the repo (CI lint depends
# on a clean worktree). Force its mtime well into the past so the cache (which
# the first run creates with mtime = now) is reliably newer -- on Linux's
# nanosecond-precision filesystems the cp + immediate-create race otherwise
# leaves the toml very slightly newer than the cache.
cp "$REPO_ROOT/starship/starship.toml" "$TMP_CONFIG"
touch -t 202001010000 "$TMP_CONFIG"

run_shell() {
    HOME="$TMP_HOME" STARSHIP_CONFIG="$TMP_CONFIG" \
        zsh -i -c "source $REPO_ROOT/shells/zshrc; print -r -- ready" >/dev/null 2>&1
}

cache="$TMP_HOME/.cache/starship-init.zsh"

# 1) First run creates the cache.
[[ -f "$cache" ]] && rm -f "$cache"
run_shell
[[ -s "$cache" ]] || { echo "FAIL: cache not created on first run"; exit 1; }

# 2) Second run reuses it (mtime unchanged).
mtime1=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache")
sleep 1
run_shell
mtime2=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache")
if [[ "$mtime1" != "$mtime2" ]]; then
    echo "FAIL: cache regenerated on second run (config wasn't newer)"
    exit 1
fi

# 3) Touching the scratch toml makes the next run regenerate the cache.
sleep 1
touch "$TMP_CONFIG"
run_shell
mtime3=$(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache")
if [[ "$mtime3" -le "$mtime2" ]]; then
    echo "FAIL: touching the toml did not trigger regeneration"
    exit 1
fi

echo "OK"
