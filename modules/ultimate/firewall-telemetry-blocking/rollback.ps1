# Rollback: Firewall Telemetry Endpoint Blocking

$ErrorActionPreference = "Stop"

# Find most recent backup
$backupRoot = "C:\ProgramData\WinOptimizer\backup"
if (Test-Path $backupRoot) {
    $latestBackup = Get-ChildItem -Path $backupRoot -Directory |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
    $backupDir = Join-Path $latestBackup.FullName "firewall-telemetry-blocking"

    if (Test-Path $backupDir -and (Test-Path "$backupDir\rule-list.txt")) {
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
}

exit 0