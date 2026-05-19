# setup.ps1 -- one-shot end-to-end install for Windows.
#
# Local usage (from a checked-out copy):
#   .\setup.ps1                  interactive: Y/n per dep, then symlink + sync
#   .\setup.ps1 -All             non-interactive: install everything missing
#   .\setup.ps1 -DryRun          preview every step
#   .\setup.ps1 -SkipDeps        already have nvim/starship; just bootstrap+sync
#   .\setup.ps1 -SkipBootstrap   already symlinked; just sync plugins+LSP
#   .\setup.ps1 -SkipNvim        skip nvim plugin + Mason sync
#   .\setup.ps1 -MergeWindowsTerminal     also merge the WT rose-pine fragment
#
# Remote usage (no checkout yet):
#   irm https://raw.githubusercontent.com/luisgui1757/nvim/main/setup.ps1 | iex
#
# The remote form clones the repo to $env:DOTFILES_DEST (default
# %USERPROFILE%\dotfiles) and re-invokes itself locally.

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$DryRun,
    [switch]$SkipDeps,
    [switch]$SkipBootstrap,
    [switch]$SkipNvim,
    [switch]$MergeWindowsTerminal
)

$ErrorActionPreference = 'Stop'

$RepoUrl     = 'https://github.com/luisgui1757/nvim.git'
$DefaultDest = Join-Path $env:USERPROFILE 'dotfiles'

# ---- Locate / clone the repo -------------------------------------------------
# When piped from `irm | iex` there is no $PSCommandPath, so we clone and
# re-invoke from the clone.
$ScriptDir = $null
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
}
if (-not $ScriptDir -or -not (Test-Path (Join-Path $ScriptDir 'bootstrap.ps1'))) {
    $dest = if ($env:DOTFILES_DEST) { $env:DOTFILES_DEST } else { $DefaultDest }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Error "setup.ps1: git is required to clone the repo. Install git first (e.g. winget install Git.Git)."
        exit 1
    }
    if (Test-Path (Join-Path $dest '.git')) {
        Write-Host "Repo already cloned at $dest. Pulling latest."
        git -C $dest pull --ff-only
    } else {
        Write-Host "Cloning $RepoUrl -> $dest"
        git clone $RepoUrl $dest
    }
    Write-Host ""
    Write-Host "Re-invoking setup.ps1 from the clone."
    & (Join-Path $dest 'setup.ps1') @PSBoundParameters
    exit $LASTEXITCODE
}

Set-Location $ScriptDir

# ---- Self-link guard ---------------------------------------------------------
$nvimTarget = Join-Path $env:LOCALAPPDATA 'nvim'
if ((Resolve-Path $ScriptDir).Path -eq (Resolve-Path $nvimTarget -ErrorAction SilentlyContinue).Path) {
    Write-Error @"
setup.ps1: the repo lives at $ScriptDir, which is the same path that
bootstrap.ps1 would symlink to itself. Move the repo elsewhere first
(e.g. %USERPROFILE%\dotfiles) and re-run setup.ps1.
"@
    exit 1
}

# ---- Forward flags to sub-scripts --------------------------------------------
$depsArgs = @()
if ($All)    { $depsArgs += '-All' }
if ($DryRun) { $depsArgs += '-DryRun' }

$bootstrapArgs = @()
if ($DryRun)               { $bootstrapArgs += '-DryRun' }
if ($MergeWindowsTerminal) { $bootstrapArgs += '-MergeWindowsTerminal' }

function Phase {
    param([string]$title)
    Write-Host ""
    Write-Host "================================================================"
    Write-Host "==  $title"
    Write-Host "================================================================"
}

# ---- Phase 1: dependencies ---------------------------------------------------
if (-not $SkipDeps) {
    Phase "Phase 1/4: install dependencies"
    & (Join-Path $ScriptDir 'install-deps.ps1') @depsArgs
} else {
    Write-Host ""
    Write-Host "skipped: Phase 1 (deps) via -SkipDeps"
}

# ---- Phase 2: symlink configs ------------------------------------------------
if (-not $SkipBootstrap) {
    Phase "Phase 2/4: symlink configs into place"
    & (Join-Path $ScriptDir 'bootstrap.ps1') @bootstrapArgs
} else {
    Write-Host ""
    Write-Host "skipped: Phase 2 (bootstrap) via -SkipBootstrap"
}

# ---- Phases 3 + 4: nvim sync -------------------------------------------------
if (-not $SkipNvim -and -not $DryRun) {
    if (Get-Command nvim -ErrorAction SilentlyContinue) {
        Phase "Phase 3/4: sync Neovim plugins (lazy.nvim)"
        & nvim --headless "+Lazy! sync" "+qa"

        Phase "Phase 4/4: install LSP servers + formatters (Mason)"
        Write-Host "  this can take 3-8 minutes on a fresh Windows machine."
        & nvim --headless "+MasonToolsInstallSync" "+qa"
    } else {
        Write-Host ""
        Write-Host "skipped: Phase 3-4 (nvim plugins) -- nvim not on PATH yet."
        Write-Host "         Open a new shell so PATH refreshes, then run:"
        Write-Host "             .\setup.ps1 -SkipDeps -SkipBootstrap"
    }
} elseif ($DryRun) {
    Write-Host ""
    Write-Host "skipped: Phase 3-4 (nvim plugins) in -DryRun mode"
} else {
    Write-Host ""
    Write-Host "skipped: Phase 3-4 (nvim plugins) via -SkipNvim"
}

# ---- Summary -----------------------------------------------------------------
Write-Host ""
Write-Host "================================================================"
Write-Host "==  setup.ps1: done"
Write-Host "================================================================"
Write-Host ""
Write-Host "Repo:    $ScriptDir"
Write-Host "Try it:  nvim  (then <Space>fg for live grep, :wnf to save w/o format)"
Write-Host ""
if ($DryRun) { Write-Host "(dry run -- nothing was actually installed or changed)" }
