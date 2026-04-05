# Apply: Firewall Telemetry Endpoint Blocking

$ErrorActionPreference = "Stop"
$moduleId = "firewall-telemetry-blocking"

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

$endpoints = @(
    'vortex-win.data.microsoft.com',
    'vortex.data.microsoft.com',
    'telecommand.telemetry.microsoft.com',
    'telecommand.traffic.data.microsoft.com',
    'settings-win.data.microsoft.com'
)

$ruleNames = @()

# Backup existing rules
$existingRules = Get-NetFirewallRule | Where-Object {
    $_.DisplayName -like '*Win11Opt*'
}
$existingRules | Select-Object DisplayName, Enabled, Direction, Action |
    Export-Csv "$backupDir\rules.csv" -NoTypeInformation

# Create blocking rules
foreach ($endpoint in $endpoints) {
    $ruleName = "Win11Opt-Block-$($endpoint -replace '[.-]', '')"

    try {
        # SEC-002: Resolve DNS hostname to IP addresses before creating firewall rule
        $resolvedIps = @()
        try {
            $addresses = [System.Net.Dns]::GetHostAddresses($endpoint)
            $resolvedIps = $addresses | ForEach-Object { $_.IPAddressToString }
            Write-Host "    Resolved $endpoint to: $($resolvedIps -join ', ')" -ForegroundColor Gray
        } catch {
            Write-Host "    Warning: Could not resolve $endpoint - skipping" -ForegroundColor Yellow
            continue
        }

        if ($resolvedIps.Count -eq 0) {
            Write-Host "    Warning: No IP addresses found for $endpoint - skipping" -ForegroundColor Yellow
            continue
        }

        New-NetFirewallRule `
            -DisplayName "Win11Opt: Block $endpoint" `
            -Name $ruleName `
            -Direction Outbound `
            -Action Block `
            -RemoteAddress $resolvedIps `
            -Enabled True `
            -Profile Any `
            -ErrorAction Stop | Out-Null

        $ruleNames += $ruleName
        Write-Host "    Added rule for $endpoint (IPs: $($resolvedIps -join ', '))" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -notlike '*already exists*') {
            Write-Host "    Warning: Could not add rule for $endpoint - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Save list of created rules
$ruleNames | Out-File "$backupDir\rule-list.txt"

exit 0