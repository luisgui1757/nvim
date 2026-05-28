# Manual test checklist

The automated suite covers the deterministic surface. Some things only
make sense to verify by eye — keep this checklist alongside any
significant change to the relevant area.

## Visual / GUI

- [ ] **Ghostty**, mac: opens with Rose Pine dark, translucent background
      reads cleanly over a coloured wallpaper, font is Hack Nerd at 13pt.
- [ ] **Ghostty**, mac, light mode: switches to Rose Pine Dawn when the
      system theme flips.
- [ ] **Windows Terminal**: rose-pine scheme applied; tabs use the
      configured theme; acrylic OFF on the body, ON in the tab row.
- [ ] **Tmux status bar**: rose-pine colors, prefix is `C-b`,
      `prefix r` reloads the conf and shows the "reloaded" message.
- [ ] **Starship prompt**: shows username pill, dir pill, git branch pill,
      git status icons (untracked/modified/staged), trailing time pill.

## Cross-OS clipboard round-trip

- [ ] **macOS**: yank in nvim, ⌘V into Notes — pastes.
- [ ] **WSL Ubuntu**: yank in nvim (inside tmux inside Windows Terminal),
      paste into a Windows app — pastes (requires `win32yank.exe`).
- [ ] **Linux X11**: same, with `xclip` installed.
- [ ] **Linux Wayland**: same, with `wl-clipboard`.

## LSP UX

- [ ] **C++ workspace** with `compile_commands.json`: hover, go-to-def,
      and clang-tidy diagnostics work in a real CMake project.
- [ ] **Rust workspace**: `cargo check` runs on save (rust-analyzer
      `checkOnSave`); inlay hints don't break visual layout.
- [ ] **Python with venv**: pyright picks up the venv interpreter
      (use `:LspInfo` to confirm).
- [ ] **CMakeLists.txt**: neocmake attaches; format-on-save runs gersemi
      without "Failed to format" toast.
- [ ] **PowerShell .ps1**: powershell_es attaches; signature help works.

## Setup on a fresh machine

- [ ] **New Mac**: `git clone`, `./setup.sh`, `exec zsh`, `nvim` opens
      and `:checkhealth` is clean except for optional system tools.
- [ ] **Fresh Windows**: clone, `.\setup.ps1`, optionally
      `.\bootstrap.ps1 -MergeWindowsTerminal`,
      new pwsh tab shows the rose-pine starship prompt; new WT tab has
      the rose-pine scheme; `nvim` works.
- [ ] **Fresh WSL Ubuntu**: clone, `./setup.sh`, `nvim` works;
      clipboard from WSL → Windows works via `win32yank.exe`.
