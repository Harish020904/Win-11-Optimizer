# Rollback: Disable Xbox Services

$ErrorActionPreference = "Stop"

# Find most recent backup
$backupRoot = "C:\ProgramData\WinOptimizer\backup"
if (Test-Path $backupRoot) {
    $latestBackup = Get-ChildItem -Path $backupRoot -Directory |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
    $backupDir = Join-Path $latestBackup.FullName "disable-xbox-services"

    if (Test-Path $backupDir -and (Test-Path "$backupDir\services.json")) {
        $serviceStates = Get-Content "$backupDir\services.json" | ConvertFrom-Json

        foreach ($state in $serviceStates) {
            try {
                $service = Get-Service $state.Name -ErrorAction SilentlyContinue
                if ($service) {
                    # Restore start type
                    $startType = switch ($state.StartType) {
                        'Automatic' { 'Automatic' }
                        'AutomaticDelayedStart' { 'Automatic' }
                        'Manual' { 'Manual' }
                        'Disabled' { 'Disabled' }
                        default { 'Automatic' }
                    }
                    Set-Service -Name $state.Name -StartupType $startType

                    # Start if it was running
                    if ($state.Status -eq 'Running') {
                        Start-Service -Name $state.Name -ErrorAction SilentlyContinue
                    }

                    Write-Host "    Restored $($state.Name)" -ForegroundColor Green
                }
            } catch {
                Write-Host "    Warning: Could not restore $($state.Name) - $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }
}

exit 0