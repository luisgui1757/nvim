# bootstrap.ps1 -- symlink dotfiles into Windows-appropriate paths.
# Requires either an elevated PowerShell session OR Developer Mode enabled
# (Settings -> Privacy & security -> For developers -> Developer Mode = On).
#
# Usage:
#   .\bootstrap.ps1
#   .\bootstrap.ps1 -DryRun
#   .\bootstrap.ps1 -MergeWindowsTerminal     # also merge WT settings fragment

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$MergeWindowsTerminal
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Get-UniqueBackupPath {
    param([Parameter(Mandatory)] [string]$Base)
    if (-not (Test-Path -LiteralPath $Base)) { return $Base }
    $i = 1
    while (Test-Path -LiteralPath "$Base.$i") { $i++ }
    return "$Base.$i"
}

function Write-Step { param([string]$msg) Write-Host "  $msg" }

function New-SymLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$Source,
        [Parameter(Mandatory)] [string]$Destination
    )

    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $parent)) {
        if ($DryRun) {
            Write-Step "mkdir   $parent"
        } else {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
    }

    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            $existing = $item.Target
            if ($existing -is [array]) { $existing = $existing[0] }
            if ($existing -eq $Source) {
                Write-Step "ok       $Destination -> $Source"
                return
            }
            # Existing symlink points elsewhere -- back up the symlink itself
            # before replacing so the prior user choice is not silently lost.
            $backup = Get-UniqueBackupPath "$Destination.bak.$Timestamp"
            if ($DryRun) {
                Write-Step "relink   $Destination (was -> $existing; backup -> $backup)"
                return
            }
            Move-Item -LiteralPath $Destination -Destination $backup -Force
            New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
            Write-Step "relinked $Destination -> $Source  (prior symlink -> $backup)"
            return
        }

        # Real file/dir at the destination -- back it up.
        $backup = Get-UniqueBackupPath "$Destination.bak.$Timestamp"
        if ($DryRun) {
            Write-Step "backup   $Destination -> $backup; then symlink"
            return
        }
        try {
            Move-Item -LiteralPath $Destination -Destination $backup -Force -ErrorAction Stop
        } catch {
            Write-Host ""
            Write-Host "  FAIL     could not back up: $Destination" -ForegroundColor Red
            Write-Host "           reason: $($_.Exception.Message)" -ForegroundColor Red
            if ($_.Exception.Message -match 'being used by another process') {
                # Use single-quoted strings -- no interpolation needed, and
                # this dodges the backtick-escapes-the-closing-quote bug that
                # made an earlier "...loaded the old `$PROFILE`" string
                # silently swallow the rest of the file at parse time.
                Write-Host '           This usually means a running program has files open inside' -ForegroundColor Yellow
                Write-Host '           the target. Most common culprits, in order:' -ForegroundColor Yellow
                Write-Host '             1. A running Neovim / Neovide / nvim-qt:' -ForegroundColor Yellow
                Write-Host '                Get-Process -Name nvim*, neovide -EA SilentlyContinue | Stop-Process -Force' -ForegroundColor Yellow
                Write-Host '             2. Another PowerShell window that loaded the old $PROFILE' -ForegroundColor Yellow
                Write-Host '             3. Windows Defender / antivirus scanning the directory' -ForegroundColor Yellow
                Write-Host '             4. A Mason-installed LSP server still attached' -ForegroundColor Yellow
                Write-Host '           Close the holder, then re-run .\bootstrap.ps1 (idempotent).' -ForegroundColor Yellow
            }
            throw
        }
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
        Write-Step "backed up $Destination -> $backup; linked -> $Source"
        return
    }

    if ($DryRun) {
        Write-Step "link     $Destination -> $Source"
        return
    }
    New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    Write-Step "linked   $Destination -> $Source"
}

function Test-CanCreateSymlinks {
    try {
        $tmp = Join-Path $env:TEMP "symlink-probe-$([guid]::NewGuid())"
        $target = Join-Path $env:TEMP "symlink-probe-target-$([guid]::NewGuid())"
        New-Item -ItemType File -Path $target -Force | Out-Null
        New-Item -ItemType SymbolicLink -Path $tmp -Target $target -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

Write-Host "bootstrap.ps1: repo=$RepoRoot dry-run=$DryRun"
Write-Host

# DryRun must not touch the filesystem. The symlink-creation probe writes
# temp files, so skip it entirely in DryRun mode.
if ($DryRun) {
    Write-Host "  (DryRun: skipping symlink-privilege probe)"
} elseif (-not (Test-CanCreateSymlinks)) {
    Write-Error @"
Cannot create symbolic links. Either:
  - Run this from an elevated PowerShell, OR
  - Enable Developer Mode: Settings -> Privacy & security -> For developers -> Developer Mode = On
"@
    exit 1
}

# ---- Self-link guard ---------------------------------------------------------
# Refuse to run if the symlink we would create would overlap the repo. If the
# destination is already a symlink, New-SymLink handles relink / no-op cases
# correctly, so the self-link risk only exists when the destination is a real
# directory or file.
$nvimDest = Join-Path $env:LOCALAPPDATA 'nvim'
$destItem = Get-Item -LiteralPath $nvimDest -Force -ErrorAction SilentlyContinue
$destIsRealDir = $destItem -and ($destItem.PSIsContainer) -and ($destItem.LinkType -ne 'SymbolicLink')
if ($destIsRealDir) {
    $repoResolved     = (Resolve-Path -LiteralPath $RepoRoot -ErrorAction SilentlyContinue).Path
    $repoNvimResolved = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'nvim') -ErrorAction SilentlyContinue).Path
    $destResolved     = (Resolve-Path -LiteralPath $nvimDest -ErrorAction SilentlyContinue).Path
    $selfLink = $false
    # Scenario A: the repo nvim subdir IS the destination dir
    if ($repoNvimResolved -and $destResolved -and ($repoNvimResolved -eq $destResolved)) { $selfLink = $true }
    # Scenario B: the repo root IS the destination dir (clone -> %LOCALAPPDATA%\nvim)
    if ($repoResolved -and $destResolved -and ($repoResolved -eq $destResolved))       { $selfLink = $true }
    if ($selfLink) {
        Write-Error @"
bootstrap.ps1: REFUSING to run.

  Repo root:           $repoResolved
  Repo nvim dir:       $repoNvimResolved
  Symlink destination: $nvimDest

  The symlink we would create would overlap your repo. Running
  bootstrap would back up the repo and replace it with a symlink
  to nothing.

  Move the repo elsewhere first (e.g. `$env:USERPROFILE\dotfiles`) and re-run.
"@
        exit 1
    }
}

# ---- Links -------------------------------------------------------------------
New-SymLink -Source (Join-Path $RepoRoot 'nvim')                       -Destination $nvimDest
New-SymLink -Source (Join-Path $RepoRoot 'starship\starship.toml')     -Destination (Join-Path $env:USERPROFILE '.config\starship.toml')
New-SymLink -Source (Join-Path $RepoRoot 'shells\powershell_profile.ps1') -Destination $PROFILE

# Claude Code settings (repo root claude/, not under nvim/). New-SymLink
# creates %USERPROFILE%\.claude\ if absent and backs up any prior file/link.
# Note: statusline-command.sh is a bash script -- it only runs under
# Git-Bash / WSL on Windows; settings.json itself is the portable part.
$claudeDir = Join-Path $env:USERPROFILE '.claude'
New-SymLink -Source (Join-Path $RepoRoot 'claude\settings.json')         -Destination (Join-Path $claudeDir 'settings.json')
New-SymLink -Source (Join-Path $RepoRoot 'claude\statusline-command.sh') -Destination (Join-Path $claudeDir 'statusline-command.sh')

# Optional: WSL Ubuntu access -- symlinks inside WSL handled by bootstrap.sh.

# ---- Optional WT fragment merge ----------------------------------------------
if ($MergeWindowsTerminal) {
    $wtSettingsCandidates = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )
    $wtSettings = $wtSettingsCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $wtSettings) {
        Write-Warning "Windows Terminal settings.json not found; skipping merge."
    } else {
        $fragmentPath = Join-Path $RepoRoot 'windows-terminal\settings.fragment.jsonc'
        # Strip start-of-line // comments WITHOUT a regex literal that contains
        # both // and $ -- PS 5.1 has been observed mis-tokenizing that pattern
        # and reporting "missing terminator" far downstream from the real issue.
        $fragmentLines = Get-Content -LiteralPath $fragmentPath | Where-Object {
            $_ -notmatch "^\s*//"
        }
        $fragment = ($fragmentLines -join "`n") | ConvertFrom-Json

        $backup = Get-UniqueBackupPath "$wtSettings.bak.$Timestamp"
        if ($DryRun) {
            Write-Step "merge    $wtSettings (backup -> $backup)"
        } else {
            Copy-Item -LiteralPath $wtSettings -Destination $backup -Force
            $current = Get-Content -Raw -LiteralPath $wtSettings | ConvertFrom-Json

            # Defensive: initialize containers that a damaged or minimal
            # settings.json might be missing.
            if ($null -eq $current.profiles) {
                $current | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force
            }

            # Top-level scalar merge. Written as straight-line if-statements
            # rather than a foreach over an array literal because some PS 5.1
            # parser quirks have made array literals unreliable in this exact
            # block on user machines.
            function Set-OrAdd-Property {
                param($obj, [string]$name, $value)
                if ($null -eq $obj.$name) {
                    $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
                } else {
                    $obj.$name = $value
                }
            }
            if ($null -ne $fragment.copyFormatting)        { Set-OrAdd-Property $current "copyFormatting"        $fragment.copyFormatting }
            if ($null -ne $fragment.copyOnSelect)          { Set-OrAdd-Property $current "copyOnSelect"          $fragment.copyOnSelect }
            if ($null -ne $fragment.firstWindowPreference) { Set-OrAdd-Property $current "firstWindowPreference" $fragment.firstWindowPreference }
            if ($null -ne $fragment.initialRows)           { Set-OrAdd-Property $current "initialRows"           $fragment.initialRows }
            if ($null -ne $fragment.theme)                 { Set-OrAdd-Property $current "theme"                 $fragment.theme }
            if ($null -ne $fragment.useAcrylicInTabRow)    { Set-OrAdd-Property $current "useAcrylicInTabRow"    $fragment.useAcrylicInTabRow }
            if ($null -ne $fragment.windowingBehavior)     { Set-OrAdd-Property $current "windowingBehavior"     $fragment.windowingBehavior }

            if ($null -eq $current.profiles.defaults) {
                $current.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue $fragment.profiles.defaults -Force
            } else {
                $current.profiles.defaults = $fragment.profiles.defaults
            }
            $current.actions = $fragment.actions
            $current.schemes = $fragment.schemes
            $current.themes  = $fragment.themes
            $tmp = "$wtSettings.tmp"
            $current | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $tmp -Encoding UTF8
            Move-Item -Force -LiteralPath $tmp -Destination $wtSettings
            Write-Step "merged   $wtSettings (backup -> $backup)"
        }
    }
}

Write-Host
Write-Host "bootstrap.ps1: done"
if ($DryRun) { Write-Host "(dry run -- no changes were made)" }
