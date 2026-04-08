# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F11: Fix disable-wer apply.ps1 (remove duplicate) and rollback.ps1 (restore DefaultConsent)
# WHY: apply.ps1 line 48 duplicates line 47. rollback.ps1 never restores DefaultConsent.
#
# === PART 1: apply.ps1 fix ===
# Remove duplicate line 48. Also backup DefaultConsent for rollback.
# APPLY: Copy PART 1 to modules/godmode/disable-wer/apply.ps1

# --- apply.ps1 (full replacement) ---

$ErrorActionPreference = "Stop"

$moduleId = "disable-wer"
$layer = "godmode"

# Create backup directory
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = "C:\ProgramData\WinOptimizer\backup\$layer\$moduleId\$timestamp"
$stateDir  = "C:\ProgramData\WinOptimizer\state"
$stateFile = Join-Path $stateDir "$moduleId.json"

New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }

# Idempotency check
if (Test-Path $stateFile) {
    $existingState = Get-Content $stateFile -Raw | ConvertFrom-Json
    Write-Host "    [WARN] Module already applied at $($existingState.AppliedAt)" -ForegroundColor Yellow
    exit 0
}

# Backup and modify service
$service = Get-Service WerSvc -ErrorAction SilentlyContinue
if ($service) {
    @{
        Name      = $service.Name
        Status    = $service.Status.ToString()
        StartType = $service.StartType.ToString()
    } | ConvertTo-Json | Out-File "$backupDir\service.json"

    if ($service.Status -eq 'Running') {
        Stop-Service -Name WerSvc -Force
        Write-Host "    Stopped WerSvc" -ForegroundColor Green
    }

    Set-Service -Name WerSvc -StartupType Disabled
    Write-Host "    Disabled WerSvc" -ForegroundColor Green
}

# Backup and modify registry — WER Disabled key
$werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
$registryBackup = @{}

if (Test-Path $werPath) {
    $currentDisabled = (Get-ItemProperty -Path $werPath -ErrorAction SilentlyContinue).Disabled
    $registryBackup['Disabled'] = $currentDisabled

    Set-ItemProperty -Path $werPath -Name "Disabled" -Value 1 -Type DWord -Force
    Write-Host "    Disabled WER via registry" -ForegroundColor Green
}

# Backup and modify DefaultConsent
$consentPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
if (-not (Test-Path $consentPath)) {
    New-Item -Path $consentPath -Force | Out-Null
    $registryBackup['DefaultConsent'] = $null
    $registryBackup['ConsentKeyCreated'] = $true
} else {
    $currentConsent = (Get-ItemProperty -Path $consentPath -ErrorAction SilentlyContinue).DefaultConsent
    $registryBackup['DefaultConsent'] = $currentConsent
    $registryBackup['ConsentKeyCreated'] = $false
}

# Set DefaultConsent — ONLY ONCE (removed duplicate from original)
Set-ItemProperty -Path $consentPath -Name "DefaultConsent" -Value 0 -Type DWord -Force
Write-Host "    Disabled WER consent prompts" -ForegroundColor Green

# Save registry backup
$registryBackup | ConvertTo-Json | Out-File "$backupDir\registry.json"

# Write state file
@{
    ModuleId   = $moduleId
    Layer      = $layer
    AppliedAt  = Get-Date -Format "o"
    BackupPath = $backupDir
} | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

exit 0


# === PART 2: rollback.ps1 fix ===
# APPLY: Copy everything below this marker to modules/godmode/disable-wer/rollback.ps1
# The key fix: restore DefaultConsent from backup and use state file for backup path.
<#
--- BEGIN rollback.ps1 ---

# AUTHOR: claude-code
# SAFE: snapshot -> apply -> verify -> rollback
# RUN INSIDE WINDOWS VM OR CI ONLY

$ErrorActionPreference = "Stop"

$moduleId  = "disable-wer"
$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

# Use state file for exact backup path (fixes F2 race condition)
if (-not (Test-Path $stateFile)) {
    Write-Host "    [ERROR] No state file found. Module was never applied or already rolled back." -ForegroundColor Red
    exit 1
}

$state = Get-Content $stateFile -Raw | ConvertFrom-Json
$backupDir = $state.BackupPath

if (-not (Test-Path $backupDir)) {
    Write-Host "    [ERROR] Backup directory not found: $backupDir" -ForegroundColor Red
    exit 1
}

# Restore service
if (Test-Path "$backupDir\service.json") {
    $serviceBackup = Get-Content "$backupDir\service.json" | ConvertFrom-Json
    $service = Get-Service $serviceBackup.Name -ErrorAction SilentlyContinue

    if ($service) {
        $startType = switch ($serviceBackup.StartType) {
            'Automatic' { 'Automatic' }
            'Manual'    { 'Manual' }
            'Disabled'  { 'Disabled' }
            default     { 'Automatic' }
        }
        Set-Service -Name $serviceBackup.Name -StartupType $startType

        if ($serviceBackup.Status -eq 'Running') {
            Start-Service -Name $serviceBackup.Name -ErrorAction SilentlyContinue
        }

        Write-Host "    Restored WerSvc service" -ForegroundColor Green
    }
}

# Restore registry
if (Test-Path "$backupDir\registry.json") {
    $registryBackup = Get-Content "$backupDir\registry.json" | ConvertFrom-Json
    $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"

    # Restore Disabled value
    if ($null -ne $registryBackup.Disabled) {
        Set-ItemProperty -Path $werPath -Name "Disabled" -Value $registryBackup.Disabled -Type DWord -Force
        Write-Host "    Restored WER Disabled = $($registryBackup.Disabled)" -ForegroundColor Green
    }

    # Restore DefaultConsent value (THIS WAS MISSING — F11 fix)
    $consentPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
    if ($null -ne $registryBackup.DefaultConsent) {
        Set-ItemProperty -Path $consentPath -Name "DefaultConsent" -Value $registryBackup.DefaultConsent -Type DWord -Force
        Write-Host "    Restored DefaultConsent = $($registryBackup.DefaultConsent)" -ForegroundColor Green
    } elseif ($registryBackup.ConsentKeyCreated -eq $true) {
        # Key was created by apply — remove it
        Remove-ItemProperty -Path $consentPath -Name "DefaultConsent" -ErrorAction SilentlyContinue
        Write-Host "    Removed DefaultConsent (was not present before apply)" -ForegroundColor Green
    }
}

# Remove state file
Remove-Item $stateFile -Force -ErrorAction SilentlyContinue
Write-Host "    [OK] Rollback complete" -ForegroundColor Green

exit 0

--- END rollback.ps1 ---
#>
