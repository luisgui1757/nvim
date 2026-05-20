#!/usr/bin/env bash
# install-deps.sh -- interactively install dependencies on macOS / Linux / WSL.
#
# Designed to work on STOCK BASH 3.2 (macOS default) -- no associative
# arrays, no mapfile, no namerefs, no ${var,,}. Tested under bash 3.2.57
# and bash 5.2.
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
            sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# ---- Bash 3.2-safe helpers ---------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
have_any() {
    local b
    for b in "$@"; do
        if command -v "$b" >/dev/null 2>&1; then return 0; fi
    done
    return 1
}
# Some tools install under a different binary name on certain distros
# (Debian/Ubuntu ship fd-find as `fdfind`). Map tool -> space-separated list
# of binaries to accept as "installed".
binaries_for() {
    case "$1" in
        fd)       echo "fd fdfind" ;;
        wl-copy)  echo "wl-copy wl-paste" ;;
        *)        echo "$1" ;;
    esac
}
is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; }

# ask MUST be defined before maybe_install_brew uses it.
ask() {
    local prompt="$1"
    if [[ "$YES_ALL" -eq 1 ]]; then return 0; fi
    printf "  %s [Y/n] " "$prompt"
    local answer
    if ! read -r answer; then return 1; fi
    answer="${answer:-y}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# sudo if needed, root-tolerant, container-tolerant. Echo to stderr when
# sudo is missing AND we're not root so the user knows why a step skipped.
maybe_sudo() {
    if [[ "$(id -u 2>/dev/null || echo 0)" -eq 0 ]]; then
        "$@"; return $?
    fi
    if have sudo; then
        sudo "$@"; return $?
    fi
    echo "  WARN: sudo not found and not running as root; skipping: $*" >&2
    return 1
}

# ---- OS / package-manager detection ------------------------------------------
detect_pm() {
    if have brew; then echo brew; return; fi
    if [[ "$(uname -s)" == "Darwin" ]]; then echo brew_missing; return; fi
    if [[ "$(uname -s)" == "Linux" ]]; then
        if   have apt-get; then echo apt
        elif have dnf;     then echo dnf
        elif have pacman;  then echo pacman
        elif have zypper;  then echo zypper
        elif have apk;     then echo apk
        else echo unknown
        fi
        return
    fi
    echo unknown
}

# ---- Homebrew bootstrap ------------------------------------------------------
maybe_install_brew() {
    if have brew; then return 0; fi
    local kind
    if [[ "$(uname -s)" == "Darwin" ]]; then
        kind="required (no other package manager on macOS)"
    else
        kind="recommended (unlocks taplo / hyperfine / ghostty etc. that apt does not carry)"
    fi
    echo "Homebrew is not installed. $kind."
    if ask "Install Homebrew via the official installer?"; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  would: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            return 1
        fi
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
        # Plumb brew into THIS shell so subsequent installs use it.
        if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew    ]]; then eval "$(/usr/local/bin/brew shellenv)"
        elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
        return 0
    fi
    return 1
}

PM="$(detect_pm)"
OS_LABEL="$(uname -s)"
if is_wsl; then OS_LABEL="WSL ($OS_LABEL)"; fi

# Bootstrap brew if asked. Re-detect after.
if [[ "$PM" == "brew_missing" ]]; then
    if maybe_install_brew; then PM="$(detect_pm)"
    else PM="unknown"; fi
elif [[ "$PM" != "brew" && "$(uname -s)" == "Linux" ]]; then
    echo "Detected $PM as the system package manager."
    if maybe_install_brew; then PM="$(detect_pm)"; fi
fi

if [[ "$PM" == "unknown" ]]; then
    echo "install-deps: no supported package manager found." >&2
    echo "  Supported: brew (mac/Linux), apt (Debian/Ubuntu), dnf (Fedora)," >&2
    echo "             pacman (Arch), zypper (openSUSE), apk (Alpine)." >&2
    exit 1
fi

echo "install-deps: OS=$OS_LABEL  package manager=$PM  dry-run=$DRY_RUN  yes-all=$YES_ALL"
echo

# ---- Package-name resolution (Bash 3.2-safe, no associative arrays) ----------
#
# Table format: lines of "tool|brew|apt|dnf|pacman|zypper|apk".
# Empty field == "not available in that PM, will fall through to manual hint".
# A leading "-" on a field marks it as flag-bearing (e.g. "-cask font-…" for brew).
#
# Keep this list in sync with the install() calls below.
PKG_TABLE=$(cat <<'EOF'
git|git|git|git|git|git|git
nvim|neovim|neovim|neovim|neovim|neovim|neovim
make|make|make|make|make|make|make
rg|ripgrep|ripgrep|ripgrep|ripgrep|ripgrep|ripgrep
fd|fd|fd-find|fd-find|fd|fd|fd
starship|starship||||||
tmux|tmux|tmux|tmux|tmux|tmux|tmux
zsh|zsh|zsh|zsh|zsh|zsh|zsh
python3|python@3.12|python3|python3|python|python311|python3
node|node|nodejs|nodejs|nodejs|nodejs|nodejs
shellcheck|shellcheck|shellcheck|ShellCheck|shellcheck|ShellCheck|shellcheck
jq|jq|jq|jq|jq|jq|jq
bats|bats-core|bats|bats|bats|bats|bats
hyperfine|hyperfine|hyperfine|hyperfine|hyperfine|hyperfine|hyperfine
taplo|taplo|||taplo-cli||
yamllint|yamllint|yamllint|yamllint|yamllint|yamllint|yamllint
editorconfig-checker|editorconfig-checker|||editorconfig-checker||
xclip||xclip|xclip|xclip|xclip|xclip
wl-copy||wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard
unzip|unzip|unzip|unzip|unzip|unzip|unzip
fc-cache|fontconfig|fontconfig|fontconfig|fontconfig|fontconfig|fontconfig
EOF
)

pkg_for() {
    local tool="$1"
    local row
    row=$(printf '%s\n' "$PKG_TABLE" | awk -F'|' -v t="$tool" '$1==t{print; exit}')
    [[ -z "$row" ]] && { echo ""; return; }
    local idx
    case "$PM" in
        brew)   idx=2 ;;
        apt)    idx=3 ;;
        dnf)    idx=4 ;;
        pacman) idx=5 ;;
        zypper) idx=6 ;;
        apk)    idx=7 ;;
        *)      idx=2 ;;
    esac
    printf '%s\n' "$row" | awk -F'|' -v i="$idx" '{print $i}'
}

pm_install() {
    local pkgs=("$@")
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "  would: $PM install ${pkgs[*]}"; return 0
    fi
    case "$PM" in
        brew)   brew install "${pkgs[@]}" ;;
        apt)    maybe_sudo apt-get update -qq && maybe_sudo apt-get install -y "${pkgs[@]}" ;;
        dnf)    maybe_sudo dnf install -y "${pkgs[@]}" ;;
        pacman) maybe_sudo pacman -S --noconfirm "${pkgs[@]}" ;;
        zypper) maybe_sudo zypper install -y "${pkgs[@]}" ;;
        apk)    maybe_sudo apk add "${pkgs[@]}" ;;
    esac
    local rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "  WARN: $PM install of '${pkgs[*]}' returned $rc" >&2
    fi
    return $rc
}

# install <check-binary> [purpose-string]
# Looks up package name from PKG_TABLE for current PM. Skips if installed.
# Uses binaries_for() so distro-specific aliases (fd -> fdfind on apt) count
# as "already installed".
install() {
    local tool="$1" purpose="${2:-}"
    local bins
    bins="$(binaries_for "$tool")"
    # shellcheck disable=SC2086  # $bins is intentional word-splitting
    if have_any $bins; then
        printf "  ok        %-26s already installed\n" "$tool"
        return
    fi
    local pkg
    pkg="$(pkg_for "$tool")"
    if [[ -z "$pkg" ]]; then
        printf "  manual    %-26s not in %s repos; install separately\n" "$tool" "$PM"
        return
    fi
    if ask "Install $tool${purpose:+ ($purpose)}?"; then
        # shellcheck disable=SC2086  # $pkg may carry cask flags on brew
        pm_install $pkg || echo "  WARN: $tool install failed; continuing"
        # Post-install hint for fd-find on apt (binary lands as 'fdfind',
        # not 'fd'). Telescope's find_files uses fd by default.
        if [[ "$tool" == "fd" ]] && [[ "$PM" == "apt" ]] && ! have fd && have fdfind; then
            echo "  note      apt installed fd as 'fdfind'. Telescope expects 'fd'."
            echo "            One-time alias:  mkdir -p ~/.local/bin && ln -sfn \"\$(command -v fdfind)\" ~/.local/bin/fd"
            echo "            and ensure ~/.local/bin is on PATH."
        fi
    else
        printf "  skipped   %-26s\n" "$tool"
    fi
}

# Starship has an official one-liner installer that works without a PM.
install_starship_curl() {
    if have starship; then
        printf "  ok        %-26s already installed\n" "starship"
        return
    fi
    if ask "Install starship (prompt) via official curl installer?"; then
        if [[ "$DRY_RUN" -eq 1 ]]; then
            echo "  would: curl -sS https://starship.rs/install.sh | sh -s -- -y"
        else
            curl -sS https://starship.rs/install.sh | sh -s -- -y || echo "  WARN: starship install failed"
        fi
    else
        printf "  skipped   %-26s\n" "starship"
    fi
}

install_nerd_font() {
    if fc-list 2>/dev/null | grep -qi "hack.*nerd"; then
        printf "  ok        %-26s already installed\n" "Hack Nerd Font"
        return
    fi
    if [[ "$PM" == "brew" ]] && [[ "$(uname -s)" == "Darwin" ]]; then
        if ask "Install Hack Nerd Font (used by ghostty / Windows Terminal)?"; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "  would: brew install --cask font-hack-nerd-font"
            else
                brew install --cask font-hack-nerd-font || echo "  WARN: cask install failed"
            fi
        fi
        return
    fi
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
    local tmp; tmp="$(mktemp -d)"
    if ! curl -fL -o "$tmp/Hack.zip" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"; then
        echo "  FAIL: download failed; install Hack Nerd Font manually from nerd-fonts releases"
        rm -rf "$tmp"; return
    fi
    mkdir -p "$font_dir"
    if have unzip; then
        unzip -oq "$tmp/Hack.zip" -d "$font_dir"
    elif have bsdtar; then
        bsdtar -xf "$tmp/Hack.zip" -C "$font_dir"
    else
        echo "  FAIL: need 'unzip' or 'bsdtar' to extract the font archive"
        rm -rf "$tmp"; return
    fi
    rm -rf "$tmp"
    have fc-cache && fc-cache -f "$(dirname "$font_dir")" >/dev/null 2>&1 || true
    printf "  installed %-26s -> %s\n" "Hack Nerd Font" "$font_dir"
}

# Ghostty: try brew HEAD if Linuxbrew, else snap, else build instructions.
install_ghostty_linux() {
    if have ghostty; then
        printf "  ok        %-26s already installed\n" "ghostty"
        return
    fi
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
    if have snap; then
        if ask "Install ghostty via snap (community package)?"; then
            if [[ "$DRY_RUN" -eq 1 ]]; then
                echo "  would: sudo snap install ghostty --classic"
            else
                maybe_sudo snap install ghostty --classic || echo "  WARN: snap install failed"
            fi
            return
        fi
    fi
    echo "  manual    ghostty has no native $PM package. Options:"
    echo "              - snap:    sudo snap install ghostty --classic"
    echo "              - flatpak: search 'ghostty' on flathub"
    echo "              - source:  https://ghostty.org/docs/install/build"
}

# WSL clipboard bridge: check that win32yank.exe is reachable from WSL PATH.
check_wsl_clipboard() {
    if have win32yank.exe; then
        printf "  ok        %-26s win32yank.exe on PATH\n" "WSL clipboard"
        return
    fi
    echo "  manual    win32yank.exe is REQUIRED for WSL clipboard integration."
    echo "            On the Windows side:"
    echo "              scoop install win32yank   (or download from"
    echo "              https://github.com/equalsraf/win32yank/releases)"
    echo "            Then it must be on the WSL PATH (typical: it appears"
    echo "            automatically once installed via scoop)."
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
install fc-cache "font config (needed to install Hack Nerd Font on Linux)"
install_nerd_font

section "language tooling (for LSP / formatter back-ends)"
install python3 "needed by pyright"
install node "needed by prettier, markdown-preview"

if is_wsl; then
    section "WSL clipboard bridge"
    check_wsl_clipboard
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
