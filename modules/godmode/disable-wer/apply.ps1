# Apply: Disable Windows Error Reporting

$ErrorActionPreference = "Stop"

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\disable-wer"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

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
    @{ Disabled = $currentDisabled } | ConvertTo-Json | Out-File "$backupDir\registry.json"

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
Set-ItemProperty -Path $consentPath -Name "DefaultConsent" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
Write-Host "    Disabled WER consent prompts" -ForegroundColor Green

exit 0