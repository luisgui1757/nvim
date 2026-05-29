#!/usr/bin/env bash
# Regression guard: lazygit/config.yml must use single-string bindings, not
# arrays. lazygit v0.58.x types moveDownCommit/moveUpCommit as Go `string`;
# an array (!!seq) here aborts lazygit with "cannot unmarshal !!seq into
# string" at every startup.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CFG="$REPO_ROOT/lazygit/config.yml"

fail=0
for key in moveDownCommit moveUpCommit; do
    line=$(grep -E "^\s*${key}:" "$CFG" || true)
    if [[ -z "$line" ]]; then continue; fi
    # An array-form value contains a `[` somewhere in the value position.
    if [[ "$line" == *"["* ]]; then
        echo "FAIL: $key uses array form; lazygit rejects with 'cannot unmarshal !!seq into string'"
        echo "      $line"
        fail=1
    fi
    # lazygit v0.58 uses the short modifier form with DASH separator
    # (<a-LETTER>, <c-LETTER>). The long form with plus (<alt+LETTER>,
    # <ctrl+LETTER>) is master-only and v0.58 rejects it as
    # "Unrecognized key". Refuse the long form.
    if grep -Eq "<(alt|ctrl|shift|meta)\+" <<<"$line"; then
        echo "FAIL: $key uses <modifier+key> long form; lazygit v0.58 needs <a-key>/<c-key> short form"
        echo "      $line"
        fail=1
    fi
done

[[ "$fail" -eq 0 ]] && echo "OK" || exit 1
