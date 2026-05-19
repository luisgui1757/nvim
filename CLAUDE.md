# Repo guide for Claude (and humans coming back to this cold)

This file is the on-ramp. If you're a future Claude session, read this **before**
touching anything. If you're me six months from now and forgot how the install
script works, read this too.

## What this repo is

Cross-platform dotfiles: Neovim (lazy.nvim), Starship, Ghostty, Windows
Terminal, tmux, zshrc, PowerShell profile, Claude Code settings. Single source
of truth — `bootstrap.sh` (macOS / Linux / WSL) and `bootstrap.ps1` (Windows)
symlink everything into OS-appropriate locations. The repo itself should live
at `~/dotfiles/` (NOT at `~/.config/nvim/` — the installer creates that as a
symlink **pointing into** the repo).

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
muted    #6e6a86   text    #e0def4
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

## Things that look weird but are intentional

- **Mouse is disabled in nvim** (`vim.opt.mouse = ""`). User preference;
  do not "fix".
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
