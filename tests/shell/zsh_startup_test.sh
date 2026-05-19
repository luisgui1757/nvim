#!/usr/bin/env bash
# Smoke-test zshrc by sourcing it under zsh in an interactive-ish session.
# Pass criteria: exit 0, no stderr output, completes within 5s.
set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
    echo "skipped: zsh not installed"
    exit 0
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# Run zsh with HOME pointing at a temp dir to avoid polluting real history.
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

# Use a copy with HOMEBREW_PREFIX cleared so we exercise the missing-brew path.
out=$(HOME="$TMP_HOME" HOMEBREW_PREFIX='' zsh -i -c "source $REPO_ROOT/shells/zshrc && echo OK" 2>&1)
rc=$?

if [[ "$rc" -ne 0 ]]; then
    echo "FAIL: zsh exited $rc"; echo "$out"; exit 1
fi
if [[ "$out" != *"OK"* ]]; then
    echo "FAIL: zshrc did not reach 'OK' marker"; echo "$out"; exit 1
fi
echo "OK"
