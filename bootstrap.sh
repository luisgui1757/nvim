#!/usr/bin/env bash
# bootstrap.sh — symlink dotfiles into OS-appropriate paths.
# Supported: macOS (Darwin), native Linux, WSL (Microsoft kernel under Linux).
# Idempotent: re-running produces zero diffs.
#
# Usage:
#   ./bootstrap.sh           # install / re-install symlinks
#   ./bootstrap.sh --dry-run # print planned actions, change nothing

set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Pick a collision-free backup path: if .bak.<timestamp> already exists,
# append .1, .2, … until we find an unused name.
unique_backup() {
    local base="$1"
    if [[ ! -e "$base" ]]; then printf '%s' "$base"; return; fi
    local i=1
    while [[ -e "${base}.${i}" ]]; do i=$((i + 1)); done
    printf '%s' "${base}.${i}"
}

# ---- OS detection ------------------------------------------------------------
detect_os() {
    case "$(uname -s)" in
        Darwin)
            echo macos ;;
        Linux)
            if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
                echo wsl
            else
                echo linux
            fi ;;
        *) echo unknown ;;
    esac
}

OS="$(detect_os)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# ---- Preflight ---------------------------------------------------------------
require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "bootstrap: required command '$1' not on PATH" >&2
        exit 1
    fi
}
require_cmd ln
require_cmd readlink
require_cmd git

echo "bootstrap: OS=$OS repo=$REPO_ROOT dry-run=$DRY_RUN"
echo

# ---- Link primitives ---------------------------------------------------------
# Create a symlink at $2 → $1. If $2 already exists:
#   - if it's the correct symlink: no-op.
#   - if it's a different symlink or a regular file: back it up to
#     <target>.bak.<timestamp> and replace.
link() {
    local src="$1" dst="$2"

    # Ensure parent dir exists
    local parent
    parent="$(dirname "$dst")"
    if [[ ! -d "$parent" ]]; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  mkdir -p  $parent"
        else
            mkdir -p "$parent"
        fi
    fi

    if [[ -L "$dst" ]]; then
        local current
        current="$(readlink "$dst")"
        if [[ "$current" == "$src" ]]; then
            echo "  ok        $dst → $src"
            return 0
        fi
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  relink    $dst (was → $current)"
        else
            ln -sfn "$src" "$dst"
            echo "  relinked  $dst → $src"
        fi
        return 0
    fi

    if [[ -e "$dst" ]]; then
        local backup
        backup="$(unique_backup "${dst}.bak.${TIMESTAMP}")"
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  backup    $dst → $backup; then symlink"
        else
            mv "$dst" "$backup"   # mv -n would still race; unique_backup is the guarantee
            ln -s "$src" "$dst"
            echo "  backed up $dst → $backup; linked → $src"
        fi
        return 0
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  link      $dst → $src"
    else
        ln -s "$src" "$dst"
        echo "  linked    $dst → $src"
    fi
}

# ---- Universal links (mac + linux + wsl) -------------------------------------
NVIM_DEST="${HOME}/.config/nvim"
link "${REPO_ROOT}/nvim"                "${NVIM_DEST}"
link "${REPO_ROOT}/starship/starship.toml" "${HOME}/.config/starship.toml"
link "${REPO_ROOT}/tmux/tmux.conf"      "${HOME}/.tmux.conf"
link "${REPO_ROOT}/shells/zshrc"        "${HOME}/.zshrc"

# ---- OS-specific links -------------------------------------------------------
case "$OS" in
    macos)
        link "${REPO_ROOT}/ghostty/config" \
             "${HOME}/Library/Application Support/com.mitchellh.ghostty/config"
        ;;
    linux)
        link "${REPO_ROOT}/ghostty/config" "${HOME}/.config/ghostty/config"
        ;;
    wsl)
        # No Ghostty on WSL today; nothing extra to link.
        echo "  note      WSL detected; Windows Terminal fragment must be merged manually"
        echo "            see windows-terminal/README.md"
        ;;
    *)
        echo "  warn      unknown OS; skipping terminal-specific links" >&2
        ;;
esac

# ---- Optional: install pwsh profile if pwsh is on PATH -----------------------
if command -v pwsh >/dev/null 2>&1; then
    # Resolve $PROFILE for pwsh (works on mac/linux too).
    # shellcheck disable=SC2016  # single quotes intentional — $PROFILE is a PowerShell variable
    if PROFILE_PATH=$(pwsh -NoProfile -Command 'Write-Output $PROFILE' 2>/dev/null); then
        PROFILE_PATH="$(echo "$PROFILE_PATH" | tr -d '\r')"
        if [[ -n "$PROFILE_PATH" ]]; then
            link "${REPO_ROOT}/shells/powershell_profile.ps1" "$PROFILE_PATH"
        fi
    fi
fi

echo
echo "bootstrap: done"
if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "(dry run — no changes were made)"
fi
