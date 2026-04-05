# Rollback: Firewall Telemetry Endpoint Blocking

$ErrorActionPreference = "Stop"
$moduleId = "firewall-telemetry-blocking"

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

if (Test-Path "$backupDir\rule-list.txt") {
    $ruleNames = Get-Content "$backupDir\rule-list.txt"

    foreach ($ruleName in $ruleNames) {
        try {
            Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
            Write-Host "    Removed rule $ruleName" -ForegroundColor Green
        } catch {
            Write-Host "    Warning: Could not remove $ruleName - $($_.Exception.Message)" -ForegroundColor Yellow
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