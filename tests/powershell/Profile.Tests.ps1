BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:Profile  = Join-Path $script:RepoRoot "shells/powershell_profile.ps1"
}

Describe "PowerShell profile" {

    It "passes PSScriptAnalyzer with no Warning+ findings" {
        $diags = Invoke-ScriptAnalyzer -Path $script:Profile -Severity Warning,Error
        if ($diags) { $diags | Format-Table | Out-String | Write-Host }
        $diags.Count | Should -Be 0
    }

    It "dot-sources cleanly even when starship is not on PATH" {
        # Use a sandbox PATH that does not contain starship.
        $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("ps-sandbox-" + [System.Guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
        $oldPath = $env:PATH
        try {
            $env:PATH = $sandbox
            $rc = 0
            pwsh -NoProfile -Command "& { . `"$($script:Profile.Replace('"','`"'))`"; exit 0 }"
            $rc = $LASTEXITCODE
            $rc | Should -Be 0
        } finally {
            $env:PATH = $oldPath
            Remove-Item -Recurse -Force $sandbox -ErrorAction SilentlyContinue
        }
    }

    It "uses an approved verb (Confirm- not Ensure-)" {
        $src = Get-Content -Raw -LiteralPath $script:Profile
        $src | Should -Match 'function Confirm-StarshipInitScript'
        $src | Should -Not -Match 'function Ensure-StarshipInitScript'
    }

    It "writes the starship init cache with UTF8 encoding" {
        $src = Get-Content -Raw -LiteralPath $script:Profile
        $src | Should -Match 'Set-Content[^|]*-Encoding\s+UTF8'
    }

    It "configures PSReadLine with Rose Pine colors" {
        $src = Get-Content -Raw -LiteralPath $script:Profile
        $src | Should -Match 'PredictionViewStyle\s+ListView'
        $src | Should -Match '#c4a7e7'   # iris
        $src | Should -Match '#f6c177'   # gold
    }
}
