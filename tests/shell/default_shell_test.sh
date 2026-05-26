#!/usr/bin/env bash
# Regression guard for install-deps.sh making zsh the interactive shell.
#
# For years we installed the zsh *binary* but never adopted it, so on Linux the
# account stayed a bash login -- tmux/new terminals launched bash and the
# symlinked ~/.zshrc was never sourced. Two account types need two strategies:
#   - LOCAL accounts -> chsh (edits /etc/passwd)
#   - DOMAIN accounts (AD/LDAP via SSSD; not in /etc/passwd) -> chsh fails, so
#     re-exec interactive bash into zsh via ~/.bashrc instead.
# This pins the decision logic WITHOUT a real chsh or editing real dotfiles: we
# source just the function defs (INSTALL_DEPS_SOURCE_ONLY) and stub the seams,
# routing the pretend mutations to temp files so they survive the $(...) subshell.
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
EXEC_LOG="$WORK/execzsh"

fail() { echo "FAIL: $1"; exit 1; }
chsh_calls() { [[ -f "$CHSH_LOG" ]] && cat "$CHSH_LOG"; }
exec_calls() { [[ -f "$EXEC_LOG" ]] && cat "$EXEC_LOG"; }
reset() { rm -f "$CHSH_LOG" "$EXEC_LOG"; }

# Force the Linux code path (so the domain branch is reachable on any host) and
# stub every system-mutating seam. chsh / exec-guard writes go to files so they
# survive the $(...) subshell the function under test runs in.
uname() { echo "Linux"; }
is_local_account() { return 0; }                  # local account by default
ensure_in_etc_shells() { return 0; }
set_login_shell() { echo "chsh:$1" >>"$CHSH_LOG"; return 0; }
ensure_bash_execs_zsh() { echo "execzsh" >>"$EXEC_LOG"; return 0; }
zsh_bin() { echo "/usr/bin/zsh"; }

# --- 1: zsh absent -> skip, touch nothing ------------------------------------
have() { return 1; }
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "zsh not installed" <<<"$out" || fail "missing-zsh did not skip cleanly: $out"
[[ -z "$(chsh_calls)$(exec_calls)" ]] || fail "missing-zsh mutated something"

# zsh 'installed' (and sudo 'available') for every scenario below.
have() { case "$1" in zsh|sudo) return 0 ;; *) command -v "$1" >/dev/null 2>&1 ;; esac; }

# --- 2: already on zsh -> no prompt, no mutation (macOS default + idempotent) -
current_login_shell() { echo "/bin/zsh"; }
ask() { echo "ASK_CALLED"; return 0; }
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "already" <<<"$out" || fail "already-zsh did not report ok: $out"
grep -q "ASK_CALLED" <<<"$out" && fail "already-zsh prompted instead of no-op: $out"
[[ -z "$(chsh_calls)$(exec_calls)" ]] || fail "already-zsh mutated something"

# ===== LOCAL account -> chsh path ============================================
current_login_shell() { echo "/bin/bash"; }
is_local_account() { return 0; }

# 3: dry-run -> announce chsh, mutate nothing
ask() { return 0; }
reset
out="$(DRY_RUN=1 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "would.*chsh" <<<"$out" || fail "local dry-run did not print a chsh 'would': $out"
[[ -z "$(chsh_calls)$(exec_calls)" ]] || fail "local dry-run mutated something"

# 4: real + consent -> chsh to the resolved zsh path, no bash fallback
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
[[ "$(chsh_calls)" == "chsh:/usr/bin/zsh" ]] || fail "local real run did not chsh to zsh (log='$(chsh_calls)')"
[[ -z "$(exec_calls)" ]] || fail "local run used the bash-exec fallback instead of chsh"

# 5: decline -> no chsh, reports keeping the current shell
ask() { return 1; }
reset
out="$(DRY_RUN=0 YES_ALL=0 set_default_shell_zsh 2>&1)"
[[ -z "$(chsh_calls)" ]] || fail "declined still ran chsh"
grep -qi "kept" <<<"$out" || fail "declined did not report keeping current shell: $out"

# ===== DOMAIN account -> exec-zsh fallback (the company-machine bug) ==========
is_local_account() { return 1; }     # not in /etc/passwd -> chsh would fail

# 6: real + consent -> install the bash exec-zsh guard, NEVER chsh
ask() { return 0; }
reset
out="$(DRY_RUN=0 YES_ALL=1 set_default_shell_zsh 2>&1)"
[[ -n "$(exec_calls)" ]] || fail "domain run did not install the exec-zsh fallback: $out"
[[ -z "$(chsh_calls)" ]] || fail "domain run ran chsh (it would fail on a domain account)"
grep -qi "domain" <<<"$out" || fail "domain run did not explain why chsh is skipped: $out"

# 7: dry-run -> announce the ~/.bashrc edit, mutate nothing
reset
out="$(DRY_RUN=1 YES_ALL=1 set_default_shell_zsh 2>&1)"
grep -qi "would.*bashrc" <<<"$out" || fail "domain dry-run did not announce the ~/.bashrc edit: $out"
[[ -z "$(chsh_calls)$(exec_calls)" ]] || fail "domain dry-run mutated something"

echo "OK"
