# Rollback: Disable Windows Error Reporting

$ErrorActionPreference = "Stop"
$moduleId = "disable-wer"

# ROLLBACK-001: Read backup path from state.json instead of timestamp-based selection
$stateFile = "C:\ProgramData\WinOptimizer\state\state.json"
$backupDir = $null

if (Test-Path $stateFile) {
    $state = Get-Content $stateFile | ConvertFrom-Json
    if ($state.backups -and $state.backups.$moduleId) {
        $backupDir = $state.backups.$moduleId
    }
}

if (-not $backupDir -or -not (Test-Path $backupDir)) {
    Write-Host "ERROR: No backup record found for module $moduleId. Cannot rollback safely." -ForegroundColor Red
    exit 1
}

# Restore service
if (Test-Path "$backupDir\service.json") {
    $serviceBackup = Get-Content "$backupDir\service.json" | ConvertFrom-Json
    $service = Get-Service $serviceBackup.Name -ErrorAction SilentlyContinue

    if ($service) {
        # Restore start type
        $startType = switch ($serviceBackup.StartType) {
            'Automatic' { 'Automatic' }
            'Manual' { 'Manual' }
            'Disabled' { 'Disabled' }
            default { 'Automatic' }
        }
        Set-Service -Name $serviceBackup.Name -StartupType $startType

        # Start if it was running
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

    if ($null -ne $registryBackup.Disabled) {
        Set-ItemProperty -Path $werPath -Name "Disabled" -Value $registryBackup.Disabled -Type DWord -Force
        Write-Host "    Restored WER registry setting" -ForegroundColor Green
    }
    
    # Restore consent settings if backed up
    if ($null -ne $registryBackup.DefaultConsent) {
        $consentPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
        if (Test-Path $consentPath) {
            Set-ItemProperty -Path $consentPath -Name "DefaultConsent" -Value $registryBackup.DefaultConsent -Type DWord -Force
            Write-Host "    Restored WER consent setting" -ForegroundColor Green
        }
    }
}

# ROLLBACK-001: Remove backup entry from state.json after successful rollback
if (Test-Path $stateFile) {
    $state = Get-Content $stateFile | ConvertFrom-Json
    if ($state.backups -and $state.backups.$moduleId) {
        $state.backups.PSObject.Properties.Remove($moduleId)
        $state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8
    }
}

exit 0