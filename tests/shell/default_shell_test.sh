#!/usr/bin/env bash
# Regression guard for install-deps.sh making zsh the LOGIN shell (chsh).
#
# For years we installed the zsh *binary* but never ran chsh, so on Linux the
# account stayed a bash login — tmux and every new terminal kept launching bash
# and the symlinked ~/.zshrc was never sourced. This pins set_default_shell_zsh's
# decision logic WITHOUT performing a real chsh: we source just the function
# defs (INSTALL_DEPS_SOURCE_ONLY) and stub the mutation seams, routing the
# pretend chsh to a temp file so its calls survive command-substitution.
#
# shellcheck disable=SC2329  # stub fns are invoked indirectly via the sourced
#                              set_default_shell_zsh, which shellcheck can't follow
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# shellcheck disable=SC1090,SC1091  # dynamic path; shellcheck can't follow it
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"
set +e   # the sourced script enables `set -e`; we test exit codes by hand

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
CHSH_LOG="$WORK/chsh"

fail() { echo "FAIL: $1"; exit 1; }
chsh_calls() { [[ -f "$CHSH_LOG" ]] && cat "$CHSH_LOG"; }
reset() { rm -f "$CHSH_LOG"; }

# Stub the real system-mutating seams. A "chsh" appends to $CHSH_LOG (a file,
# so it is observable even when the function runs inside $(...)).
ensure_in_etc_shells() { return 0; }
set_login_shell() { echo "chsh:$1" >>"$CHSH_LOG"; return 0; }
zsh_bin() { echo "/usr/bin/zsh"; }

# --- 1: zsh absent -> skip, never touch the login shell ----------------------
have() { return 1; }
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "zsh not installed" <<<"$out" || fail "missing-zsh did not skip cleanly: $out"
[[ -z "$(chsh_calls)" ]] || fail "missing-zsh ran chsh: $(chsh_calls)"

# zsh is 'installed' (and sudo 'available') for every scenario below.
have() { case "$1" in zsh|sudo) return 0 ;; *) command -v "$1" >/dev/null 2>&1 ;; esac; }

# --- 2: already on zsh -> no prompt, no chsh (macOS default + idempotent) -----
current_login_shell() { echo "/bin/zsh"; }
ask() { echo "ASK_CALLED"; return 0; }
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "already" <<<"$out" || fail "already-zsh did not report ok: $out"
grep -q "ASK_CALLED" <<<"$out" && fail "already-zsh prompted instead of no-op: $out"
[[ -z "$(chsh_calls)" ]] || fail "already-zsh ran chsh: $(chsh_calls)"

# --- 3: bash login + dry-run -> announce intent, but never chsh --------------
current_login_shell() { echo "/bin/bash"; }
ask() { return 0; }
reset
out="$(DRY_RUN=1 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "would" <<<"$out" || fail "dry-run did not print a 'would' line: $out"
[[ -z "$(chsh_calls)" ]] || fail "dry-run performed a real chsh: $(chsh_calls)"

# --- 4: bash login + real run + consent -> chsh to the resolved zsh path -----
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
[[ "$(chsh_calls)" == "chsh:/usr/bin/zsh" ]] \
    || fail "real run did not chsh to zsh (log='$(chsh_calls)', out='$out')"

# --- 5: bash login + decline -> no chsh, warns about tmux/terminals ----------
ask() { return 1; }
reset
out="$(DRY_RUN=0 YES_ALL=0 set_default_shell_zsh 2>&1)"
[[ -z "$(chsh_calls)" ]] || fail "declined still ran chsh: $(chsh_calls)"
grep -qi "kept" <<<"$out" || fail "declined did not report keeping current shell: $out"

echo "OK"
