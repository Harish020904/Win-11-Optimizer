# Rollback: Disable Diagnostic Telemetry

$ErrorActionPreference = "Stop"

$moduleId = "disable-telemetry"

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

# Restore service states
if (Test-Path "$backupDir\services.json") {
    $serviceStates = Get-Content "$backupDir\services.json" | ConvertFrom-Json
    foreach ($svcState in $serviceStates) {
        try {
            $service = Get-Service $svcState.Name -ErrorAction SilentlyContinue
            if ($service) {
                # Restore start type
                $startType = switch ($svcState.StartType) {
                    'Automatic' { 'Automatic' }
                    'Manual' { 'Manual' }
                    'Disabled' { 'Disabled' }
                    default { 'Automatic' }
                }
                Set-Service -Name $svcState.Name -StartupType $startType

                # Start if it was running
                if ($svcState.Status -eq 'Running') {
                    Start-Service -Name $svcState.Name -ErrorAction SilentlyContinue
                }

                Write-Host "    Restored $($svcState.Name)" -ForegroundColor Green
            }
        } catch {
            Write-Host "    Warning: Could not restore $($svcState.Name) - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Remove telemetry policy
try {
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    Remove-ItemProperty -Path $policyPath -Name "AllowTelemetry" -ErrorAction SilentlyContinue
    Write-Host "    Removed telemetry policy" -ForegroundColor Green
} catch {
    Write-Verbose "Could not remove telemetry policy: $_"
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