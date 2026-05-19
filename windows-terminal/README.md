# Windows Terminal — merge instructions

Windows Terminal **rewrites** its `settings.json` on every launch with discovered
profiles (PowerShell GUIDs, WSL distros, Azure Cloud Shell, Visual Studio shells,
etc.). A hard symlink either loses those entries or gets clobbered. So instead of
symlinking the file, we keep **only the user-owned keys** in
`settings.fragment.jsonc` and merge them in on each new machine.

## Path

```
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

(For the WT Preview the package is `Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe`.)

## What's in the fragment

- `actions` — keybindings.
- `profiles.defaults` — font (Hack Nerd Font 12), Rose Pine color scheme,
  acrylic off, padding, antialiasing.
- `schemes[rose-pine]` — the color scheme definition.
- `themes[rose-pine]` — the tab/window theme.
- Top-level: `copyFormatting`, `copyOnSelect`, `initialRows`,
  `useAcrylicInTabRow`, `windowingBehavior`, `firstWindowPreference`.

What's intentionally **not** in the fragment: anything WT auto-generates
(`profiles.list[]`, `defaultProfile` GUID, the per-machine VS / Ubuntu / Azure
entries).

## One-shot merge (PowerShell)

```powershell
$wtSettings = Resolve-Path "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_*\LocalState\settings.json"
$fragment = Get-Content -Raw -Path windows-terminal\settings.fragment.jsonc |
            ForEach-Object { $_ -replace '(?ms)^\s*//.*?$', '' } |
            ConvertFrom-Json

$current = Get-Content -Raw -Path $wtSettings | ConvertFrom-Json

# Top-level scalars. Keep the array on one line — PS 5.1 rejects both
# comma-continuation AND newline-separated string literals inside @() in
# an assignment expression. The one-line form parses cleanly in 5.1 + 7.
$topLevelKeys = @('copyFormatting','copyOnSelect','firstWindowPreference','initialRows','theme','useAcrylicInTabRow','windowingBehavior')
foreach ($key in $topLevelKeys) {
    if ($null -ne $fragment.$key) { $current.$key = $fragment.$key }
}

# Defaults, actions, schemes, themes (replace these sections wholesale)
$current.profiles.defaults = $fragment.profiles.defaults
$current.actions  = $fragment.actions
$current.schemes  = $fragment.schemes
$current.themes   = $fragment.themes

# Atomic write
$tmp = "$wtSettings.tmp"
$current | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tmp -Encoding UTF8
Move-Item -Force -LiteralPath $tmp -Destination $wtSettings
```

`bootstrap.ps1` will offer to run this merge for you, with a backup of the
pre-merge `settings.json` saved as `settings.json.bak.<timestamp>`.
