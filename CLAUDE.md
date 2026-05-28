# Repo guide for Claude (and humans coming back to this cold)

This file is the on-ramp. If you're a future Claude session, read this **before**
touching anything. If you're me six months from now and forgot how the install
script works, read this too.

## What this repo is

Cross-platform dotfiles: Neovim (lazy.nvim), Starship, Ghostty, Windows
Terminal, tmux, zshrc, PowerShell profile, Claude Code settings. Single source
of truth — `bootstrap.sh` (macOS / Linux / WSL) and `bootstrap.ps1` (Windows)
symlink everything into OS-appropriate locations. The bootstrap scripts are
**location-independent** (they resolve `$REPO_ROOT` / `$RepoRoot` from their own
path), so the repo can live anywhere — `~/dotfiles/`, `~/Documents/dotfiles/`,
etc. The remote-clone default in `setup.{sh,ps1}` is `~/dotfiles/`, but an
in-place clone elsewhere works too. Do NOT put the repo at `~/.config/nvim/` —
the installer creates that path as a symlink **pointing into** the repo, so a
repo there would self-overlap (the self-link guard refuses this).

Claude Code settings live under `claude/` at the **repo root** — NOT under
`nvim/claude/`. `~/.claude/settings.json` and `~/.claude/statusline-command.sh`
symlink to `claude/settings.json` and `claude/statusline-command.sh`. (A stale
pre-restructure layout routed `~/.claude/settings.json` through
`~/.config/nvim/claude/` — that indirection is deprecated; bootstrap now links
`claude/` directly.)

## Layout at a glance

```
~/dotfiles/
├── nvim/                  Neovim — init.lua, lua/{vim-options,util,plugins}
├── starship/              starship.toml (Rose Pine palette)
├── shells/                zshrc + powershell_profile.ps1
├── tmux/                  tmux.conf (Rose Pine, vi-mode, OSC52 clipboard)
├── ghostty/               config (Rose Pine, Hack Nerd, tuned for tmux)
├── windows-terminal/      settings.fragment.jsonc + merge README
├── claude/                Claude Code per-user settings (cross-machine sync)
├── tests/                 automated tests, grouped by tool
├── .github/workflows/     CI matrix: ubuntu / macos / windows
├── bootstrap.sh           macOS/Linux/WSL installer (idempotent)
├── bootstrap.ps1          Windows installer (idempotent)
├── Makefile               `make test`, `make install`, `make dryrun`, `make lint`
├── .editorconfig          formatting rules every editor + Claude respects
├── README.md              the human-facing install matrix
└── CLAUDE.md              ← you are here
```

`.claude/` (with dot) is Claude Code's local state directory and is **not**
part of the synced configuration — leave it alone. `claude/` (no dot) is the
folder of Claude Code settings that DO sync.

## Non-negotiable invariants

These are guarded by `tests/static/invariants_test.sh`. If you change code
that violates one of these, fix it instead of disabling the test.

1. **Leader is set before lazy.** `vim.g.mapleader = " "` must appear in
   `nvim/init.lua` *before* the `require("lazy").setup(...)` line. Plugin specs
   that mention `<leader>` are resolved at spec-import time, so flipping the
   order silently re-binds every `<leader>X` to `\X`. Caught by
   `tests/nvim/spec/leader_spec.lua`.
2. **No `NODE_TLS_REJECT_UNAUTHORIZED`.** Anywhere outside the `claude/`
   subtree. The old config disabled TLS verification globally for node-based
   plugins — that's a security regression, not a workaround.
3. **No `vim.loop`.** Use `vim.uv`. (Caught by invariants_test.)
4. **No `client.supports_method(...)` dot-call.** Use the colon form
   `client:supports_method(...)` — the dot form is deprecated in nvim 0.11.
5. **No `bindkey '\e' kill-whole-line` in zshrc.** That binding shadows the
   entire Meta prefix and breaks every `Alt-X` keybinding (including the
   `<A-h/j/k/l>` window-nav bindings in `vim-options.lua`).
6. **Starship `git_status` styles use `($style)` not `(style)`.** Literal
   `(style)` is a render-bug — the closing icon wouldn't get styled.
7. **`rose-pine.lua` is the only plugin with `lazy = false`**, and it must
   have `priority = 1000`. Everything else lazy-loads on event/cmd/keys/ft.
8. **`conform.nvim` is the ONLY format-on-save handler.** Don't add a
   `BufWritePre` autocmd in `lsp-config.lua` or in any `LspAttach` block. The
   old config raced two handlers with different timeouts.
9. **`vim.b.skip_format_on_save` controls `:WNF`.** If you add another
   format-on-save path, it MUST check this flag (see `nvim/lua/plugins/conform.lua`).
10. **The four deleted dead files must stay deleted:**
    `nvim/lua/plugins.lua`, `nvim/lua/plugins/ai.lua`,
    `nvim/lua/plugins/avante.lua`, `nvim/lua/plugins/none-ls.lua`.
11. **Markdown rendering lives in `nvim/lua/plugins/markdown.lua`
    (render-markdown.nvim).** Don't add `headlines.nvim` or
    `markview.nvim` alongside it — they overlap and fight for the same
    extmarks. Obsidian.nvim's own UI is disabled (`ui.enable = false`)
    in `notes.lua` so render-markdown owns rendering everywhere. obsidian.nvim
    loads on every markdown buffer — it is **no longer** gated on the vault dir
    existing (`enabled = isdirectory(...)` silently disabled it on machines
    without a vault). It `mkdir -p`s the resolved vault and honors `NOTES_VAULT`
    (see `util/notes_path.lua`); set that env var to point at your real vault.
12. **No `vim.lsp.set_log_level(...)`.** Deprecated in nvim 0.11; use the module
    form `vim.lsp.log.set_level(...)` (see `lsp-config.lua`). Guarded by
    `invariants_test.sh`.

## Common workflows

### Add a new plugin

Drop a single file under `nvim/lua/plugins/<name>.lua` returning the lazy
spec. Lazy auto-discovers `{ import = "plugins" }` from `init.lua`. Default
to lazy-loading (`event` / `cmd` / `keys` / `ft`). Only `rose-pine` may set
`lazy = false`.

### Add a new LSP server

1. Add the server name to `vim.lsp.config(...)` and the `vim.lsp.enable({...})`
   list in `nvim/lua/plugins/lsp-config.lua`.
2. Add the Mason package to the `ensure_installed` array in the same file
   (under the `mason-tool-installer` config block).
3. Add the server name to `tests/nvim/spec/lsp_spec.lua`'s `required_servers`
   so the static-check catches a future accidental removal.

> **Headless-install gotcha:** `mason-tool-installer` is `event = "VeryLazy"`
> (interactive auto-install via `run_on_start`) **and** registers its commands
> under `cmd = { … }`. Those `cmd` triggers are load-bearing — the setup phase
> runs `nvim --headless +MasonToolsInstallSync`, and `VeryLazy` never fires
> without a UI, so without the `cmd` trigger that command is `E492: Not an
> editor command`. Keep `MasonToolsInstallSync`/`MasonToolsUpdate` in the `cmd`
> list (guarded by `lsp_spec.lua`).

### Add a new formatter

1. Add to `formatters_by_ft` in `nvim/lua/plugins/conform.lua`.
2. Add the Mason package to `mason-tool-installer` `ensure_installed`.
3. No new autocmd — conform's `format_on_save` handles it. The buffer-local
   `vim.b.skip_format_on_save` short-circuit (i.e. `:WNF`) is already in place.

### Add a treesitter parser

1. Add the parser name to `ensure_installed` in
   `nvim/lua/plugins/treesitter.lua`.
2. Add it to `required` in `tests/nvim/spec/treesitter_spec.lua`.

### Rebind a Rose Pine color anywhere

The palette is **one constant set** used everywhere. Keep it consistent:

```
overlay  #26233a   love    #eb6f92   gold    #f6c177
rose     #ebbcba   pine    #31748f   foam    #9ccfd8
iris     #c4a7e7   base    #191724   surface #1f1d2e
muted    #6e6a86   subtle  #908caa   text    #e0def4
```

Surfaces that consume these: nvim (rose-pine plugin defaults), lualine
(theme="rose-pine"), starship.toml (`[palettes.rose-pine]`), tmux.conf (hex
literals in status/borders), ghostty/config (`theme = dark:Rose Pine,...`),
windows-terminal/settings.fragment.jsonc (`schemes` + `themes`),
shells/powershell_profile.ps1 (PSReadLine `-Colors`).

### Refresh the lazy lockfile after adding plugins

```bash
nvim --headless "+Lazy! sync" +qa
git add nvim/lazy-lock.json
```

`lazy-lock.json` is tracked (NOT gitignored) — that's how every machine ends
up on the same commits.

### Update Mason-installed tools across machines

```bash
nvim --headless "+MasonToolsUpdate" +qa
```

There's no machine-pinned lockfile for Mason itself — `mason-tool-installer`
ensures the named tools exist on each machine.

## Test runner

```bash
make help            # list all sub-targets
make test            # run everything that can run on this OS
make test-nvim       # plenary busted suite
make test-bootstrap  # bats coverage of bootstrap.sh idempotency
make lint            # shellcheck across all .sh
```

Sub-targets **skip gracefully** when their tool isn't installed
(`yamllint`/`editorconfig-checker`/`hyperfine`/`bats`/`ghostty`). The
ubuntu/macos/windows CI matrix in `.github/workflows/test.yml` installs
everything, so anything passing locally + CI is genuinely cross-platform.

When adding a new spec:
- Plenary specs: drop a `*_spec.lua` under `tests/nvim/spec/`. Use plenary
  busted's `describe` / `it` / `before_each` / `after_each` — **do not** use
  `setup` / `teardown` (those globals don't exist in plenary's busted).
- Shell tests: drop a `*_test.sh` under `tests/shell/` (or other dir). It's
  picked up by the dir's `run_all.sh` automatically.

## :WNF (Write Without Formatting)

The buffer-local feature you can rely on. `:WNF<CR>` (or lower-case
`:wnf<CR>`) writes the current buffer with formatters skipped for **this one
save only**. The next plain `:w` formats normally. Implemented in
`nvim/lua/vim-options.lua`; the skip flag is consumed in
`nvim/lua/plugins/conform.lua`'s `format_on_save` callback and cleared by a
`BufWritePost` autocmd.

## Bootstrap details (don't reinvent these)

- Both installers are **idempotent** — running twice produces zero diffs.
  Tested by `tests/bootstrap/sh_test.bats` (and `ps1_test.ps1` on Windows).
- Pre-existing non-symlink targets are backed up to
  `<target>.bak.<timestamp>` (with `.1`, `.2`, … suffixes if a collision
  exists). Backups are never overwritten.
- `bootstrap.sh --dry-run` and `bootstrap.ps1 -DryRun` print the planned
  actions without touching disk. The Windows DryRun does not require
  Developer Mode — it downgrades the symlink-permission probe to a warning.
- The Windows installer does NOT symlink `settings.json` for Windows
  Terminal — WT rewrites that file on launch. Use
  `.\bootstrap.ps1 -MergeWindowsTerminal` to merge the user-owned keys in;
  it backs up the pre-merge `settings.json` first.
- **`install-deps.ps1` prefers scoop, then falls back across managers
  per tool.** `Install-One` builds an ordered candidate list (scoop → primary →
  winget → choco) of managers that are installed AND carry the package, and
  tries each until one succeeds — so a winget `No package found` (exit
  `-1978335212`) no longer dead-ends a tool. scoop carries every CLI tool in
  the `$Catalog`.
- **`install-deps.sh` prompts for the notes/Obsidian vault** and persists
  `export NOTES_VAULT=…` to `~/.zshrc.local` (sourced by `zshrc`, read by
  `util/notes_path.lua`). The prompt is tty-gated (skipped under `--all` /
  piped / `--dry-run`); the write logic is split into `persist_notes_vault` so
  `tests/shell/notes_vault_test.sh` can exercise it without a tty.
- **`install-deps` can install VS Code + the Rose Pine theme.** Both installers
  offer VS Code (macOS brew cask; Linux snap/flatpak/manual; Windows
  winget/scoop/choco). Then, **only if `code` is detected**, they install the
  `mvllow.rose-pine` extension and set `workbench.colorTheme` to "Rosé Pine".
  The theme setter (`set_vscode_theme` in sh, tested by `vscode_theme_test.sh`;
  `Set-VSCodeTheme` in ps1) only merges into *clean* JSON (jq /
  `ConvertFrom-Json`) — VS Code settings are usually JSONC with comments, so it
  leaves those untouched rather than clobbering them. The theme value must keep
  its accented é to match the extension's label; the ps1 emits it as a `\u` JSON
  escape (or `[char]0xE9`) so that file stays pure ASCII (invariant), while the
  sh side uses the literal é.
- **Both installers open with an "install EVERYTHING?" prompt.** Interactive
  runs that didn't pass `--all`/`-All` get one upfront question; answering yes
  flips `YES_ALL`/`$All` so the rest runs with no per-item prompts. Skipped when
  `--all`/`--dry-run` was passed or there's no tty (so `curl|bash` and the CI
  `--dry-run --all` dogfood don't hang).
- **`bootstrap.ps1` reports WHY symlinks fail and how to fix it.** When the
  symlink probe fails it prints your *elevated* (admin) and *Developer Mode*
  state, then the two fixes (Developer Mode — no admin, recommended — or an
  elevated shell), and `exit 1` via `Write-Host` (not `Write-Error`, so no stack
  trace). `setup.ps1` resets `$LASTEXITCODE` before Phase 2 and stops if
  bootstrap fails, so nvim sync never runs against un-symlinked configs. Note:
  don't elevate the whole `setup.ps1` — scoop refuses to run as admin.
- **Forcing Ghostty maximize on Linux is WM-side, not config.** `maximize = true`
  is only a hint the compositor may ignore — confirmed on **GNOME 46 / X11**,
  where Mutter does NOT honor it. `install-deps.sh`'s `setup_ghostty_maximize`
  is an opt-in step (Linux + Ghostty installed + non-Wayland) that installs
  devilspie2, symlinks `linux/devilspie2/ghostty-maximize.lua` (keyed on WM_CLASS
  `com.mitchellh.ghostty`) into `~/.config/devilspie2/`, and writes a
  `~/.config/autostart/devilspie2.desktop`. It lives in install-deps (installs a
  package + runs a daemon), NOT bootstrap (pure-symlink); Wayland needs a GNOME
  Shell extension instead. Guarded by `tests/shell/devilspie2_test.sh`.
- **psmux is the Windows tmux** (`install-deps.ps1` → `Install-Psmux`). Picked
  because it **reads `~/.tmux.conf`** and speaks the tmux command language, so
  Windows reuses the *same* `tmux/tmux.conf` we maintain for Unix — one source
  of truth, Rose Pine carries over, no parallel config. `bootstrap.ps1` symlinks
  `tmux\tmux.conf` to `%USERPROFILE%\.tmux.conf` (mirrors the Unix
  `~/.tmux.conf` link). If the Unix-shaped `if-shell` clipboard block ever
  chokes under ConPTY on a given machine, guard that block rather than fork the
  config. Install-Psmux is NOT in the `$Catalog` because scoop needs a custom
  bucket (`scoop bucket add psmux …`) — the helper does that, then falls back
  to winget / choco.
- **psmux + PSReadLine: Windows-only overlay, two settings.** psmux's default
  shell is **cmd**, not pwsh — which is the *real* reason "history prediction"
  and `MenuComplete` looked broken inside panes: PSReadLine was never loaded.
  The fix is a Windows-only overlay `tmux/tmux.windows.conf`, symlinked to
  `~/.tmux.windows.conf` by `bootstrap.ps1` and pulled in by the main
  `tmux/tmux.conf` via `source-file -q` (silent no-op on Unix where it does not
  exist). The overlay sets:
  (1) `default-shell pwsh` — so fresh psmux panes spawn PowerShell 7, which
  loads PSReadLine + the profile.
  (2) `allow-predictions on` — psmux otherwise resets `PredictionSource` to
  `None` during pane init (psmux issue #150 — fresh panes ignore the profile's
  `HistoryAndPlugin`). With this on, the profile's ListView prediction +
  `Tab=MenuComplete` survive into psmux panes.
  Diagnose inside a pane with `(Get-Process -Id $PID).Name` (expect `pwsh`).
  Do NOT add `set -g default-shell` to the main `tmux.conf` — `pwsh` does not
  exist on Unix; keep Windows-specific tmux settings in the overlay.
- **psmux residual race (v3.3.4): `OnIdle` workaround in the profile.** Even
  with `allow-predictions on`, fresh psmux panes were observed at
  `PredictionSource=None` / `PredictionViewStyle=InlineView` -- the documented
  psmux init resets PSReadLine **after** `$PROFILE` finishes (issue #150). The
  user-visible "calling pwsh inside psmux fixes it" trick works because the
  nested pwsh re-runs `$PROFILE` after psmux is done. Same idea, done
  automatically: `shells/powershell_profile.ps1` registers a one-shot
  `PowerShell.OnIdle` (gated on `$env:TMUX`) that re-applies
  `HistoryAndPlugin`/`ListView` + `Tab=MenuComplete` (+ `ShowToolTips` when the
  parameter exists, PSReadLine ≥ 2.3.4). Microsoft + psmux #150 both point at
  `OnIdle` as the right hook. Drop it once a psmux release fixes the residual
  race upstream (no PR yet; track issue #150 / #165).

## Login shell: zsh adoption (install-deps.sh)

Installing the zsh *package* does NOT make zsh your login shell — that takes a
`chsh`. `install-deps.sh` does it in the "terminal multiplexer + shell" section
(`set_default_shell_zsh`); without it, Linux keeps logging the account into bash
and tmux / new terminals never source the symlinked `~/.zshrc` (this is the
"tmux shows bash" symptom). The step is:

- **idempotent** — no-op when the login shell is already a *zsh* (compared by
  basename, so macOS's `/bin/zsh`, a distro `/usr/bin/zsh`, and a brew zsh all
  count as done; macOS therefore never churns);
- **consent-gated** — prompts before changing (auto-yes under `--all`);
- **dry-run-safe** — prints a `would:` line and mutates nothing under `--dry-run`
  (this is why the CI `--dry-run --all` dogfood stays green);
- it registers zsh in `/etc/shells` first (chsh refuses otherwise) and runs chsh
  as root / via sudo / via plain PAM, whichever is available. Takes effect on the
  next login.

It lives in `install-deps.sh`, NOT `bootstrap.sh` (which stays pure-symlink), and
NOT `tmux.conf` (a tmux-only `default-command` would paper over the symptom while
bare TTYs and SSH sessions stayed bash).

**Domain / non-local accounts (AD/LDAP/SSSD):** these resolve through NSS but
are NOT in local `/etc/passwd`, so `chsh` fails (`user '<name>' does not exist in
/etc/passwd`). `set_default_shell_zsh` detects this on Linux via
`is_local_account` (an `awk` exact-match on `/etc/passwd`) and routes to
`adopt_zsh_domain` instead of `adopt_zsh_chsh`. The fallback (`ensure_bash_execs_zsh`)
appends an idempotent, **interactive-only** (`[[ $- == *i* ]]`, so scp/rsync and
scripts stay bash) marked block to `~/.bashrc` that `export SHELL`s zsh and
`exec zsh`, and makes `~/.bash_profile` source `~/.bashrc` so login shells (tmux,
ssh) hit it too. macOS is excluded from this branch (its accounts live in dscl,
not passwd files, and `chsh` works there). The textbook chsh path is unchanged
for local accounts.

**Test seam — leave it:** the line `if [[ -n "${INSTALL_DEPS_SOURCE_ONLY:-}" ]];
then return …` near the middle of `install-deps.sh` exists ONLY so
`tests/shell/default_shell_test.sh` can `source` the function defs (without
running any installs) and exercise the chsh decision logic against stubbed
seams. Unset in normal runs, so it's skipped.

## Things that look weird but are intentional

- **Mouse is disabled in nvim AND tmux** (`vim.opt.mouse = ""` and
  `set -g mouse off`). User preference -- keyboard-only, no accidental
  selection/scroll behaviors stealing focus across panes. Do not "fix".
  Guarded for tmux by `tests/tmux/option_test.sh` (`check mouse off`).
- **Arrow keys are mapped to `<Nop>`** in `vim-options.lua`. User
  preference; hjkl-only navigation enforced.
- **`vim.opt.clipboard = "unnamedplus"`** even on macOS — works fine via
  pbcopy/pbpaste. The single-register `unnamed` value would lock WSL/Linux
  out.
- **`shells/zshrc` has shellcheck disable directives** at the top — zsh
  has glob qualifiers (`(#qN.mh+24)`) that shellcheck (a bash linter)
  cannot parse. The directives suppress the noise; the file is otherwise
  shellcheck-clean.
- **`nvim/lazy-lock.json` is tracked** (NOT in `.gitignore`). This is how
  every machine ends up on the same plugin commits.
- **`ghostty/config` sets `window-save-state = default`** (NOT `always`)
  alongside `maximize = true`. It's not an oversight: on macOS
  `window-save-state = always` restores the last window geometry *after*
  `maximize` applies, overriding it — so the window wouldn't reliably open
  maximized. `default` keeps normal launches maximized while still allowing
  macOS OS-driven session restore (save-state is a no-op on Linux/GTK).
- **fzf in `shells/zshrc` is guarded by `command -v fzf`** and prefers
  `fzf --zsh` (fzf ≥ 0.48), falling back to share-dir key-binding files for
  older distro builds. The guard is load-bearing: `tests/shell/zsh_startup_test.sh`
  sources zshrc with no fzf installed and expects exit 0, so an unguarded
  `source <(fzf --zsh)` would break it. Installed by default by `install-deps.sh`.
- **starship `[directory]` shows the FULL path** (`truncation_length = 0`,
  `truncate_to_repo = false`) — not starship's default of 3 folders collapsed to
  the git-repo root. Intentional; raise `truncation_length` / flip
  `truncate_to_repo` to shorten. Guarded by `tests/starship/directory_test.sh`.
- **`[directory.substitutions]` are "icon + name"** (e.g. `Downloads` →
  download-glyph + `Downloads`), using Material Design Icon codepoints (U+F0xxx)
  verified present in Hack Nerd Font. Keep the folder name in the value so it
  stays readable if a glyph is missing on some machine, and **never let a value
  become a bare space** — an earlier encoding pass stripped three of these to
  U+0020, which rendered `~/Downloads`, `~/Music`, `~/Pictures` as a blank `~/`.
  The same `directory_test.sh` guards against whitespace-only values.

## When you're about to make a change

1. Run `make test` locally. Get baseline.
2. Make the change.
3. Update tests in the same diff (add a regression test for the new
   behavior; update an invariant assertion if you changed something this
   doc says is invariant).
4. Update this CLAUDE.md if you've changed any of the invariants or added a
   new common workflow.
5. Update `README.md` if you've changed the install path / install command.
6. Run `make test` again. Green.
7. Stage everything, commit.

If a test breaks: fix the cause, not the test. The test names are
deliberately worded as failure modes ("regression guard for …") — read them
carefully before "fixing" the test.

## Plan / history

The full design rationale that drove the current layout is at
`~/.claude/plans/this-directory-has-my-idempotent-seahorse.md`. If
something feels arbitrary, the plan file likely has the why.
