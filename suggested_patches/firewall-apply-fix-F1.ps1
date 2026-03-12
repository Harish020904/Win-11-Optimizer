# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F1: Replace hostname-based firewall rules with resolved IP approach
# WHY: New-NetFirewallRule -RemoteAddress does NOT resolve DNS. Hostname rules silently match nothing.
# HOW TO TEST: Invoke-Pester -Path ./tests/unit/modules/firewall-telemetry-blocking.tests.ps1
# APPLY: Copy this file to modules/ultimate/firewall-telemetry-blocking/apply.ps1
#
# RUN INSIDE WINDOWS VM OR CI ONLY
# To apply: copy suggested_patches/firewall-apply-fix-F1.ps1 → modules/ultimate/firewall-telemetry-blocking/apply.ps1

$ErrorActionPreference = "Stop"

# --- Module identity ---
$moduleId = "firewall-telemetry-blocking"
$layer = "ultimate"

# --- Directories ---
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = "C:\ProgramData\WinOptimizer\backup\$layer\$moduleId\$timestamp"
$stateDir  = "C:\ProgramData\WinOptimizer\state"
$stateFile = Join-Path $stateDir "$moduleId.json"

New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
if (-not (Test-Path $stateDir)) { New-Item -Path $stateDir -ItemType Directory -Force | Out-Null }

# --- Idempotency check ---
if (Test-Path $stateFile) {
    $existingState = Get-Content $stateFile -Raw | ConvertFrom-Json
    Write-Host "    [WARN] Module already applied at $($existingState.AppliedAt)" -ForegroundColor Yellow
    Write-Host "    [INFO] Run rollback first, or delete state file to force reapply." -ForegroundColor Cyan
    exit 0
}

# --- Telemetry endpoints ---
$telemetryHosts = @(
    'vortex-win.data.microsoft.com',
    'vortex.data.microsoft.com',
    'telecommand.telemetry.microsoft.com',
    'telecommand.traffic.data.microsoft.com',
    'settings-win.data.microsoft.com'
)

# --- Backup existing WinOptimizer firewall rules ---
$existingRules = Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object {
    $_.DisplayName -like 'WinOptimizer-Telemetry-*'
}
if ($existingRules) {
    $existingRules | Select-Object Name, DisplayName, Enabled, Direction, Action |
        Export-Csv "$backupDir\existing-rules.csv" -NoTypeInformation
}

# --- Resolve hostnames to IPs ---
$resolvedMap = @{}
$allIPs = @()

foreach ($hostname in $telemetryHosts) {
    try {
        $dnsResults = Resolve-DnsName -Name $hostname -Type A -ErrorAction Stop
        $ips = @($dnsResults | Where-Object { $_.QueryType -eq 'A' } | Select-Object -ExpandProperty IPAddress)
        if ($ips.Count -gt 0) {
            $resolvedMap[$hostname] = $ips
            $allIPs += $ips
            Write-Host "    [OK] Resolved $hostname → $($ips -join ', ')" -ForegroundColor Green
        } else {
            Write-Host "    [WARN] No A records for $hostname" -ForegroundColor Yellow
            $resolvedMap[$hostname] = @()
        }
    } catch {
        Write-Host "    [WARN] DNS resolution failed for $hostname — $($_.Exception.Message)" -ForegroundColor Yellow
        $resolvedMap[$hostname] = @()
    }
}

# Deduplicate IPs
$uniqueIPs = @($allIPs | Sort-Object -Unique)

if ($uniqueIPs.Count -eq 0) {
    Write-Host "    [ERROR] No IPs resolved. Cannot create firewall rules. Check DNS connectivity." -ForegroundColor Red
    exit 1
}

# --- Save resolution snapshot for rollback ---
$snapshot = @{
    Hostnames   = $telemetryHosts
    ResolvedMap = $resolvedMap
    UniqueIPs   = $uniqueIPs
    Timestamp   = $timestamp
}
$snapshot | ConvertTo-Json -Depth 5 | Out-File "$backupDir\dns-snapshot.json" -Encoding UTF8

# --- Create firewall rules (one per hostname for traceability) ---
$createdRules = @()

foreach ($hostname in $telemetryHosts) {
    $ips = $resolvedMap[$hostname]
    if ($ips.Count -eq 0) { continue }

    $ruleName = "WinOptimizer-Telemetry-$($hostname -replace '[.\-]', '_')"
    $displayName = "WinOptimizer: Block $hostname"

    # Remove existing rule with same name (idempotent)
    Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

    try {
        New-NetFirewallRule `
            -Name $ruleName `
            -DisplayName $displayName `
            -Description "Blocks telemetry endpoint $hostname (resolved IPs: $($ips -join ', '))" `
            -Direction Outbound `
            -Action Block `
            -RemoteAddress $ips `
            -Enabled True `
            -Profile Any `
            -ErrorAction Stop | Out-Null

        $createdRules += $ruleName
        Write-Host "    [OK] Created rule: $displayName → $($ips -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "    [ERROR] Failed to create rule for $hostname — $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Save rule list for rollback ---
$createdRules | Out-File "$backupDir\rule-names.txt" -Encoding UTF8

# --- Write state file ---
$state = @{
    ModuleId   = $moduleId
    Layer      = $layer
    AppliedAt  = Get-Date -Format "o"
    BackupPath = $backupDir
    RuleNames  = $createdRules
    ResolvedIPs = $uniqueIPs
}
$state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8

Write-Host "    [OK] $($createdRules.Count) firewall rules created blocking $($uniqueIPs.Count) unique IPs" -ForegroundColor Green
exit 0
