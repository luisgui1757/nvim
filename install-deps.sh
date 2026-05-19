#!/usr/bin/env bash
# install-deps.sh -- interactively install dependencies on macOS / Linux / WSL.
#
# Usage:
#   ./install-deps.sh           prompt Y/n for each tool
#   ./install-deps.sh --all     skip prompts, install everything
#   ./install-deps.sh --dry-run print what would be installed without acting

set -euo pipefail

YES_ALL=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --all|-y)   YES_ALL=1 ;;
        --dry-run)  DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# ---- OS / package-manager detection ------------------------------------------
# Preference order:
#   macOS: brew always
#   Linux: brew (if installed) -> apt/dnf/pacman/zypper/apk
# Brew on Linux (Linuxbrew) is preferred when present because it carries
# tools that apt either lacks (taplo, hyperfine, editorconfig-checker) or
# ships in a stale version (neovim 0.7 on Ubuntu 22.04 LTS, etc.).
detect_pm() {
    if command -v brew >/dev/null 2>&1; then echo brew; return; fi
    if [[ "$(uname -s)" == "Darwin" ]]; then echo brew_missing; return; fi
    if [[ "$(uname -s)" == "Linux" ]]; then
        if   command -v apt-get >/dev/null 2>&1; then echo apt
        elif command -v dnf     >/dev/null 2>&1; then echo dnf
        elif command -v pacman  >/dev/null 2>&1; then echo pacman
        elif command -v zypper  >/dev/null 2>&1; then echo zypper
        elif command -v apk     >/dev/null 2>&1; then echo apk
        else echo unknown
        fi
        return
    fi
    echo unknown
}

# ---- Homebrew bootstrap ------------------------------------------------------
# If brew is missing on either mac or Linux, offer to install it. On mac
# it is the ONLY sane option; on Linux it unlocks the same package set
# the mac side uses (taplo, hyperfine, ghostty, etc.).
maybe_install_brew() {
    if command -v brew >/dev/null 2>&1; then return 0; fi
    local kind
    if [[ "$(uname -s)" == "Darwin" ]]; then kind="required (no other package manager on macOS)"
    else kind="recommended (unlocks taplo / hyperfine / ghostty etc. that apt does not carry)"
    fi
    echo "Homebrew is not installed. $kind."
    if ask "Install Homebrew via the official installer?"; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  would: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # Plumb brew into THIS shell so subsequent installs use it.
            if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
            elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
            fi
        fi
        return 0
    fi
    return 1
}

is_wsl() {
    grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null
}

PM="$(detect_pm)"
OS_LABEL="$(uname -s)"
if is_wsl; then OS_LABEL="WSL ($OS_LABEL)"; fi

# Bootstrap brew if asked. Re-detect after.
if [[ "$PM" == "brew_missing" ]]; then
    if maybe_install_brew; then PM="$(detect_pm)"
    else PM="unknown"; fi
elif [[ "$PM" != "brew" && "$(uname -s)" == "Linux" ]]; then
    # Linux user without brew — offer to install it so they get the wider catalog.
    echo "Detected $PM as the system package manager."
    if maybe_install_brew; then PM="$(detect_pm)"; fi
fi

if [[ "$PM" == "unknown" ]]; then
    echo "install-deps: no supported package manager found." >&2
    echo "  Supported: brew (mac/Linux), apt (Debian/Ubuntu), dnf (Fedora), pacman (Arch), zypper (openSUSE), apk (Alpine)." >&2
    exit 1
fi

echo "install-deps: OS=$OS_LABEL  package manager=$PM  dry-run=$DRY_RUN  yes-all=$YES_ALL"
echo

# ---- Helpers -----------------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

ask() {
    local prompt="$1"
    if [[ "$YES_ALL" -eq 1 ]]; then return 0; fi
    printf "  %s [Y/n] " "$prompt"
    local answer
    if ! read -r answer; then return 1; fi
    answer="${answer:-y}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

pm_install() {
    local pkgs=("$@")
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would: $PM install ${pkgs[*]}"; return 0
    fi
    case "$PM" in
        brew)   brew install "${pkgs[@]}" ;;
        apt)    sudo apt-get update -qq && sudo apt-get install -y "${pkgs[@]}" ;;
        dnf)    sudo dnf install -y "${pkgs[@]}" ;;
        pacman) sudo pacman -S --noconfirm "${pkgs[@]}" ;;
        zypper) sudo zypper install -y "${pkgs[@]}" ;;
        apk)    sudo apk add "${pkgs[@]}" ;;
    esac
}

# `install <check-binary> <package-name-per-pm-or-empty> [purpose-string]`
# Looks up the package name from a table per pm. Use empty string to use
# the check-binary name as the package name on all pms.
declare -A APT_NAMES=(
    [nvim]=neovim
    [rg]=ripgrep
    [fd]=fd-find
    [pwsh]="" # not in apt; user must install separately
    [bats]=bats
    [taplo]="" # not in apt
    [hyperfine]=hyperfine
    [editorconfig-checker]="" # not in apt
    [yamllint]=yamllint
    [win32yank.exe]="" # WSL: install separately
    [xclip]=xclip
    [wl-copy]=wl-clipboard
    [zsh]=zsh
    [tmux]=tmux
    [git]=git
    [make]=make
    [shellcheck]=shellcheck
    [jq]=jq
    [starship]="" # install via curl script below
    [ghostty]="" # not in apt repos
)
declare -A BREW_NAMES=(
    [nvim]=neovim
    [rg]=ripgrep
    [fd]=fd
    [pwsh]="powershell --cask"
    [bats]=bats-core
    [taplo]=taplo
    [hyperfine]=hyperfine
    [editorconfig-checker]=editorconfig-checker
    [yamllint]=yamllint
    [xclip]=""
    [wl-copy]=""
    [zsh]=zsh
    [tmux]=tmux
    [git]=git
    [make]=make
    [shellcheck]=shellcheck
    [jq]=jq
    [starship]=starship
    [ghostty]="ghostty --cask"
)

pkg_for() {
    local tool="$1"
    case "$PM" in
        brew)   echo "${BREW_NAMES[$tool]-$tool}" ;;
        apt)    echo "${APT_NAMES[$tool]-$tool}" ;;
        *)      echo "$tool" ;;  # pacman/dnf usually match upstream names
    esac
}

install() {
    local tool="$1" purpose="${2:-}"
    if have "$tool"; then
        printf "  ok        %-26s already installed\n" "$tool"
        return
    fi
    local pkg
    pkg="$(pkg_for "$tool")"
    if [[ -z "$pkg" ]]; then
        printf "  skipped   %-26s not in %s repos; install manually\n" "$tool" "$PM"
        return
    fi
    if ask "Install $tool${purpose:+ ($purpose)}?"; then
        # shellcheck disable=SC2086  # $pkg may contain --cask flags
        pm_install $pkg || echo "  WARN: $tool install failed; continuing"
    else
        printf "  skipped   %-26s\n" "$tool"
    fi
}

# Starship has its own one-liner installer on Linux (apt doesn't carry it).
install_starship_curl() {
    if have starship; then
        printf "  ok        %-26s already installed\n" "starship"
        return
    fi
    if ask "Install starship (prompt) via official curl installer?"; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  would: curl -sS https://starship.rs/install.sh | sh -s -- -y"
        else
            curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi
    else
        printf "  skipped   %-26s\n" "starship"
    fi
}

install_nerd_font() {
    # Already installed?
    if fc-list 2>/dev/null | grep -qi "hack.*nerd"; then
        printf "  ok        %-26s already installed\n" "Hack Nerd Font"
        return
    fi
    # On macOS prefer the cask (handles user vs system font dirs + cache).
    if [[ "$PM" == "brew" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
        if ask "Install Hack Nerd Font (used by ghostty / Windows Terminal)?"; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "  would: brew install --cask font-hack-nerd-font"
            else
                brew install --cask font-hack-nerd-font
            fi
        fi
        return
    fi
    # Linux (and Linuxbrew on Linux, which has no font cask): download
    # release zip -> extract to user font dir -> fc-cache.
    if ! ask "Install Hack Nerd Font (download + extract to user font dir)?"; then
        printf "  skipped   %-26s\n" "Hack Nerd Font"
        return
    fi
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would: curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"
        echo "         unzip -> \${XDG_DATA_HOME:-\$HOME/.local/share}/fonts/HackNerdFont/"
        echo "         fc-cache -f"
        return
    fi
    local font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts/HackNerdFont"
    local tmp
    tmp="$(mktemp -d)"
    if ! curl -fL -o "$tmp/Hack.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"; then
        echo "  FAIL: download failed; install Hack Nerd Font manually from nerd-fonts releases"
        rm -rf "$tmp"; return
    fi
    mkdir -p "$font_dir"
    if command -v unzip >/dev/null 2>&1; then
        unzip -oq "$tmp/Hack.zip" -d "$font_dir"
    else
        # apk/alpine and some minimal images skip unzip; try bsdtar.
        if command -v bsdtar >/dev/null 2>&1; then
            bsdtar -xf "$tmp/Hack.zip" -C "$font_dir"
        else
            echo "  FAIL: need 'unzip' or 'bsdtar' to extract the font archive"
            rm -rf "$tmp"; return
        fi
    fi
    rm -rf "$tmp"
    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$(dirname "$font_dir")" >/dev/null 2>&1 || true
    fi
    printf "  installed %-26s -> %s\n" "Hack Nerd Font" "$font_dir"
}

# Try to install Ghostty on Linux via snap; otherwise print build/source hint.
install_ghostty_linux() {
    if have ghostty; then
        printf "  ok        %-26s already installed\n" "ghostty"
        return
    fi
    # On Linux brew we have a (head-only) ghostty formula.
    if [[ "$PM" == "brew" ]]; then
        if ask "Install ghostty (HEAD build from brew)?"; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "  would: brew install --HEAD ghostty"
            else
                brew install --HEAD ghostty || echo "  WARN: brew HEAD build failed; build from source instead"
            fi
        fi
        return
    fi
    # Snap is available on most Ubuntu/Debian/Fedora desktops.
    if command -v snap >/dev/null 2>&1; then
        if ask "Install ghostty via snap (community package)?"; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "  would: sudo snap install ghostty --classic"
            else
                sudo snap install ghostty --classic || \
                    echo "  WARN: snap install failed; the snap may have changed names"
            fi
            return
        fi
    fi
    # Last resort: build instructions.
    echo "  manual    ghostty has no native $PM package. Options:"
    echo "              - snap:  sudo snap install ghostty --classic  (if snapd is set up)"
    echo "              - flatpak: search 'ghostty' on flathub"
    echo "              - source build with Zig:  https://ghostty.org/docs/install/build"
}

# ---- Sections ----------------------------------------------------------------
section() { echo; echo "== $1 =="; }

section "core editor stack"
install git "version control, required by lazy.nvim"
install nvim "Neovim 0.11+, the editor"
install make "needed for some plugin builds (notably LuaSnip jsregexp)"
install rg "ripgrep, powers Telescope live_grep"
install fd "fd, powers Telescope find_files"

section "prompt"
if [[ "$PM" == "brew" ]]; then
    install starship
else
    install_starship_curl
fi

section "terminal multiplexer + shell"
install tmux
install zsh

section "terminals (optional)"
if [[ "$(uname -s)" == "Darwin" ]] && [[ "$PM" == "brew" ]]; then
    install ghostty "macOS terminal, our daily driver"
elif [[ "$(uname -s)" == "Linux" ]]; then
    install_ghostty_linux
fi

section "fonts"
install_nerd_font

section "language tooling (for LSP / formatter back-ends)"
install python3 "needed by pyright"
install node "needed by prettier, markdown-preview"

if is_wsl; then
    section "WSL clipboard bridge"
    echo "  manual    win32yank.exe (Windows side):"
    echo "            scoop install win32yank   (PowerShell on Windows)"
    echo "            or download from https://github.com/equalsraf/win32yank/releases"
    echo "            Then ensure it is on the WSL PATH."
elif [[ "$(uname -s)" == "Linux" ]]; then
    section "Linux clipboard helpers"
    install xclip "X11 clipboard"
    install wl-copy "Wayland clipboard"
fi

section "developer / test dependencies (optional)"
install shellcheck "shell script linter"
install jq "JSON CLI, used by claude/statusline-command.sh"
install bats "bats-core, for tests/bootstrap/sh_test.bats"
install hyperfine "starship prompt perf test"
install taplo "TOML linter"
install yamllint "YAML linter"
install editorconfig-checker

echo
echo "install-deps: done"
if [[ "$DRY_RUN" -eq 1 ]]; then echo "(dry run -- nothing was installed)"; fi
echo
echo "Next: run ./bootstrap.sh to symlink configs into place."
