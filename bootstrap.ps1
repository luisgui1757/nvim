# bootstrap.ps1 — symlink dotfiles into Windows-appropriate paths.
# Requires either an elevated PowerShell session OR Developer Mode enabled
# (Settings → Privacy & security → For developers → Developer Mode = On).
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
                Write-Step "ok       $Destination → $Source"
                return
            }
            if ($DryRun) {
                Write-Step "relink   $Destination (was → $existing)"
                return
            }
            Remove-Item -LiteralPath $Destination -Force
            New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
            Write-Step "relinked $Destination → $Source"
            return
        }

        # Real file/dir at the destination — back it up.
        $backup = Get-UniqueBackupPath "$Destination.bak.$Timestamp"
        if ($DryRun) {
            Write-Step "backup   $Destination → $backup; then symlink"
            return
        }
        Move-Item -LiteralPath $Destination -Destination $backup -Force
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
        Write-Step "backed up $Destination → $backup; linked → $Source"
        return
    }

    if ($DryRun) {
        Write-Step "link     $Destination → $Source"
        return
    }
    New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    Write-Step "linked   $Destination → $Source"
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

# In dry-run mode, downgrade the symlink-privilege check to a warning so a
# non-elevated user without Developer Mode can still preview the install.
if (-not (Test-CanCreateSymlinks)) {
    if ($DryRun) {
        Write-Warning "Symlink creation not currently permitted; -DryRun will preview anyway. To actually install, enable Developer Mode or run elevated."
    } else {
        Write-Error @"
Cannot create symbolic links. Either:
  - Run this from an elevated PowerShell, OR
  - Enable Developer Mode: Settings → Privacy & security → For developers → Developer Mode = On
"@
        exit 1
    }
}

# ---- Links -------------------------------------------------------------------
$nvimDest = Join-Path $env:LOCALAPPDATA 'nvim'
New-SymLink -Source (Join-Path $RepoRoot 'nvim')                       -Destination $nvimDest
New-SymLink -Source (Join-Path $RepoRoot 'starship\starship.toml')     -Destination (Join-Path $env:USERPROFILE '.config\starship.toml')
New-SymLink -Source (Join-Path $RepoRoot 'shells\powershell_profile.ps1') -Destination $PROFILE

# Optional: WSL Ubuntu access — symlinks inside WSL handled by bootstrap.sh.

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
        $fragmentRaw = (Get-Content -Raw -LiteralPath $fragmentPath) -replace '(?ms)^\s*//.*?$', ''
        $fragment = $fragmentRaw | ConvertFrom-Json

        $backup = "$wtSettings.bak.$Timestamp"
        if ($DryRun) {
            Write-Step "merge    $wtSettings (backup → $backup)"
        } else {
            Copy-Item -LiteralPath $wtSettings -Destination $backup -Force
            $current = Get-Content -Raw -LiteralPath $wtSettings | ConvertFrom-Json

            # Defensive: initialize containers that a damaged or minimal
            # settings.json might be missing.
            if ($null -eq $current.profiles) {
                $current | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) -Force
            }

            'copyFormatting','copyOnSelect','firstWindowPreference','initialRows',
            'useAcrylicInTabRow','windowingBehavior','theme' | ForEach-Object {
                if ($null -ne $fragment.$_) {
                    if ($null -eq $current.$_) {
                        $current | Add-Member -NotePropertyName $_ -NotePropertyValue $fragment.$_ -Force
                    } else {
                        $current.$_ = $fragment.$_
                    }
                }
            }

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
            Write-Step "merged   $wtSettings (backup → $backup)"
        }
    }
}

Write-Host
Write-Host "bootstrap.ps1: done"
if ($DryRun) { Write-Host "(dry run — no changes were made)" }
