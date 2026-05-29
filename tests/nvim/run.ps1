[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $RepoRoot

if (-not (Get-Command nvim -ErrorAction SilentlyContinue)) {
    Write-Host 'skipped: nvim not installed'
    exit 0
}

# Plenary sequential mode reports false failures on Windows. The default
# harness checks child exit codes without that signal parsing path.
& nvim --headless -u tests/nvim/minimal_init.lua -c "PlenaryBustedDirectory tests/nvim/spec { minimal_init = 'tests/nvim/minimal_init.lua' }" 2>&1
exit $LASTEXITCODE
