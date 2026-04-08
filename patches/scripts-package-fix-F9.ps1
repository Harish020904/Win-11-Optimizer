# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F9: Missing packaging script
# WHY: release.yml references scripts/package.ps1 which does not exist.
# APPLY: Save as scripts/package.ps1

param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$OutputPath = ".\dist"
)

$ErrorActionPreference = 'Stop'

Write-Host "Packaging Win11 Optimizer v$Version" -ForegroundColor Cyan

# Clean and create output directory
if (Test-Path $OutputPath) { Remove-Item $OutputPath -Recurse -Force }
New-Item -ItemType Directory -Path $OutputPath | Out-Null

# Copy release files
$releaseItems = @(
    'runtime',
    'modules',
    'README.md',
    'LICENSE',
    'SECURITY.md',
    'build-info.yaml'
)

foreach ($item in $releaseItems) {
    if (Test-Path $item) {
        Copy-Item -Path $item -Destination $OutputPath -Recurse -Force
        Write-Host "  Copied: $item" -ForegroundColor Green
    } else {
        Write-Host "  Skipped (not found): $item" -ForegroundColor Yellow
    }
}

# Create version.json
@{
    version   = $Version
    buildDate = Get-Date -Format "o"
    commit    = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { "local" }
    branch    = if ($env:GITHUB_REF_NAME) { $env:GITHUB_REF_NAME } else { "local" }
} | ConvertTo-Json | Set-Content (Join-Path $OutputPath "version.json") -Encoding UTF8

# Create archive
$archiveName = "win11-optimizer-$Version.zip"
$archivePath = Join-Path (Split-Path $OutputPath -Parent) $archiveName

Compress-Archive -Path "$OutputPath\*" -DestinationPath $archivePath -Force

# Compute SHA256
$hash = Get-FileHash -Algorithm SHA256 $archivePath
$hash.Hash | Out-File "$archivePath.sha256" -Encoding UTF8

Write-Host "`nPackage created: $archiveName" -ForegroundColor Green
Write-Host "SHA256: $($hash.Hash)" -ForegroundColor Cyan
