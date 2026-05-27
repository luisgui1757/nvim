#!/usr/bin/env bash
# Regression guard for the notes/Obsidian vault prompt in install-deps.sh.
# obsidian.nvim reads $NOTES_VAULT; install-deps persists the user's answer to
# ~/.zshrc.local (which shells/zshrc sources). The prompt itself is tty-gated,
# so persist_notes_vault is split out and tested directly here.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# shellcheck disable=SC1090,SC1091  # dynamic path; shellcheck can't follow it
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"
set +e   # the sourced script enables `set -e`; we assert by hand

fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# 1) Absolute path (with a space) -> written to ~/.zshrc.local, dir created, and
#    the written line round-trips back to the exact path through a shell.
HOME="$WORK/h1"; mkdir -p "$HOME"
resolved="$(persist_notes_vault "$WORK/vault one")"
[[ "$resolved" == "$WORK/vault one" ]] || fail "persist did not echo the resolved path: '$resolved'"
[[ -d "$WORK/vault one" ]] || fail "vault dir (with space) was not created"
grep -q '^export NOTES_VAULT=' "$HOME/.zshrc.local" || fail "NOTES_VAULT not written to ~/.zshrc.local"
got="$(HOME="$HOME" bash -c 'source "$HOME/.zshrc.local"; printf %s "${NOTES_VAULT:-}"')"
[[ "$got" == "$WORK/vault one" ]] || fail "NOTES_VAULT did not round-trip through a shell (got: '$got')"

# 2) A leading ~ is expanded to $HOME (passing a literal tilde on purpose).
HOME="$WORK/h2"; mkdir -p "$HOME"
# shellcheck disable=SC2088  # intentionally a literal ~, simulating typed input
resolved="$(persist_notes_vault "~/notes-x")"
[[ "$resolved" == "$HOME/notes-x" ]] || fail "leading ~ was not expanded (got: '$resolved')"

echo "OK"
