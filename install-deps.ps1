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

# ---- Package-manager detection + scoop bootstrap -----------------------------
function Get-AvailablePM {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return 'winget' }
    if (Get-Command choco  -ErrorAction SilentlyContinue) { return 'choco'  }
    if (Get-Command scoop  -ErrorAction SilentlyContinue) { return 'scoop'  }
    return $null
}

function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) { return $true }
    Write-Host "Scoop is not installed. It is a userspace package manager that"
    Write-Host "carries tools missing from winget/choco (taplo, win32yank, etc.)."
    if (-not (Ask "Install Scoop via the official one-liner?")) { return $false }
    if ($DryRun) {
        Write-Host "  would: irm get.scoop.sh | iex"
        return $false
    }
    try {
        # The official scoop bootstrap. RemoteSigned policy is needed for the
        # script; we set it for the current process only.
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
        Invoke-Expression (Invoke-RestMethod -Uri 'https://get.scoop.sh')
        # Add the standard extras bucket so we get things like win32yank.
        scoop bucket add extras 2>$null | Out-Null
        scoop bucket add nerd-fonts 2>$null | Out-Null
        return [bool](Get-Command scoop -ErrorAction SilentlyContinue)
    } catch {
        Write-Warning ("Scoop install failed: " + $_.Exception.Message)
        return $false
    }
}

# Ask early — needed by the catalog logic below.
function Ask {
    param([string]$prompt)
    if ($All) { return $true }
    $resp = Read-Host "  $prompt [Y/n]"
    if ([string]::IsNullOrWhiteSpace($resp)) { return $true }
    return ($resp -match '^[Yy]')
}

$Pm = Get-AvailablePM

# If no package manager at all, try scoop first (no admin required).
if (-not $Pm) {
    Write-Warning "No package manager detected (winget / choco / scoop)."
    if (Install-Scoop) { $Pm = Get-AvailablePM }
}

# Even when winget/choco are available, scoop unlocks extras
# (taplo, win32yank, nerd-fonts bucket). Offer it as a complement.
if ($Pm -and -not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Detected $Pm. Scoop is also recommended -- it carries taplo,"
    Write-Host "win32yank, and the nerd-fonts bucket that $Pm does not have."
    Install-Scoop | Out-Null
}

Write-Host ""
Write-Host ("install-deps: primary PM=$Pm  scoop=" + [bool](Get-Command scoop -ErrorAction SilentlyContinue) + "  dry-run=$DryRun  yes-all=$All")
Write-Host ""

if (-not $Pm) {
    Write-Warning "No supported package manager available. Install winget from the"
    Write-Warning "Microsoft Store ('App Installer'), or accept the Scoop offer above."
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

    # Pick the best PM that actually has this package. Primary $Pm first,
    # then scoop if available (scoop has wider coverage for niche tools),
    # then anything else still available.
    $pmsToTry = @($Pm)
    foreach ($alt in @('scoop','winget','choco')) {
        if ($alt -ne $Pm -and (Get-Command $alt -ErrorAction SilentlyContinue)) {
            $pmsToTry += $alt
        }
    }
    $chosenPm = $null; $chosenPkg = $null
    foreach ($p in $pmsToTry) {
        if ($entry.$p) { $chosenPm = $p; $chosenPkg = $entry.$p; break }
    }
    if (-not $chosenPm) {
        Write-Host ("  manual    {0,-26} not in winget/choco/scoop; install separately" -f $tool)
        return
    }

    $purpose = $entry.purpose
    $promptText = if ($purpose) { "Install ${tool} via ${chosenPm} (${purpose})?" } else { "Install ${tool} via ${chosenPm}?" }
    if (-not (Ask $promptText)) {
        Write-Host ("  skipped   {0,-26}" -f $tool)
        return
    }
    if ($DryRun) {
        Write-Host ("  would:    $chosenPm install $chosenPkg")
        return
    }
    switch ($chosenPm) {
        'winget' { winget install --id $chosenPkg -e --accept-source-agreements --accept-package-agreements --silent }
        'choco'  { choco install $chosenPkg -y }
        'scoop'  { scoop install $chosenPkg }
    }
}

# ---- Hack Nerd Font: prefer scoop bucket, fall back to direct download+register
function Install-HackNerdFont {
    # Already installed?
    $userFonts = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $sysFonts = "$env:WINDIR\Fonts"
    if ((Test-Path $userFonts -PathType Container) -and
        (Get-ChildItem -Path $userFonts -Filter "Hack*Nerd*" -ErrorAction SilentlyContinue)) {
        Write-Host ("  ok        {0,-26} already installed (user)" -f "Hack Nerd Font")
        return
    }
    if ((Test-Path $sysFonts -PathType Container) -and
        (Get-ChildItem -Path $sysFonts -Filter "Hack*Nerd*" -ErrorAction SilentlyContinue)) {
        Write-Host ("  ok        {0,-26} already installed (system)" -f "Hack Nerd Font")
        return
    }
    if (-not (Ask "Install Hack Nerd Font?")) {
        Write-Host ("  skipped   {0,-26}" -f "Hack Nerd Font")
        return
    }

    # Path 1: scoop with the nerd-fonts bucket — proper user-scope install.
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        if ($DryRun) {
            Write-Host "  would: scoop install nerd-fonts/Hack-NF"
            return
        }
        scoop bucket add nerd-fonts 2>$null | Out-Null
        scoop install nerd-fonts/Hack-NF
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("  installed {0,-26} via scoop" -f "Hack Nerd Font")
            return
        }
        Write-Warning "scoop install failed; falling back to direct download."
    }

    # Path 2: download Hack.zip and register fonts user-scope. No admin needed.
    if ($DryRun) {
        Write-Host "  would: download nerd-fonts/Hack.zip, extract, register in HKCU\\Fonts"
        return
    }
    try {
        $tmp = New-Item -ItemType Directory -Force -Path (Join-Path $env:TEMP "hack-nf-$([guid]::NewGuid())")
        $zip = Join-Path $tmp.FullName "Hack.zip"
        Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive -Path $zip -DestinationPath $tmp.FullName -Force

        $fontDest = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        if (-not (Test-Path $fontDest)) {
            New-Item -ItemType Directory -Force -Path $fontDest | Out-Null
        }
        $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        if (-not (Test-Path $regPath)) {
            New-Item -Path $regPath -Force | Out-Null
        }
        $installedCount = 0
        Get-ChildItem -Path $tmp.FullName -Recurse -Include *.ttf,*.otf | ForEach-Object {
            $destPath = Join-Path $fontDest $_.Name
            Copy-Item -LiteralPath $_.FullName -Destination $destPath -Force
            New-ItemProperty -Path $regPath -Name "$($_.BaseName) (TrueType)" `
                -Value $destPath -PropertyType String -Force | Out-Null
            $installedCount++
        }
        Remove-Item -Recurse -Force $tmp.FullName
        Write-Host ("  installed {0,-26} {1} font files registered in HKCU" -f "Hack Nerd Font", $installedCount)
        Write-Host "             (you may need to restart your terminal to see them)"
    } catch {
        Write-Warning ("Hack Nerd Font install failed: " + $_.Exception.Message)
        Write-Host  "  manual    download Hack.zip from nerd-fonts releases and install via the Fonts control panel."
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

Section "fonts"
Install-HackNerdFont

Section "Ghostty terminal (manual step on Windows)"
Write-Host "  manual    Ghostty does not have a Windows build yet."
Write-Host "            Use Windows Terminal (.\bootstrap.ps1 -MergeWindowsTerminal applies"
Write-Host "            the rose-pine fragment) or WezTerm for now."

Write-Host ""
Write-Host "install-deps: done"
if ($DryRun) { Write-Host "(dry run -- nothing was installed)" }
Write-Host ""
Write-Host "Next: run .\bootstrap.ps1 to symlink configs into place."
