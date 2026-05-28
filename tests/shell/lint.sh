#!/usr/bin/env bash
# Shellcheck everything we ship as a script.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
cd "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "skipped: shellcheck not installed (brew install shellcheck)"
    exit 0
fi

# Gather .sh files (using process substitution into an array to stay
# bash 3.2 compatible — `mapfile` is bash 4+).
sh_files=()
while IFS= read -r f; do sh_files+=("$f"); done < <(
    find . -type f -name "*.sh" -not -path "./.git/*" -not -path "./tests/.cache/*"
)

shellcheck --shell=bash "${sh_files[@]}" || exit 1

# zshrc — best-effort under bash shell-check; warnings only.
shellcheck --shell=bash --severity=warning shells/zshrc || true

echo "lint OK"
