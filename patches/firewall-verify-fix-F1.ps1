# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F1: Verify for IP-based firewall rules
# APPLY: Copy to modules/ultimate/firewall-telemetry-blocking/verify.ps1

$ErrorActionPreference = "Stop"

$moduleId  = "firewall-telemetry-blocking"
$stateFile = "C:\ProgramData\WinOptimizer\state\$moduleId.json"

$allVerified = $true
$foundRules = 0

# --- Check state file exists ---
if (-not (Test-Path $stateFile)) {
    Write-Host "    [FAIL] No state file — module not applied" -ForegroundColor Red
    exit 1
}

$null = Get-Content $stateFile -Raw | ConvertFrom-Json

# --- Verify each rule exists, is enabled, blocks outbound, and has IP addresses ---
$telemetryHosts = @(
    'vortex-win.data.microsoft.com',
    'vortex.data.microsoft.com',
    'telecommand.telemetry.microsoft.com',
    'telecommand.traffic.data.microsoft.com',
    'settings-win.data.microsoft.com'
)

foreach ($hostname in $telemetryHosts) {
    $ruleName = "WinOptimizer-Telemetry-$($hostname -replace '[.\-]', '_')"
    $rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue

    if (-not $rule) {
        Write-Host "    [WARN] Rule for $hostname not found (may not have resolved)" -ForegroundColor Yellow
        continue
    }

    $foundRules++

    # Check rule properties
    if ($rule.Action -ne 'Block') {
        Write-Host "    [FAIL] Rule for $hostname action is $($rule.Action), expected Block" -ForegroundColor Red
        $allVerified = $false
    }
    if ($rule.Enabled.ToString() -ne 'True') {
        Write-Host "    [FAIL] Rule for $hostname is not enabled" -ForegroundColor Red
        $allVerified = $false
    }
    if ($rule.Direction -ne 'Outbound') {
        Write-Host "    [FAIL] Rule for $hostname direction is $($rule.Direction), expected Outbound" -ForegroundColor Red
        $allVerified = $false
    }

    # Verify RemoteAddress contains IPs not hostnames
    $addrFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $rule -ErrorAction SilentlyContinue
    if ($addrFilter) {
        $remoteAddresses = @($addrFilter.RemoteAddress)
        foreach ($addr in $remoteAddresses) {
            if ($addr -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}') {
                Write-Host "    [OK] $hostname → IP $addr" -ForegroundColor Green
            } elseif ($addr -eq 'Any' -or $addr -eq 'LocalSubnet') {
                # These are valid tokens but wrong for our use
                Write-Host "    [FAIL] $hostname has non-specific address: $addr" -ForegroundColor Red
                $allVerified = $false
            } else {
                Write-Host "    [FAIL] $hostname has non-IP address: $addr (hostname?)" -ForegroundColor Red
                $allVerified = $false
            }
        }
    }
}

if ($foundRules -eq 0) {
    Write-Host "    [FAIL] No blocking rules found at all" -ForegroundColor Red
    $allVerified = $false
} else {
    Write-Host "    [INFO] $foundRules rules verified" -ForegroundColor Cyan
}

if ($allVerified) {
    Write-Host "    [PASS] All firewall rules verified — using IP addresses, not hostnames" -ForegroundColor Green
    exit 0
} else {
    exit 1
}
