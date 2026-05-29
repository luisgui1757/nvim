#!/usr/bin/env bash
# Regression guard: lazygit/config.yml must be parseable by lazygit v0.58.x.
# Two specific failure shapes we have hit and want pinned:
#   1) array-form values for fields lazygit types as Go string ("cannot
#      unmarshal !!seq into string").
#   2) keybinding values like <alt+j> or <a-j> which are NOT in
#      pkg/config/keynames.go LabelByKey; lazygit rejects them at startup
#      with "Unrecognized key".
#
# We strip YAML comments (everything from # to end of line) before grepping
# so the warnings in the config header do not trip the test.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CFG="$REPO_ROOT/lazygit/config.yml"

# Comment-stripped content (preserves line numbers for grep -n output).
stripped=$(sed -E 's/[[:space:]]*#.*$//' "$CFG")

fail=0
match() {
    local pattern=$1
    printf '%s\n' "$stripped" | grep -nE "$pattern" | grep -v '^[0-9]*:[[:space:]]*$' || true
}

# 1) No array form on string-typed fields.
hits=$(match '^[[:space:]]+(moveDownCommit|moveUpCommit|.*Commit):[[:space:]]*\[')
if [[ -n "$hits" ]]; then
    echo "FAIL: array form found on a lazygit string field"
    echo "$hits"
    fail=1
fi

# 2) Refuse the long modifier forms.
hits=$(match '<(alt|ctrl|shift|meta)\+')
if [[ -n "$hits" ]]; then
    echo "FAIL: <modifier+key> long form is rejected by lazygit v0.58"
    echo "$hits"
    fail=1
fi

# 3) Refuse Alt+letter (only <a-enter> is registered).
hits=$(match '<a-[a-z]>' | grep -v '<a-enter>' || true)
if [[ -n "$hits" ]]; then
    echo "FAIL: <a-LETTER> in config; lazygit v0.58 only registers <a-enter>"
    echo "$hits"
    fail=1
fi

[[ "$fail" -eq 0 ]] && echo "OK" || exit 1
