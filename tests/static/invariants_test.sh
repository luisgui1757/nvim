#!/usr/bin/env bash
# Cross-cutting invariants. These catch regressions that aren't bound to a
# single file's spec — bugs that could re-appear if someone copy-pastes from
# an old commit or AI-generates similar code.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$REPO_ROOT"

fail=0
check_absent() {
    local desc="$1" pattern="$2"; shift 2
    if grep -rE --binary-files=without-match "$pattern" "$@" >/dev/null 2>&1; then
        echo "FAIL: $desc — pattern '$pattern' still appears:"
        grep -rnE --binary-files=without-match "$pattern" "$@" | head -5
        fail=1
    else
        echo "ok  : $desc"
    fi
}

check_absent "NODE_TLS_REJECT_UNAUTHORIZED gone (security)" \
    "NODE_TLS_REJECT_UNAUTHORIZED" \
    --exclude-dir=.git --exclude-dir=claude --exclude-dir=.claude \
    --exclude-dir=tests \
    .

check_absent "vim.loop replaced by vim.uv (deprecation)" \
    "vim\\.loop\\." \
    --exclude-dir=.git --exclude-dir=tests \
    nvim/

check_absent "client.supports_method dot-call replaced (0.11)" \
    "client\\.supports_method" \
    --exclude-dir=.git --exclude-dir=tests \
    nvim/

check_absent "starship literal '(style)' typo gone" \
    "\\]\\(style\\)" \
    --exclude-dir=.git --exclude-dir=tests \
    starship/

check_absent "bare-Esc kill-whole-line bindkey gone (Meta prefix shadow)" \
    "bindkey[[:space:]]+'\\\\e'[[:space:]]+kill-whole-line" \
    --exclude-dir=.git --exclude-dir=tests \
    shells/

# Lazy-load discipline: only rose-pine should be lazy=false
nonlazy=$(grep -lE "lazy[[:space:]]*=[[:space:]]*false" nvim/lua/plugins/*.lua 2>/dev/null | grep -v rose-pine.lua || true)
if [[ -n "$nonlazy" ]]; then
    echo "FAIL: only rose-pine should be lazy=false. Offenders:"
    echo "$nonlazy"
    fail=1
else
    echo "ok  : lazy-load discipline (only rose-pine is lazy=false)"
fi

# Rose-pine must keep priority = 1000 so it loads before any plugin renders
# (without it, you get a brief flash of default colorscheme on startup).
if ! grep -E "priority[[:space:]]*=[[:space:]]*1000" nvim/lua/plugins/rose-pine.lua >/dev/null; then
    echo "FAIL: rose-pine.lua must keep priority = 1000"
    fail=1
else
    echo "ok  : rose-pine.lua has priority = 1000"
fi

# Lazy-lock must not contain references to removed plugins.
for stale in mason-lspconfig.nvim none-ls.nvim CopilotChat.nvim copilot.vim nui.nvim; do
    if grep -q "\"$stale\"" nvim/lazy-lock.json 2>/dev/null; then
        echo "FAIL: lazy-lock.json still references removed plugin '$stale'"
        fail=1
    fi
done

# Dead-code guards
for dead in nvim/lua/plugins.lua nvim/lua/plugins/ai.lua nvim/lua/plugins/avante.lua nvim/lua/plugins/none-ls.lua; do
    if [[ -e "$dead" ]]; then
        echo "FAIL: $dead should be deleted"
        fail=1
    fi
done
[[ "$fail" -eq 0 ]] && echo "ok  : dead-code files gone"

[[ "$fail" -eq 0 ]] || exit 1
echo "all invariants OK"
