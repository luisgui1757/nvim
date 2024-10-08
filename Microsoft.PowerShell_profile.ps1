# Paths for the Starship init script and configuration
$starshipInitPath = "$env:LOCALAPPDATA\starship.ps1"
$starshipConfigPath = "$env:USERPROFILE\.config\starship.toml"

# Function to ensure the Starship init script is compiled
function Ensure-StarshipInitScript {
    # Check if the init script exists
    $initScriptExists = Test-Path $starshipInitPath

    # Check if the config file exists
    $configExists = Test-Path $starshipConfigPath

    # Determine if we need to regenerate the init script
    $regenerate = $false

    if (-not $initScriptExists) {
        $regenerate = $true
    } elseif ($configExists) {
        $initScriptTime = (Get-Item $starshipInitPath).LastWriteTime
        $configTime = (Get-Item $starshipConfigPath).LastWriteTime

        if ($configTime -gt $initScriptTime) {
            $regenerate = $true
        }
    }

    if ($regenerate) {
        Write-Host "Generating precompiled Starship init script..."
        $starshipInitScript = &starship init powershell --print-full-init
        Set-Content -Path $starshipInitPath -Value $starshipInitScript
    }
}

# Ensure the precompiled Starship init script exists and is up to date
Ensure-StarshipInitScript

# Source the precompiled Starship script
. $starshipInitPath
