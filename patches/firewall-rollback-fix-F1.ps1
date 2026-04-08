# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F1: Rollback for IP-based firewall rules
# APPLY: Copy to modules/ultimate/firewall-telemetry-blocking/rollback.ps1

$ErrorActionPreference = "Stop"

$moduleId  = "firewall-telemetry-blocking"
$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

# --- State file validation ---
if (-not (Test-Path $stateFile)) {
    Write-Host "    [ERROR] No state file found. Module was never applied or already rolled back." -ForegroundColor Red
    exit 1
}

$state = Get-Content $stateFile -Raw | ConvertFrom-Json
$backupDir = $state.BackupPath

if (-not (Test-Path $backupDir)) {
    Write-Host "    [WARN] Backup directory not found: $backupDir" -ForegroundColor Yellow
    Write-Host "    [INFO] Attempting to remove rules by name pattern..." -ForegroundColor Cyan
}

# --- Remove created rules ---
$ruleNames = @()
$ruleListFile = Join-Path $backupDir "rule-names.txt"

if (Test-Path $ruleListFile) {
    $ruleNames = @(Get-Content $ruleListFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
} elseif ($state.RuleNames) {
    $ruleNames = @($state.RuleNames)
}

if ($ruleNames.Count -eq 0) {
    # Fallback: remove by naming convention
    $ruleNames = @(Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'WinOptimizer-Telemetry-*' } |
        Select-Object -ExpandProperty Name)
}

$removed = 0
foreach ($ruleName in $ruleNames) {
    try {
        Remove-NetFirewallRule -Name $ruleName -ErrorAction Stop
        $removed++
        Write-Host "    [OK] Removed rule: $ruleName" -ForegroundColor Green
    } catch {
        Write-Host "    [WARN] Could not remove $ruleName — $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# --- Clean up state file ---
Remove-Item $stateFile -Force -ErrorAction SilentlyContinue

Write-Host "    [OK] Rollback complete: $removed rules removed" -ForegroundColor Green
exit 0
