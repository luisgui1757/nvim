# PowerShell profile -- cross-version (5.1 + 7+), Rose Pine styled.

$ErrorActionPreference = 'Continue'

# ---- Path constants (cross-platform: pwsh runs on Windows + macOS + Linux) ---
$script:CacheDir = if ($env:LOCALAPPDATA) {
    $env:LOCALAPPDATA
} elseif ($env:XDG_CACHE_HOME) {
    $env:XDG_CACHE_HOME
} elseif ($env:HOME) {
    Join-Path $env:HOME '.cache'
} else {
    [System.IO.Path]::GetTempPath()
}
if (-not (Test-Path -LiteralPath $script:CacheDir)) {
    New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null
}
$script:StarshipInitPath = Join-Path $script:CacheDir 'starship.ps1'

$script:HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { '~' }
$script:StarshipConfigPath = $(if ($env:STARSHIP_CONFIG) {
    $env:STARSHIP_CONFIG
} else {
    Join-Path $script:HomeDir '.config' 'starship.toml'
})

# ---- Precompile Starship init (idempotent; regenerates when toml is newer) ---
function Confirm-StarshipInitScript {
    [CmdletBinding()]
    param(
        [string]$InitPath = $script:StarshipInitPath,
        [string]$ConfigPath = $script:StarshipConfigPath
    )

    $regenerate = -not (Test-Path -LiteralPath $InitPath)
    if (-not $regenerate -and (Test-Path -LiteralPath $ConfigPath)) {
        $initTime = (Get-Item -LiteralPath $InitPath).LastWriteTime
        $configTime = (Get-Item -LiteralPath $ConfigPath).LastWriteTime
        if ($configTime -gt $initTime) { $regenerate = $true }
    }

    if ($regenerate) {
        Write-Verbose 'Generating precompiled Starship init script...'
        $init = & starship init powershell --print-full-init
        # Force UTF-8 (no BOM) so unicode glyphs survive on Windows PowerShell 5.
        Set-Content -LiteralPath $InitPath -Value $init -Encoding UTF8
    }
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Confirm-StarshipInitScript
    . $script:StarshipInitPath
}

# ---- PSReadLine (history prediction + Rose Pine colors + menu complete) ------
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    if ((Get-Module PSReadLine).Version -ge [Version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineOption -Colors @{
        Command            = '#c4a7e7'  # iris
        Parameter          = '#9ccfd8'  # foam
        String             = '#f6c177'  # gold
        Operator           = '#ebbcba'  # rose
        Variable           = '#e0def4'  # text
        Number             = '#eb6f92'  # love
        Type               = '#9ccfd8'  # foam
        Comment            = '#6e6a86'  # muted
        Keyword            = '#c4a7e7'  # iris
        Error              = '#eb6f92'  # love
        Selection          = '#26233a'  # overlay
        ContinuationPrompt = '#6e6a86'
        Default            = '#e0def4'
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}
