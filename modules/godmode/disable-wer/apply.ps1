# Apply: Disable Windows Error Reporting

$ErrorActionPreference = "Stop"
$moduleId = "disable-wer"

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\$moduleId"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# ROLLBACK-001: Record backup path in state.json for explicit rollback tracking
$stateFile = "C:\ProgramData\WinOptimizer\state\state.json"
$stateDir = Split-Path $stateFile -Parent
if (-not (Test-Path $stateDir)) {
    New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
}
$state = if (Test-Path $stateFile) {
    Get-Content $stateFile | ConvertFrom-Json
} else {
    @{ backups = @{} }
}
if (-not $state.backups) { $state | Add-Member -NotePropertyName "backups" -NotePropertyValue @{} -Force }
$state.backups | Add-Member -NotePropertyName $moduleId -NotePropertyValue $backupDir -Force
$state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8

# Backup and modify service
$service = Get-Service WerSvc -ErrorAction SilentlyContinue
if ($service) {
    # Backup state
    @{
        Name = $service.Name
        Status = $service.Status.ToString()
        StartType = $service.StartType.ToString()
    } | ConvertTo-Json | Out-File "$backupDir\service.json"

    # Stop if running
    if ($service.Status -eq 'Running') {
        Stop-Service -Name WerSvc -Force
        Write-Host "    Stopped WerSvc" -ForegroundColor Green
    }

    # Disable service
    Set-Service -Name WerSvc -StartupType Disabled
    Write-Host "    Disabled WerSvc" -ForegroundColor Green
}

# Backup and modify registry
$werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
if (Test-Path $werPath) {
    # Backup current Disabled value
    $currentDisabled = (Get-ItemProperty -Path $werPath -ErrorAction SilentlyContinue).Disabled
    
    # Also backup consent settings
    $consentPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
    $currentConsent = $null
    if (Test-Path $consentPath) {
        $currentConsent = (Get-ItemProperty -Path $consentPath -ErrorAction SilentlyContinue).DefaultConsent
    }
    
    @{ 
        Disabled = $currentDisabled
        DefaultConsent = $currentConsent
    } | ConvertTo-Json | Out-File "$backupDir\registry.json"

    # Set to 1 (disabled)
    Set-ItemProperty -Path $werPath -Name "Disabled" -Value 1 -Type DWord -Force
    Write-Host "    Disabled WER via registry" -ForegroundColor Green
}

# Also disable consent settings
$consentPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Consent"
if (-not (Test-Path $consentPath)) {
    New-Item -Path $consentPath -Force | Out-Null
}
Set-ItemProperty -Path $consentPath -Name "DefaultConsent" -Value 0 -Type DWord -Force
Write-Host "    Disabled WER consent prompts" -ForegroundColor Green

exit 0