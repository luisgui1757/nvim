#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

(
    # shellcheck disable=SC1091
    INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"
    YES_ALL=0
    DRY_RUN=1
    exec 0<&-
    ask "anything?"
)

echo "OK"
