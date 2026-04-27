# Win11 Optimizer Package Script
# Creates release packages with checksums
# Compatible with PowerShell 5.1+

param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Configuration
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $projectRoot) {
    $projectRoot = (Get-Location).Path
}
$distDir = Join-Path $projectRoot "dist"
$binaryName = "win11-optimizer-tui.exe"
$binaryPath = Join-Path $projectRoot $binaryName

# Validate version format
if ($Version -notmatch '^v?\d+\.\d+\.\d+') {
    Write-Host "ERROR: Invalid version format. Expected: v1.0.0 or 1.0.0" -ForegroundColor Red
    exit 1
}

# Normalize version (ensure 'v' prefix)
if ($Version -notmatch '^v') {
    $Version = "v$Version"
}

Write-Host "Packaging Win11 Optimizer $Version" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Check binary exists
if (-not (Test-Path $binaryPath)) {
    # Try alternative paths
    $altPaths = @(
        "tui\target\release\$binaryName",
        "tui\target\x86_64-pc-windows-msvc\release\$binaryName"
    )
    
    $found = $false
    foreach ($alt in $altPaths) {
        $altPath = Join-Path $projectRoot $alt
        if (Test-Path $altPath) {
            $binaryPath = $altPath
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Write-Host "ERROR: Binary not found at expected path: $binaryPath" -ForegroundColor Red
        Write-Host "Run '.\scripts\build-tui.ps1' first" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "Binary: $binaryPath" -ForegroundColor Gray

# Create dist directory
if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir -Force | Out-Null

Write-Host "Created dist directory: $distDir" -ForegroundColor Gray

# Copy binary
$destBinary = Join-Path $distDir $binaryName
Copy-Item $binaryPath $destBinary
Write-Host "  Copied binary" -ForegroundColor Green

# Copy IPC dispatcher
$dispatcherPath = Join-Path $projectRoot "WinOptimizer.ps1"
if (Test-Path $dispatcherPath) {
    Copy-Item $dispatcherPath $distDir
    Write-Host "  Copied IPC dispatcher" -ForegroundColor Green
}

# Copy modules
$modulesPath = Join-Path $projectRoot "modules"
if (Test-Path $modulesPath) {
    Copy-Item $modulesPath (Join-Path $distDir "modules") -Recurse
    Write-Host "  Copied modules" -ForegroundColor Green
}

# Copy runtime
$runtimePath = Join-Path $projectRoot "runtime"
if (Test-Path $runtimePath) {
    Copy-Item $runtimePath (Join-Path $distDir "runtime") -Recurse
    Write-Host "  Copied runtime" -ForegroundColor Green
}

# Copy documentation
$docFiles = @("README.md", "LICENSE", "SECURITY.md")
foreach ($doc in $docFiles) {
    $docPath = Join-Path $projectRoot $doc
    if (Test-Path $docPath) {
        Copy-Item $docPath $distDir
    }
}
Write-Host "  Copied documentation" -ForegroundColor Green

# Create zip archive
$zipName = "win11-optimizer-tui-$Version-windows-x64.zip"
$zipPath = Join-Path $projectRoot $zipName

# Remove existing zip if present
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

Write-Host "Creating archive: $zipName" -ForegroundColor Gray

# Create archive
Compress-Archive -Path "$distDir\*" -DestinationPath $zipPath -Force

if (-not (Test-Path $zipPath)) {
    Write-Host "ERROR: Failed to create archive" -ForegroundColor Red
    exit 1
}

Write-Host "  Created archive" -ForegroundColor Green

# Compute SHA-256 checksum
$checksumFile = "$zipPath.sha256"
$hash = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
"$hash  $zipName" | Out-File -FilePath $checksumFile -Encoding utf8 -NoNewline

Write-Host "  Computed checksum: $hash" -ForegroundColor Green

# Also compute checksum for the raw binary
$binaryHash = (Get-FileHash -Path $destBinary -Algorithm SHA256).Hash.ToLower()
$binaryChecksumFile = Join-Path $projectRoot "$binaryName.sha256"
"$binaryHash  $binaryName" | Out-File -FilePath $binaryChecksumFile -Encoding utf8 -NoNewline

Write-Host "  Binary checksum: $binaryHash" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "Package complete!" -ForegroundColor Green
Write-Host "  Archive: $zipPath" -ForegroundColor Cyan
Write-Host "  Checksum: $checksumFile" -ForegroundColor Cyan
Write-Host ""

exit 0
