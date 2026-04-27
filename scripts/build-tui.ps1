#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$tuiRoot = Join-Path $repoRoot "tui"
$binaryName = "win11-optimizer-tui.exe"

Push-Location $tuiRoot
try {
    cargo build --release
} finally {
    Pop-Location
}

$source = Join-Path $tuiRoot "target\release\$binaryName"
$destination = Join-Path $repoRoot $binaryName

if (-not (Test-Path $source)) {
    throw "Expected TUI binary was not produced: $source"
}

Copy-Item -Path $source -Destination $destination -Force
Write-Output "Built $destination"
