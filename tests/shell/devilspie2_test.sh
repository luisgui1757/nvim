#!/usr/bin/env bash
# Regression guard for the GNOME/X11 Ghostty-maximize setup (devilspie2).
# The runtime behavior (Mutter ignoring `maximize = true`) can't be tested in
# CI, so this pins the pieces: the rule file exists and matches Ghostty's
# WM_CLASS + calls maximize(), and install-deps wires the opt-in setup.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
fail() { echo "FAIL: $1"; exit 1; }

rule="$REPO_ROOT/linux/devilspie2/ghostty-maximize.lua"
[[ -f "$rule" ]] || fail "devilspie2 rule file missing: $rule"
grep -q "com.mitchellh.ghostty" "$rule" || fail "rule does not match Ghostty's WM_CLASS (com.mitchellh.ghostty)"
grep -q "maximize()" "$rule" || fail "rule does not call maximize()"

# install-deps must define AND call the opt-in setup.
grep -q '^setup_ghostty_maximize()' "$REPO_ROOT/install-deps.sh" || fail "setup_ghostty_maximize() not defined in install-deps.sh"
grep -qE '^setup_ghostty_maximize($|[[:space:]])' "$REPO_ROOT/install-deps.sh" \
    || fail "setup_ghostty_maximize is never called in install-deps.sh"

echo "OK"
