#!/usr/bin/env bash
# Regression guard for the VS Code Rose Pine theme setter in install-deps.sh.
# set_vscode_theme writes "workbench.colorTheme":"Rosé Pine" into settings.json,
# handling: absent/empty (fresh write), valid JSON (jq-merge preserving other
# keys), and JSONC-with-comments (left untouched -- never clobber user settings).
# The theme label has an accented e (U+00E9); we assert its UTF-8 bytes are
# present via $'\xc3\xa9' so the test never hardcodes the glyph.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# shellcheck disable=SC1090,SC1091  # dynamic path; shellcheck can't follow it
INSTALL_DEPS_SOURCE_ONLY=1 source "$REPO_ROOT/install-deps.sh"
set +e

fail() { echo "FAIL: $1"; exit 1; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
eacute=$'\xc3\xa9'   # UTF-8 bytes for é

# 1) Absent settings.json -> fresh file with the colorTheme key and the é byte.
s1="$WORK/a/settings.json"
set_vscode_theme "$s1" >/dev/null
[[ -f "$s1" ]] || fail "fresh settings.json was not created"
grep -q '"workbench.colorTheme"' "$s1" || fail "fresh file missing the colorTheme key"
grep -q "$eacute" "$s1" || fail "fresh theme value lost its é (UTF-8) byte"

# 2) Existing valid JSON -> merged, other keys preserved (needs jq).
if command -v jq >/dev/null 2>&1; then
    s2="$WORK/b/settings.json"; mkdir -p "$WORK/b"
    printf '{ "editor.fontSize": 14 }\n' > "$s2"
    set_vscode_theme "$s2" >/dev/null
    [[ "$(jq -r '."editor.fontSize"' "$s2")" == "14" ]] || fail "merge clobbered an existing key"
    [[ "$(jq -r '."workbench.colorTheme"' "$s2")" == Ros*" Pine" ]] || fail "merge did not set the theme"
    grep -q "$eacute" "$s2" || fail "merged theme lost its é byte"
fi

# 3) JSONC with comments -> left untouched (jq can't parse it; never clobber).
s3="$WORK/c/settings.json"; mkdir -p "$WORK/c"
printf '// my settings\n{ "editor.fontSize": 14 }\n' > "$s3"
before="$(cat "$s3")"
set_vscode_theme "$s3" >/dev/null
[[ "$(cat "$s3")" == "$before" ]] || fail "JSONC file was modified (must be left untouched)"

echo "OK"
