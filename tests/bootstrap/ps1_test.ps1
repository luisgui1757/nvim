BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
    $script:Bootstrap = Join-Path $script:RepoRoot "bootstrap.ps1"
}

Describe "bootstrap.ps1" {

    BeforeEach {
        $script:FakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("bs-" + [System.Guid]::NewGuid())
        # LOCALAPPDATA is where lazygit reads its config from (v0.58+), and
        # where bootstrap.ps1 symlinks lazygit/config.yml. Keep it under the
        # FakeHome so the test sandboxes the symlink.
        $script:FakeLocalAppData = Join-Path $script:FakeHome "AppData/Local"
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
        # lazygit config -- symlinked into %LOCALAPPDATA%\lazygit (where
        # lazygit v0.58 actually reads from, NOT %APPDATA%). Carries the
        # Alt+J/Alt+K / F7/F8 fallbacks so "move commit down/up" survives
        # the psmux ConPTY proxy (Ctrl+J degrades to Enter there).
        $lazy = Get-Item (Join-Path $env:LOCALAPPDATA 'lazygit/config.yml')
        $lazy.LinkType | Should -Be 'SymbolicLink'
        $lazy.Target  | Should -Match 'lazygit\\config\.yml$'

        $statusPs1 = Get-Item (Join-Path $env:USERPROFILE '.claude/statusline-command.ps1')
        $statusPs1.LinkType | Should -Be 'SymbolicLink'
        $statusPs1.Target | Should -Match 'claude\\statusline-command\.ps1$'
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

    It "broken symlink at target is backed up and replaced" {
        $dest = Join-Path $env:LOCALAPPDATA 'nvim'
        $missing = Join-Path $script:FakeHome 'missing-nvim-target'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        New-Item -ItemType SymbolicLink -Path $dest -Target $missing | Out-Null

        & $script:Bootstrap | Out-Null

        $nvim = Get-Item -LiteralPath $dest -Force
        $nvim.LinkType | Should -Be 'SymbolicLink'
        $nvim.Target | Should -Match 'nvim$'
        $bak = Get-ChildItem -Path (Split-Path -Parent $dest) -Filter "nvim.bak.*" | Select-Object -First 1
        $bak | Should -Not -BeNullOrEmpty
    }

    It "warns when pwsh is missing for the psmux overlay" {
        Mock -CommandName Get-Command -MockWith { $null } -ParameterFilter { $Name -eq 'pwsh' }

        $out = & $script:Bootstrap 6>&1

        ($out | Out-String) | Should -Match 'psmux will fail to spawn panes without pwsh'
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
        # LOCALAPPDATA -- bootstrap.ps1 always runs the link block, which
        # symlinks lazygit\config.yml under %LOCALAPPDATA%. Confine that to FakeHome
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

    It "preserves custom Windows Terminal actions, schemes, and themes" {
        @"
{
    "profiles": { "defaults": {}, "list": [] },
    "actions": [
        { "command": "openSettings", "keys": "ctrl+comma" },
        { "command": "oldCopy", "keys": "ctrl+c" }
    ],
    "schemes": [
        { "name": "custom-scheme", "background": "#000000" },
        { "name": "rose-pine", "background": "#ffffff" }
    ],
    "themes": [
        { "name": "custom-theme", "tab": { "background": "#000000" } },
        { "name": "rose-pine", "tab": { "background": "#ffffff" } }
    ]
}
"@ | Set-Content -LiteralPath $script:WTSettings -Encoding UTF8

        & $script:Bootstrap -MergeWindowsTerminal | Out-Null

        $merged = Get-Content -Raw -LiteralPath $script:WTSettings | ConvertFrom-Json
        ($merged.actions | Where-Object { $_.keys -eq 'ctrl+comma' }) | Should -Not -BeNullOrEmpty
        ($merged.actions | Where-Object { $_.keys -eq 'ctrl+c' }).command.action | Should -Be 'copy'
        ($merged.schemes | Where-Object { $_.name -eq 'custom-scheme' }) | Should -Not -BeNullOrEmpty
        ($merged.schemes | Where-Object { $_.name -eq 'rose-pine' }).background | Should -Be '#191724'
        ($merged.themes | Where-Object { $_.name -eq 'custom-theme' }) | Should -Not -BeNullOrEmpty
        ($merged.themes | Where-Object { $_.name -eq 'rose-pine' }).tab.background | Should -Be '#191724ff'
    }
}
