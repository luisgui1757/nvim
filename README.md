# Dotfiles — cross-platform terminal & editor setup

| Tool             | macOS                                             | Linux / WSL                     | Windows                                                       |
|------------------|---------------------------------------------------|---------------------------------|---------------------------------------------------------------|
| **Neovim**       | `~/.config/nvim` → `nvim/`                        | `~/.config/nvim` → `nvim/`      | `%LOCALAPPDATA%\nvim` → `nvim\`                               |
| **Starship**     | `~/.config/starship.toml` → `starship/starship.toml` | same                       | `%USERPROFILE%\.config\starship.toml` → `starship\starship.toml` |
| **zsh**          | `~/.zshrc` → `shells/zshrc`                       | same                            | n/a                                                           |
| **PowerShell**   | `$PROFILE` → `shells/powershell_profile.ps1` (via pwsh, optional) | same       | `$PROFILE` → `shells\powershell_profile.ps1`                  |
| **tmux**         | `~/.tmux.conf` → `tmux/tmux.conf`                 | same                            | (WSL only)                                                    |
| **Ghostty**      | `~/Library/Application Support/com.mitchellh.ghostty/config` → `ghostty/config` | `~/.config/ghostty/config` → `ghostty/config` | n/a (Ghostty not on Windows yet) |
| **Windows Terminal** | n/a                                           | n/a                             | merge `windows-terminal/settings.fragment.jsonc` (see that dir's README)  |
| **Claude Code**  | `~/.claude/*` (out of scope; tracked via `claude/`) | same                          | `%USERPROFILE%\.claude\*`                                     |

## Install

### One-shot, from scratch (recommended)

No checkout needed. `setup.{sh,ps1}` clones the repo to `~/dotfiles`
(or `%USERPROFILE%\dotfiles` on Windows), installs every dependency,
symlinks every config, and finishes with `:Lazy! sync` +
`:MasonToolsInstallSync` so LSP servers and formatters are downloaded
before nvim even opens.

```bash
# mac / linux / wsl
curl -fsSL https://raw.githubusercontent.com/luisgui1757/nvim/main/setup.sh | bash
```

```powershell
# windows -- run elevated OR with Developer Mode enabled (Settings ->
# Privacy & security -> For developers -> Developer Mode = On)
irm https://raw.githubusercontent.com/luisgui1757/nvim/main/setup.ps1 | iex
```

Add `--all` / `-All` for fully non-interactive (Y to every prompt).
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
├── claude/                # Claude Code settings (cross-machine sync)
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
  ghostty, Windows Terminal, PSReadLine — same palette across the stack.
- **conform.nvim is the only format-on-save handler.** Replacing the
  prior LSP-attach autocmd + null-ls duo eliminates a real race condition
  with different timeouts. `:WNF` (or `:wnf`) skips formatting for one save.
- **Mason installs LSP servers + formatters via mason-tool-installer.** No
  `mason-lspconfig` — redundant on nvim 0.11 with `vim.lsp.enable`.
- **Starship language modules pared down.** Only `c, go, node, rust, python,
  conda` are enabled. Disabled languages don't spawn version probes on every
  prompt.
- **Zsh starship init is precompiled** (mirroring the PowerShell profile
  approach) — re-generated only when `starship.toml` is newer than the cache.
- **No `bindkey '\e' kill-whole-line`** — that shadowed the entire Meta
  prefix and silently broke Alt-h/j/k/l window nav in nvim.
- **Windows Terminal settings.json is NOT symlinked** because WT auto-rewrites
  it. Only the user-owned keys live in `settings.fragment.jsonc`; the install
  script merges them in.

See `/Users/user/.claude/plans/this-directory-has-my-idempotent-seahorse.md`
for the full design notes that drove the restructure, and `CLAUDE.md` for the
operational guide (invariants, common workflows, conventions).

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
| `Alt-h/j/k/l` window nav doesn't work in terminal | something rebinds bare Esc in the shell | `bindkey | grep '^"\^\['` in zsh — should NOT show `kill-whole-line` |
| Ghostty doesn't load the config | wrong path | the install path is `~/Library/Application Support/com.mitchellh.ghostty/config` on macOS, `~/.config/ghostty/config` on Linux. `bootstrap.sh` handles this |
| Windows Terminal lost a profile after merge | WT auto-rewrites — pre-merge backup is at `<settings.json>.bak.<timestamp>` | restore the profile list from the backup |
| `bootstrap.ps1` errors "cannot create symbolic links" | Developer Mode off and not elevated | enable Developer Mode (Settings → Privacy & security → For developers) OR run from an elevated PowerShell |
