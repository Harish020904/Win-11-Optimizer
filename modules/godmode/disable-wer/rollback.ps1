# Rollback: Disable Windows Error Reporting

$ErrorActionPreference = "Stop"

# Find most recent backup
$backupRoot = "C:\ProgramData\WinOptimizer\backup"
if (Test-Path $backupRoot) {
    $latestBackup = Get-ChildItem -Path $backupRoot -Directory |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
    $backupDir = Join-Path $latestBackup.FullName "disable-wer"

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
    }
}

exit 0