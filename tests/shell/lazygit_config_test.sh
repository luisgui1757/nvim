#!/usr/bin/env bash
# Regression guard: lazygit/config.yml must use single-string bindings, not
# arrays. lazygit v0.58.x types moveDownCommit/moveUpCommit as `string`; an
# array (!!seq) here aborts lazygit with "cannot unmarshal !!seq into string"
# at every startup.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
CFG="$REPO_ROOT/lazygit/config.yml"

if ! command -v python3 >/dev/null 2>&1; then
    echo "skipped: python3 not installed"
    exit 0
fi

python3 - "$CFG" <<'PY'
import sys, yaml
with open(sys.argv[1]) as fh:
    cfg = yaml.safe_load(fh)
commits = (cfg or {}).get("keybinding", {}).get("commits", {})
bad = []
for key in ("moveDownCommit", "moveUpCommit"):
    val = commits.get(key)
    if val is not None and not isinstance(val, str):
        bad.append(f"{key}: {type(val).__name__} (expected str)")
if bad:
    sys.exit("FAIL: lazygit config bindings must be strings:\n  " + "\n  ".join(bad))
PY

echo "OK"
