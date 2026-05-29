# Dotfiles — cross-platform terminal & editor setup

| Tool             | macOS                                             | Linux / WSL                     | Windows                                                       |
|------------------|---------------------------------------------------|---------------------------------|---------------------------------------------------------------|
| **Neovim**       | `~/.config/nvim` → `nvim/`                        | `~/.config/nvim` → `nvim/`      | `%LOCALAPPDATA%\nvim` → `nvim\`                               |
| **Starship**     | `~/.config/starship.toml` → `starship/starship.toml` | same                       | `%USERPROFILE%\.config\starship.toml` → `starship\starship.toml` |
| **zsh**          | `~/.zshrc` → `shells/zshrc`                       | same                            | n/a                                                           |
| **PowerShell**   | `$PROFILE` → `shells/powershell_profile.ps1` (via pwsh, optional) | same       | `$PROFILE` → `shells\powershell_profile.ps1`                  |
| **tmux**         | `~/.tmux.conf` → `tmux/tmux.conf`                 | same                            | `%USERPROFILE%\.tmux.conf` → `tmux\tmux.conf` (read by **psmux** — native Windows tmux); also via WSL |
| **Ghostty**      | `~/Library/Application Support/com.mitchellh.ghostty/config` → `ghostty/config` | `~/.config/ghostty/config` → `ghostty/config` | n/a (Ghostty not on Windows yet) |
| **Windows Terminal** | n/a                                           | n/a                             | merge `windows-terminal/settings.fragment.jsonc` (see that dir's README)  |

## Install

> **TL;DR — the one command is `setup`.** Run `setup.sh` (macOS / Linux / WSL)
> or `setup.ps1` (Windows). That's it. It installs dependencies, symlinks every
> config, and syncs Neovim plugins + LSP. You do **not** run `bootstrap.sh` or
> `install-deps.sh` yourself — `setup` runs them for you, in order.

`setup` is the supreme call: a thin orchestrator over four idempotent phases.

```
setup ─► install-deps   (phase 1: install packages)
      ─► bootstrap       (phase 2: symlink configs into place)
      ─► nvim +Lazy! sync                (phase 3: plugins)
      ─► nvim +MasonToolsInstallSync     (phase 4: LSP servers + formatters)
```

You only reach for the phase scripts to **re-run a single phase later** (e.g.
`bootstrap.sh` to re-symlink after moving the repo). On a fresh machine, ignore
them and run `setup`.

| Situation | Command |
|---|---|
| **New machine — the normal case** | **`setup.sh`** · **`setup.ps1`** |
| Re-symlink configs only (no installs) | `bootstrap.sh` · `bootstrap.ps1` |
| (Re)install packages only | `install-deps.sh` · `install-deps.ps1` |

### One-shot, from scratch (recommended)

No checkout needed. `setup.{sh,ps1}` clones the repo to `~/dotfiles`
(or `%USERPROFILE%\dotfiles` on Windows). **Git is the only hard prerequisite
for remote bootstrap** because setup needs it to clone the repo; every other
repo-managed dependency is installed by `setup`. It symlinks every config and
finishes with `:Lazy! sync` +
`:MasonToolsInstallSync` so LSP servers and formatters are downloaded
before nvim even opens.

```bash
# mac / linux / wsl
curl -fsSL https://raw.githubusercontent.com/luisgui1757/dotfiles/main/setup.sh | bash -s -- --all
```

```powershell
# windows -- enable Developer Mode, then run from a normal PowerShell
# Settings -> Privacy & security -> For developers -> Developer Mode = On
iwr https://raw.githubusercontent.com/luisgui1757/dotfiles/main/setup.ps1 -OutFile setup.ps1
.\setup.ps1 -All
```

If Developer Mode is unavailable AND you cannot enable it, run JUST
`bootstrap.ps1` from an elevated PowerShell; do NOT elevate `setup.ps1` --
scoop refuses admin.

Pass `--all` / `-All` for explicit non-interactive installs (Y to every prompt).
When setup detects redirected stdin/stdout and neither all nor dry-run was
requested, it defaults to all and prints `note: no TTY detected; running with
--all` (or `-All`). An interactive run (no all flag) still opens with a single
**"install EVERYTHING without further prompts? [Y/n]"** question — answer `Y`
to pull the lot in one go, or `n` to choose per tool.
Add `--dry-run` / `-DryRun` to preview every step without touching disk.

### From an existing checkout

```bash
./setup.sh                       # Y/n per dep, end-to-end
./setup.sh --all                 # non-interactive
./setup.sh --dry-run             # preview
./setup.sh --skip-deps           # already installed; just bootstrap + sync
./setup.sh --skip-bootstrap      # already symlinked; just sync plugins + LSP
make setup                       # same as ./setup.sh, via the Makefile
```

```powershell
.\setup.ps1
.\setup.ps1 -All
.\setup.ps1 -DryRun
.\setup.ps1 -MergeWindowsTerminal     # also apply the WT rose-pine fragment
```

### Or invoke the phases manually

`setup.{sh,ps1}` is a thin orchestrator. Each phase is also a
standalone, idempotent script:

```bash
./install-deps.sh                # phase 1: package-manager installs
./bootstrap.sh                   # phase 2: symlink configs
nvim --headless "+Lazy! sync" +qa            # phase 3: plugins
nvim --headless "+MasonToolsInstallSync" +qa # phase 4: LSP + formatters
```

```powershell
.\install-deps.ps1
.\bootstrap.ps1
nvim --headless "+Lazy! sync" "+qa"
nvim --headless "+MasonToolsInstallSync" "+qa"
```

Phase 1 (`install-deps.sh`) also offers to make **zsh your login shell**
(`chsh`) — installing the package alone doesn't, so without this step tmux and
new terminals on Linux keep launching bash and never source the symlinked
`~/.zshrc`. It's consent-gated (auto-yes under `--all`), idempotent, and
no-ops on macOS (already zsh). The change takes effect after the next login.
On **domain / AD / LDAP** machines the account isn't in `/etc/passwd`, so
`chsh` can't help — there it instead offers to re-exec interactive bash into
zsh from `~/.bashrc` (reversible).

On Linux without Homebrew, Phase 1 installs Neovim from a pinned official
GitHub release tarball into `/opt/nvim-linux-<arch>` (`x86_64` or `arm64`) and
symlinks `/usr/local/bin/nvim`. The installer verifies the tarball SHA-256
first, which avoids distro packages that lag below this config's Neovim 0.11+
floor.

On macOS, Phase 1 installs Ghostty through `brew install --cask ghostty` when
selected. Linux keeps the Linux-specific brew HEAD / snap / manual install
paths because Ghostty is not packaged uniformly there.

Phase 1 also **prompts for your notes / Obsidian vault path** and persists it as
`export NOTES_VAULT=…` in `~/.zshrc.local` (gitignored, sourced by `zshrc`), so
obsidian.nvim opens that vault. Blank answer = an OS-appropriate default. The
prompt is skipped under `--all` / non-interactive runs — set `NOTES_VAULT`
yourself there.

Every script is idempotent — re-running is a no-op when everything is
already in place. Pre-existing non-symlink targets are backed up to
`<target>.bak.<timestamp>` (collision-proof: `.1`, `.2`, … if reused).

## Test

```bash
make help           # list targets
make test           # run everything that can run on this OS
make test-bootstrap # bats coverage of the installer
make lint           # shellcheck everything
```

Sub-targets skip themselves with a `skipped: <tool> not installed` message
when their dependency tool is missing on the current machine.

## Repo layout

```
.
├── nvim/                  # Neovim — init.lua, lua/{vim-options,util,plugins}
├── starship/              # starship.toml (Rose Pine)
├── shells/                # zshrc + powershell_profile.ps1
├── tmux/                  # tmux.conf (Rose Pine, vi-mode, true-color)
├── ghostty/               # config (Rose Pine, Hack Nerd, Ghostty-tuned)
├── windows-terminal/      # settings.fragment.jsonc + merge README
├── tests/                 # automated test tree
├── .github/workflows/     # CI matrix (ubuntu, macos, windows)
├── bootstrap.sh           # Unix installer
├── bootstrap.ps1          # Windows installer
├── Makefile               # test/install entry point
├── .editorconfig          # cross-IDE formatting rules
└── README.md
```

## Key design decisions (and why)

- **One source of truth via symlinks.** Edits in the repo are live everywhere
  without manual copy-paste; `bootstrap.{sh,ps1}` are idempotent.
- **Rose Pine everywhere it can render.** Nvim, lualine, starship, tmux,
  ghostty, Windows Terminal, PSReadLine — same palette across the stack. VS Code
  joins optionally: `install-deps` offers VS Code, and if `code` is detected it
  installs the `mvllow.rose-pine` theme and sets `workbench.colorTheme` (existing
  JSONC settings are left untouched).
- **conform.nvim is the only format-on-save handler.** Replacing the
  prior LSP-attach autocmd + null-ls duo eliminates a real race condition
  with different timeouts. `:WNF` (or `:wnf`) skips formatting for one save.
- **Mason installs LSP servers + formatters via mason-tool-installer.** No
  `mason-lspconfig` — redundant on nvim 0.11 with `vim.lsp.enable`.
- **DAP launches stay generic.** The shared browser launch defaults to
  `http://localhost:3000`; set `DAP_LAUNCH_URL` or put project-specific launch
  configs in workspace `.nvim.lua` files.
- **Starship language modules pared down.** Only `c, go, node, rust, python,
  conda` are enabled. Disabled languages don't spawn version probes on every
  prompt.
- **Zsh starship init is precompiled** (mirroring the PowerShell profile
  approach) — re-generated only when `starship.toml` is newer than the cache.
- **fzf wired into zsh by default** — `Ctrl-R` fuzzy history, `Ctrl-T` file
  picker, `Alt-C` fuzzy cd. It *complements* zsh-autosuggestions (inline
  ghosting), it doesn't replace it. Guarded by `command -v fzf` so a machine
  without it still starts cleanly; uses `fzf --zsh` with a share-dir fallback
  for older distro builds.
- **No `bindkey '\e' kill-whole-line`** — that shadowed the entire Meta
  prefix and silently broke Alt-h/j/k/l window nav in nvim.
- **Windows Terminal settings.json is NOT symlinked** because WT auto-rewrites
  it. Only the user-owned keys live in `settings.fragment.jsonc`; the install
  script merges them in.

See `CLAUDE.md` for the operational guide (invariants, common workflows,
conventions).

## Daily workflows

### `:wnf` — write without formatting

In any buffer: `:wnf<CR>` (lowercase) saves the file with formatters skipped
**for this one save**. The next plain `:w` formats normally. Useful in legacy
codebases where the formatter would create a noisy diff. Implemented in
`nvim/lua/vim-options.lua`.

### Adding a plugin

Drop one file at `nvim/lua/plugins/<name>.lua` returning the lazy spec.
Lazy auto-discovers it. Default to lazy-loading (`event` / `cmd` / `keys` /
`ft`). Only `rose-pine` may set `lazy = false`.

### Adding an LSP server / formatter / treesitter parser

See `CLAUDE.md` → "Common workflows". Three small edits each: the plugin
spec, the Mason ensure_installed list, and the corresponding test under
`tests/nvim/spec/`.

### Refreshing the plugin lockfile

```bash
nvim --headless "+Lazy! sync" +qa
git add nvim/lazy-lock.json   # tracked, not gitignored
```

### Updating Mason tools across machines

```bash
nvim --headless "+MasonToolsUpdate" +qa
```

Run on each machine; there's no machine-pinned lockfile for Mason itself.

### Switching machines mid-session

```bash
git -C ~/dotfiles pull          # sync configs
nvim --headless "+Lazy! sync" +qa     # match plugin commits
make test                       # verify the new state
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `<leader>X` keymaps fire `\X` instead of `<Space>X` | mapleader set after lazy.setup somehow | restore the order in `nvim/init.lua` — leader **before** `require("lazy").setup` |
| Formatter runs twice or shows two BufWritePre autocmds | someone added a second handler outside conform.nvim | `:lua print(#vim.api.nvim_get_autocmds({event="BufWritePre"}))` should be 1; if not, find the second autocmd and delete it |
| Clipboard not crossing host on WSL | `win32yank.exe` not on PATH | install win32yank via scoop on Windows side, ensure WSL PATH picks it up |
| Starship prompt slow | a disabled language got re-enabled | check `starship/starship.toml` — only `c, go, nodejs, rust, python, conda` should be enabled |
| Starship shows only the last few folders (or a leading `…/`) | the `[directory]` module was truncating the path | `starship/starship.toml` sets `truncation_length = 0` + `truncate_to_repo = false` for the full path; raise the length or set `truncate_to_repo = true` to shorten again |
| A folder like `Downloads`/`Music`/`Pictures` shows as a blank `~/` | its `[directory.substitutions]` glyph was stripped to a bare space | values are `icon + name` (e.g. `Downloads = "<nerd-font-glyph> Downloads"`) using a codepoint your font has; `tests/starship/directory_test.sh` fails on a whitespace-only value |
| `Alt-h/j/k/l` window nav doesn't work in terminal | something rebinds bare Esc in the shell | `bindkey | grep '^"\^\['` in zsh — should NOT show `kill-whole-line` |
| tmux (or any new terminal) launches **bash on Linux**, not zsh | the login shell was never changed — `~/.zshrc` is symlinked but the account still logs into bash | re-run `./install-deps.sh` and accept "Make zsh your default login shell?", or `chsh -s "$(command -v zsh)"` then log out/in. macOS already defaults to zsh |
| `chsh` fails with `user '<name>' does not exist in /etc/passwd` | you log in via a **domain** account (AD/LDAP/SSSD) that isn't in local `/etc/passwd`, so `chsh` can't touch it | re-run `./install-deps.sh` — it detects this and offers to re-exec interactive bash into zsh via `~/.bashrc` instead. The "proper" fix is admin-side: set the directory `loginShell` / SSSD `default_shell` |
| Move commits in lazygit, including inside psmux | Ctrl+J collides with Enter on the wire, and psmux v3.3.4 does not relay Windows Terminal's Win32-input-mode modifier data into panes | use uppercase `J` / `K`. `%LOCALAPPDATA%\lazygit\config.yml` binds commits-panel moveDownCommit / moveUpCommit to printable J/K, so no psmux root bind is needed. In the commits panel, use PgUp/PgDn or Ctrl-U/Ctrl-D to scroll the diff |
| Ghostty doesn't open maximized | `window-save-state = always` restored an old geometry over `maximize` (macOS only) | `ghostty/config` uses `window-save-state = default` (not `always`) with `maximize = true`; `always` lets the saved size win |
| Ghostty doesn't load the config | wrong path | the install path is `~/Library/Application Support/com.mitchellh.ghostty/config` on macOS, `~/.config/ghostty/config` on Linux. `bootstrap.sh` handles this |
| Windows Terminal lost a profile after merge | WT auto-rewrites — pre-merge backup is at `<settings.json>.bak.<timestamp>` | restore the profile list from the backup |
| `bootstrap.ps1` errors "cannot create symbolic links" | Developer Mode off and not elevated | `bootstrap.ps1` now reports your *elevated* + *Developer Mode* state and the fix: enable Developer Mode (Settings → Privacy & security → For developers — no admin, recommended) **then** `.\setup.ps1 -SkipDeps`; OR run just `.\bootstrap.ps1` from an elevated PowerShell. Don't elevate the whole `setup.ps1` — scoop refuses to run as admin |
| Ghostty won't open maximized on Linux/GNOME | `maximize = true` is a hint the WM may ignore (GNOME Mutter often does) | on **X11**, `install-deps` offers a devilspie2 setup that enforces it (rule + autostart, keyed on `com.mitchellh.ghostty`); the manual steps are in `linux/devilspie2/ghostty-maximize.lua`. Wayland needs a GNOME Shell extension instead |
| `install-deps.ps1`: winget `No package found matching input criteria` (exit `-1978335212`) | winget source/catalog flakiness | install-deps now **prefers scoop** and falls back across managers per tool — accept the scoop bootstrap when offered (`irm get.scoop.sh \| iex`) and re-run; scoop carries every CLI tool here |
