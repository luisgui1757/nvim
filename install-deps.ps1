# install-deps.ps1 -- interactively install dependencies on Windows.
#
# Uses winget by default (preinstalled on Windows 11 and modern Windows 10
# builds). Falls back to chocolatey if winget is missing AND choco is present.
# Otherwise prints manual-install hints and continues.
#
# Usage:
#   .\install-deps.ps1            prompt Y/n for each tool
#   .\install-deps.ps1 -All       skip prompts, install everything
#   .\install-deps.ps1 -DryRun    print what would be installed without acting

[CmdletBinding()]
param(
    [switch]$All,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

# ---- Package-manager detection -----------------------------------------------
$Pm = $null
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $Pm = 'winget'
} elseif (Get-Command choco -ErrorAction SilentlyContinue) {
    $Pm = 'choco'
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    $Pm = 'scoop'
}

Write-Host ("install-deps: package manager=$Pm  dry-run=$DryRun  yes-all=$All")
Write-Host ""

if (-not $Pm) {
    Write-Warning "No supported package manager found (winget / choco / scoop)."
    Write-Warning "Install winget from the Microsoft Store ('App Installer') and re-run."
    exit 1
}

# ---- Per-tool: package id per PM. Empty string means "not available there". --
# Keys are the command name we check via Get-Command.
$Catalog = @{
    git                  = @{ winget = 'Git.Git';                          choco = 'git';                  scoop = 'git'                  ; purpose = 'version control' }
    nvim                 = @{ winget = 'Neovim.Neovim';                    choco = 'neovim';               scoop = 'neovim'               ; purpose = 'Neovim 0.11+ editor' }
    starship             = @{ winget = 'Starship.Starship';                choco = 'starship';             scoop = 'starship'             ; purpose = 'cross-shell prompt' }
    rg                   = @{ winget = 'BurntSushi.ripgrep.MSVC';          choco = 'ripgrep';              scoop = 'ripgrep'              ; purpose = 'Telescope live_grep backend' }
    fd                   = @{ winget = 'sharkdp.fd';                       choco = 'fd';                   scoop = 'fd'                   ; purpose = 'Telescope find_files backend' }
    make                 = @{ winget = 'GnuWin32.Make';                    choco = 'make';                 scoop = 'make'                 ; purpose = 'plugin builds (LuaSnip jsregexp)' }
    pwsh                 = @{ winget = 'Microsoft.PowerShell';             choco = 'powershell-core';      scoop = 'pwsh'                 ; purpose = 'modern PowerShell 7' }
    'win32yank'          = @{ winget = '';                                 choco = 'win32yank';            scoop = 'win32yank'            ; purpose = 'clipboard bridge for WSL nvim' }
    node                 = @{ winget = 'OpenJS.NodeJS.LTS';                choco = 'nodejs-lts';           scoop = 'nodejs-lts'           ; purpose = 'prettier + markdown-preview' }
    python               = @{ winget = 'Python.Python.3.12';               choco = 'python';               scoop = 'python'               ; purpose = 'pyright + tooling' }
    jq                   = @{ winget = 'jqlang.jq';                        choco = 'jq';                   scoop = 'jq'                   ; purpose = 'JSON CLI for statusline scripts' }
    shellcheck           = @{ winget = 'koalaman.shellcheck';              choco = 'shellcheck';           scoop = 'shellcheck'           ; purpose = 'shell-script linter' }
    hyperfine            = @{ winget = 'sharkdp.hyperfine';                choco = 'hyperfine';            scoop = 'hyperfine'            ; purpose = 'starship perf benchmark' }
    taplo                = @{ winget = '';                                 choco = '';                     scoop = 'taplo'                ; purpose = 'TOML linter' }
}

# Some Catalog keys (e.g. "rg") map to a different actual binary on Windows
# than on Unix. Provide a name -> binary mapping for Get-Command checks.
$BinaryName = @{
    rg          = 'rg'
    fd          = 'fd'
    nvim        = 'nvim'
    pwsh        = 'pwsh'
    'win32yank' = 'win32yank'
    starship    = 'starship'
    git         = 'git'
    make        = 'make'
    node        = 'node'
    python      = 'python'
    jq          = 'jq'
    shellcheck  = 'shellcheck'
    hyperfine   = 'hyperfine'
    taplo       = 'taplo'
}

function Test-Tool {
    param([string]$name)
    return [bool](Get-Command $BinaryName[$name] -ErrorAction SilentlyContinue)
}

function Ask {
    param([string]$prompt)
    if ($All) { return $true }
    $resp = Read-Host "  $prompt [Y/n]"
    if ([string]::IsNullOrWhiteSpace($resp)) { return $true }
    return ($resp -match '^[Yy]')
}

function Install-One {
    param([string]$tool)
    if (Test-Tool $tool) {
        Write-Host ("  ok        {0,-26} already installed" -f $tool)
        return
    }
    $entry = $Catalog[$tool]
    if (-not $entry) {
        Write-Host ("  skipped   {0,-26} no catalog entry" -f $tool)
        return
    }
    $pkg = $entry[$Pm]
    if (-not $pkg) {
        Write-Host ("  manual    {0,-26} not in $Pm repos; install separately" -f $tool)
        return
    }
    $purpose = $entry.purpose
    $promptText = if ($purpose) { "Install ${tool} (${purpose})?" } else { "Install ${tool}?" }
    if (-not (Ask $promptText)) {
        Write-Host ("  skipped   {0,-26}" -f $tool)
        return
    }
    if ($DryRun) {
        Write-Host ("  would:    $Pm install $pkg")
        return
    }
    switch ($Pm) {
        'winget' { winget install --id $pkg -e --accept-source-agreements --accept-package-agreements --silent }
        'choco'  { choco install $pkg -y }
        'scoop'  { scoop install $pkg }
    }
}

function Section { param([string]$title) Write-Host ""; Write-Host "== $title ==" }

# ---- Sections ----------------------------------------------------------------
Section "core editor stack"
Install-One git
Install-One nvim
Install-One make
Install-One rg
Install-One fd

Section "prompt"
Install-One starship

Section "modern shell (optional, you can stay on Windows PowerShell 5.1)"
Install-One pwsh

Section "language tooling (for LSP / formatter back-ends)"
Install-One python
Install-One node

Section "WSL clipboard bridge (skip if you don't use WSL nvim)"
Install-One win32yank

Section "developer / test dependencies (optional)"
Install-One jq
Install-One shellcheck
Install-One hyperfine
Install-One taplo

Section "fonts (manual step)"
Write-Host "  manual    Hack Nerd Font: download from"
Write-Host "            https://github.com/ryanoasis/nerd-fonts/releases (search Hack)"
Write-Host "            then double-click the .ttf files to install."

Section "Ghostty terminal (manual step on Windows)"
Write-Host "  manual    Ghostty does not have a Windows build yet."
Write-Host "            Use Windows Terminal (.\bootstrap.ps1 -MergeWindowsTerminal applies"
Write-Host "            the rose-pine fragment) or WezTerm for now."

Write-Host ""
Write-Host "install-deps: done"
if ($DryRun) { Write-Host "(dry run -- nothing was installed)" }
Write-Host ""
Write-Host "Next: run .\bootstrap.ps1 to symlink configs into place."
