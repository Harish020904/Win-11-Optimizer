# Apply: Firewall Telemetry Endpoint Blocking

$ErrorActionPreference = "Stop"

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\firewall-telemetry-blocking"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

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
        New-NetFirewallRule `
            -DisplayName "Win11Opt: Block $endpoint" `
            -Name $ruleName `
            -Direction Outbound `
            -Action Block `
            -RemoteAddress $endpoint `
            -Enabled True `
            -Profile Any `
            -ErrorAction Stop | Out-Null

        $ruleNames += $ruleName
        Write-Host "    Added rule for $endpoint" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -notlike '*already exists*') {
            Write-Host "    Warning: Could not add rule for $endpoint - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Save list of created rules
$ruleNames | Out-File "$backupDir\rule-list.txt"

exit 0