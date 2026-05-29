#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed"
  exit 0
fi

sample='{
  "workspace": { "current_dir": "/Users/luis/My Project" },
  "model": { "display_name": "Opus Test" },
  "context_window": {
    "current_usage": { "input_tokens": 123 },
    "context_window_size": 1000,
    "used_percentage": 12.3
  }
}'

assert_contains() {
  local haystack="$1"
  local needle="$2"
  case "$haystack" in
    *"$needle"*) ;;
    *)
      echo "missing expected output: $needle" >&2
      echo "$haystack" >&2
      exit 1
      ;;
  esac
}

bash_out=$(printf '%s' "$sample" | bash "$ROOT/claude/statusline-command.sh")
assert_contains "$bash_out" "My Project"
assert_contains "$bash_out" "Opus Test"
assert_contains "$bash_out" "123/1000 (12%)"

status_command=$(jq -r '.statusLine.command' "$ROOT/claude/settings.json")
expected_status_command="bash \"\$HOME/.claude/statusline-command.sh\""
if [ "$status_command" != "$expected_status_command" ]; then
  echo "unexpected statusLine.command: $status_command" >&2
  exit 1
fi
tmp_home=$(mktemp -d)
trap 'rm -rf "$tmp_home"' EXIT
mkdir -p "$tmp_home/.claude"
ln -s "$ROOT/claude/statusline-command.sh" "$tmp_home/.claude/statusline-command.sh"
configured_out=$(printf '%s' "$sample" | HOME="$tmp_home" bash -lc "$status_command")
assert_contains "$configured_out" "My Project"
assert_contains "$configured_out" "Opus Test"
assert_contains "$configured_out" "123/1000 (12%)"

if command -v pwsh >/dev/null 2>&1; then
  ps_out=$(printf '%s' "$sample" | pwsh -NoProfile -File "$ROOT/claude/statusline-command.ps1")
  assert_contains "$ps_out" "My Project"
  assert_contains "$ps_out" "Opus Test"
  assert_contains "$ps_out" "123/1000 (12%)"
else
  echo "SKIP: pwsh not installed"
fi
