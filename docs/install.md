# Installation Guide

This guide covers installation of Win11 Optimizer on Windows 11.

## Prerequisites

- Windows 11 (21H2 or later)
- Administrator privileges
- PowerShell 5.1+ (built into Windows 11)
- At least 1 GB free disk space for backups

## Quick Install

### Method 1: One-liner (Recommended)

```powershell
# Download and run installer (verify signature first)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-WebRequest -Uri "https://github.com/yourorg/win11-optimizer/releases/latest/download/install.ps1" -OutFile "$env:TEMP\install.ps1"

# Verify SHA256
$expectedHash = "PUBLISHED_SHA256_HERE"
$actualHash = (Get-FileHash -Algorithm SHA256 "$env:TEMP\install.ps1").Hash
if ($actualHash -ne $expectedHash) {
    Write-Host "SHA256 mismatch! Do not continue." -ForegroundColor Red
    exit 1
}

# Verify Authenticode signature
$signature = Get-AuthenticodeSignature "$env:TEMP\install.ps1"
if ($signature.Status -ne 'Valid') {
    Write-Host "Signature verification failed! Do not continue." -ForegroundColor Red
    exit 1
}

# Run installer
powershell -ExecutionPolicy Bypass -File "$env:TEMP\install.ps1"
```

### Method 2: Manual Install

1. Download the latest release from [GitHub Releases](https://github.com/Harish020904/Win-11-Optimizer/releases/latest)
2. Extract the ZIP file to `C:\Win11Optimizer\`
3. Right-click PowerShell → "Run as Administrator"
4. Launch `C:\Win11Optimizer\win11-optimizer-tui.exe`

## Installation Locations

### Default Paths

```
C:\Win11Optimizer\          # Main installation directory
  ├── win11-optimizer-tui.exe # Ratatui frontend
  ├── WinOptimizer.ps1      # Headless IPC backend and plaintext fallback
  ├── runtime\              # Manifests and legacy runtime support
  ├── modules\              # Optimization modules
  ├── manifests\            # Layer manifests
  └── logs\                 # Execution logs

C:\ProgramData\WinOptimizer\ # Runtime data
  ├── backup\               # Snapshots and backups
  └── state\                # Applied layers state
```

### Portable Installation

For portable installation (no system changes):

```powershell
# Extract to any directory
Expand-Archive -Path win11-optimizer.zip -DestinationPath D:\Tools\win11-optimizer

# Run from extracted directory
cd D:\Tools\win11-optimizer
.\win11-optimizer-tui.exe
```

## Post-Installation Verification

After installation, verify the system:

```powershell
# Check that the optimizer script exists
Test-Path C:\Win11Optimizer\win11-optimizer-tui.exe
Test-Path C:\Win11Optimizer\WinOptimizer.ps1

# Check backup directory
Test-Path C:\ProgramData\WinOptimizer\backup

# Verify modules are present
Test-Path C:\Win11Optimizer\modules\minimal
Test-Path C:\Win11Optimizer\modules\moderate
Test-Path C:\Win11Optimizer\modules\ultimate
Test-Path C:\Win11Optimizer\modules\godmode
```

## Uninstallation

To completely remove Win11 Optimizer:

```powershell
# 1. Rollback any applied layers first
.\win11-optimizer-tui.exe

# 2. Remove installation directory
Remove-Item -Path C:\Win11Optimizer -Recurse -Force

# 3. Remove runtime data
Remove-Item -Path C:\ProgramData\WinOptimizer -Recurse -Force

# 4. Remove Start Menu shortcut (if created)
Remove-Item -Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Win11 Optimizer.lnk" -Force
```

## Troubleshooting

### Execution Policy Error

```
"cannot be loaded because running scripts is disabled on this system"
```

**Solution:**

```powershell
# Set execution policy for current user (elevated PowerShell)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or bypass for single run
powershell -ExecutionPolicy Bypass -File .\WinOptimizer.ps1
```

### Administrator Privileges Required

```
"This application requires Administrator privileges"
```

**Solution:**

Right-click PowerShell and select "Run as Administrator"

### Module Loading Failed

```
"[FATAL] Failed to load module: ..."
```

**Solution:**

```powershell
# Check module file exists
Test-Path C:\Win11Optimizer\modules\minimal\disable-telemetry\metadata.yaml

# Check for file corruption (re-download if needed)
Get-FileHash -Algorithm SHA256 C:\Win11Optimizer\win11-optimizer-tui.exe
```

### Windows Defender Blocking

If Windows Defender blocks execution:

1. Open Windows Security → Virus & threat protection
2. Click "Manage settings"
3. Add `C:\Win11Optimizer` to exclusions under "Exclusions"

**Note:** This is safe since the optimizer scripts are open source and verified via signatures.

## System Requirements Verification

Verify your system meets requirements:

```powershell
# Check Windows version
$winVer = [System.Environment]::OSVersion.Version
Write-Host "Windows Version: $($winVer.Major).$($winVer.Minor).$($winVer.Build)"

# Check PowerShell version
$psVer = $PSVersionTable.PSVersion
Write-Host "PowerShell Version: $psVer"

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Administrator: $isAdmin"

# Check disk space
$disk = Get-PSDrive C
Write-Host "Free Space: $([math]::Round($disk.Free / 1GB, 2)) GB"
```

## Next Steps

After installation:

1. [Read the runbook](runbook.md) for usage instructions
2. Start with the **Minimal** layer
3. Preview changes before applying
4. Verify system after each layer
5. Monitor for 24-48 hours before proceeding to next layer

## Security Notes

- Always verify SHA256 checksums before running
- Always verify Authenticode signatures
- Never run scripts from untrusted sources
- Review disclaimers before applying changes
- Create a system backup before using

For more information, see:
- [Runbook](runbook.md)
- [Testing Guide](testing.md)
- [Security Policy](../SECURITY.md)
