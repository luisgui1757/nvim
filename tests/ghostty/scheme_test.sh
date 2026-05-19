#!/usr/bin/env bash
# Rose Pine consistency invariant: ghostty/config must declare the Rose Pine
# dark + dawn theme pair.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if ! grep -E "^theme\s*=\s*dark:Rose Pine,light:Rose Pine Dawn" "$REPO_ROOT/ghostty/config" >/dev/null; then
    echo "FAIL: ghostty/config does not declare the Rose Pine dark/dawn theme pair"
    exit 1
fi
echo "OK"
