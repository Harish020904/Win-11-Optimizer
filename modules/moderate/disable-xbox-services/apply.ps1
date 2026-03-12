# Apply: Disable Xbox Services

$ErrorActionPreference = "Stop"

$services = @('XboxNetApiSvc', 'XboxGipSvc', 'XblAuthManager', 'XblGameSave')

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\disable-xbox-services"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

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