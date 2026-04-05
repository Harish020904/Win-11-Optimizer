# Apply: Disable Xbox Services

$ErrorActionPreference = "Stop"
$moduleId = "disable-xbox-services"

$services = @('XboxNetApiSvc', 'XboxGipSvc', 'XblAuthManager', 'XblGameSave')

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

# Backup and modify services
$serviceStates = @()
foreach ($svc in $services) {
    try {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service) {
            # Backup state
            $serviceStates += @{
                Name = $service.Name
                Status = $service.Status.ToString()
                StartType = $service.StartType.ToString()
            }

            # Stop if running
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Write-Host "    Stopped $svc" -ForegroundColor Green
            }

            # Set to Manual
            Set-Service -Name $svc -StartupType Manual
            Write-Host "    Set $svc to Manual startup" -ForegroundColor Green
        }
    } catch {
        Write-Host "    Warning: Could not modify $svc - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Save backup
$serviceStates | ConvertTo-Json | Out-File "$backupDir\services.json"

exit 0