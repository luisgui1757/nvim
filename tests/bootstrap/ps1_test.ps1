BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:Bootstrap = Join-Path $script:RepoRoot "bootstrap.ps1"
}

Describe "bootstrap.ps1" {

    BeforeEach {
        $script:FakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("bs-" + [System.Guid]::NewGuid())
        $script:FakeLocalAppData = Join-Path $script:FakeHome "AppData/Local"
        # APPDATA (Roaming) is where the lazygit config.yml is symlinked on
        # Windows; keep it inside FakeHome so the test does not pollute the
        # real user profile when CI runs as a logged-in account.
        $script:FakeAppData = Join-Path $script:FakeHome "AppData/Roaming"
        New-Item -ItemType Directory -Force -Path $script:FakeHome | Out-Null
        New-Item -ItemType Directory -Force -Path $script:FakeLocalAppData | Out-Null
        New-Item -ItemType Directory -Force -Path $script:FakeAppData | Out-Null

        $script:OldUserProfile  = $env:USERPROFILE
        $script:OldLocalAppData = $env:LOCALAPPDATA
        $script:OldAppData      = $env:APPDATA
        $env:USERPROFILE = $script:FakeHome
        $env:LOCALAPPDATA = $script:FakeLocalAppData
        $env:APPDATA = $script:FakeAppData
    }

    AfterEach {
        $env:USERPROFILE = $script:OldUserProfile
        $env:LOCALAPPDATA = $script:OldLocalAppData
        $env:APPDATA = $script:OldAppData
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $script:FakeHome
    }

    It "fresh install creates the expected symlinks" {
        & $script:Bootstrap | Out-Null
        $nvim = Get-Item (Join-Path $env:LOCALAPPDATA 'nvim')
        $nvim.LinkType | Should -Be 'SymbolicLink'
        # tmux.conf -> the shared tmux config; psmux reads it on the Windows side
        $tmux = Get-Item (Join-Path $env:USERPROFILE '.tmux.conf')
        $tmux.LinkType | Should -Be 'SymbolicLink'
        $tmux.Target  | Should -Match 'tmux\\tmux\.conf$'
        # tmux.windows.conf -> psmux-only overlay (default-shell pwsh,
        # allow-predictions on, mouse-selection off). Main tmux.conf sources
        # it with `-q`, so the overlay being absent on Unix is silent.
        $tmuxWin = Get-Item (Join-Path $env:USERPROFILE '.tmux.windows.conf')
        $tmuxWin.LinkType | Should -Be 'SymbolicLink'
        $tmuxWin.Target  | Should -Match 'tmux\\tmux\.windows\.conf$'
        # lazygit config -- carries the Alt+J/Alt+K fallback so the
        # "move commit down/up" bindings survive the psmux ConPTY proxy
        # (Ctrl+J degrades to Enter without Win32-input-mode relay).
        $lazy = Get-Item (Join-Path $env:APPDATA 'lazygit/config.yml')
        $lazy.LinkType | Should -Be 'SymbolicLink'
        $lazy.Target  | Should -Match 'lazygit\\config\.yml$'
    }

    It "re-running is idempotent (no new backups)" {
        & $script:Bootstrap | Out-Null
        & $script:Bootstrap | Out-Null
        $backups = Get-ChildItem -Recurse -Force -Path $script:FakeHome -Filter "*.bak.*" -ErrorAction SilentlyContinue
        $backups.Count | Should -Be 0
    }

    It "non-symlink at target is backed up" {
        $profileDir = Split-Path $PROFILE
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
        Set-Content -LiteralPath $PROFILE -Value "# user content" -Encoding UTF8
        & $script:Bootstrap | Out-Null
        (Get-Item $PROFILE).LinkType | Should -Be 'SymbolicLink'
        $bak = Get-ChildItem -Path $profileDir -Filter "*.bak.*" | Select-Object -First 1
        $bak | Should -Not -BeNullOrEmpty
        (Get-Content -LiteralPath $bak.FullName) | Should -Be "# user content"
    }

    It "-DryRun changes nothing" {
        & $script:Bootstrap -DryRun | Out-Null
        Test-Path (Join-Path $env:LOCALAPPDATA 'nvim') | Should -Be $false
    }
}

Describe "bootstrap.ps1 -MergeWindowsTerminal" {

    BeforeEach {
        $script:FakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("bs-wt-" + [System.Guid]::NewGuid())
        $script:FakeLocalAppData = Join-Path $script:FakeHome "AppData/Local"
        # APPDATA (Roaming) -- bootstrap.ps1 always runs the link block, which
        # symlinks lazygit\config.yml under %APPDATA%. Confine that to FakeHome
        # so -MergeWindowsTerminal runs do not pollute the real user profile.
        $script:FakeAppData = Join-Path $script:FakeHome "AppData/Roaming"
        $script:WTPackageDir = Join-Path $script:FakeLocalAppData "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState"
        New-Item -ItemType Directory -Force -Path $script:WTPackageDir | Out-Null
        New-Item -ItemType Directory -Force -Path $script:FakeAppData | Out-Null
        $env:LOCALAPPDATA = $script:FakeLocalAppData
        $env:USERPROFILE = $script:FakeHome
        $env:APPDATA = $script:FakeAppData
        $script:WTSettings = Join-Path $script:WTPackageDir "settings.json"
    }

    AfterEach {
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $script:FakeHome
    }

    It "preserves the user's discovered profile list" {
        # Seed a minimal but realistic settings.json -- what WT auto-generates.
        @"
{
    "profiles": {
        "defaults": { "fontSize": 10 },
        "list": [
            { "guid": "{aaa}", "name": "Existing WSL", "source": "Windows.Terminal.Wsl" }
        ]
    },
    "actions": [],
    "schemes": [],
    "themes": []
}
"@ | Set-Content -LiteralPath $script:WTSettings -Encoding UTF8

        & $script:Bootstrap -MergeWindowsTerminal | Out-Null

        $merged = Get-Content -Raw -LiteralPath $script:WTSettings | ConvertFrom-Json
        $merged.profiles.list.Count | Should -Be 1
        $merged.profiles.list[0].name | Should -Be 'Existing WSL'
    }

    It "creates a *.bak.<timestamp> backup of the pre-merge settings" {
        '{"profiles":{"defaults":{},"list":[]},"actions":[],"schemes":[],"themes":[]}' |
            Set-Content -LiteralPath $script:WTSettings -Encoding UTF8

        & $script:Bootstrap -MergeWindowsTerminal | Out-Null

        $bak = Get-ChildItem -Path $script:WTPackageDir -Filter "settings.json.bak.*" | Select-Object -First 1
        $bak | Should -Not -BeNullOrEmpty
    }

    It "applies the rose-pine theme and scheme from the fragment" {
        '{"profiles":{"defaults":{},"list":[]},"actions":[],"schemes":[],"themes":[]}' |
            Set-Content -LiteralPath $script:WTSettings -Encoding UTF8

        & $script:Bootstrap -MergeWindowsTerminal | Out-Null

        $merged = Get-Content -Raw -LiteralPath $script:WTSettings | ConvertFrom-Json
        $merged.theme | Should -Be 'rose-pine'
        ($merged.schemes | Where-Object { $_.name -eq 'rose-pine' }) | Should -Not -BeNullOrEmpty
        ($merged.themes | Where-Object { $_.name -eq 'rose-pine' }) | Should -Not -BeNullOrEmpty
    }

    It "tolerates a settings.json missing the profiles object" {
        '{"actions":[]}' | Set-Content -LiteralPath $script:WTSettings -Encoding UTF8

        { & $script:Bootstrap -MergeWindowsTerminal } | Should -Not -Throw
        $merged = Get-Content -Raw -LiteralPath $script:WTSettings | ConvertFrom-Json
        $merged.profiles.defaults | Should -Not -BeNullOrEmpty
    }
}
