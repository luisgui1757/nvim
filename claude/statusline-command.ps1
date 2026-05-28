$InputJson = [Console]::In.ReadToEnd()

try {
    $Data = $InputJson | ConvertFrom-Json -ErrorAction Stop
} catch {
    [Console]::Out.Write(" |  | no data")
    exit 0
}

$CwdPath = $Data.workspace.current_dir
if (-not $CwdPath) {
    $CwdPath = $Data.cwd
}

$Cwd = ""
if ($CwdPath) {
    $Cwd = Split-Path -Leaf ([string]$CwdPath)
    if (-not $Cwd) {
        $Cwd = [string]$CwdPath
    }
}

$Model = ""
if ($Data.model.display_name) {
    $Model = [string]$Data.model.display_name
}

$Used = $Data.context_window.current_usage.input_tokens
$Total = $Data.context_window.context_window_size
$Pct = $Data.context_window.used_percentage

$Esc = [char]27
$Green = "$Esc[32m"
$Yellow = "$Esc[33m"
$Red = "$Esc[31m"
$Reset = "$Esc[0m"

$CtxColored = "no data"
if ($null -ne $Pct -and $null -ne $Used -and $null -ne $Total -and "$Pct" -ne "" -and "$Used" -ne "" -and "$Total" -ne "") {
    $PctInt = [int][Math]::Round([double]$Pct)
    if ($PctInt -lt 50) {
        $Color = $Green
    } elseif ($PctInt -le 80) {
        $Color = $Yellow
    } else {
        $Color = $Red
    }
    $CtxColored = "$Color$Used/$Total ($PctInt%)$Reset"
}

[Console]::Out.Write("$Cwd | $Model | $CtxColored")
