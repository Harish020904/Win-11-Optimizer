# Verify: Firewall Telemetry Endpoint Blocking

$endpoints = @(
    'vortex-win.data.microsoft.com',
    'vortex.data.microsoft.com',
    'telecommand.telemetry.microsoft.com',
    'telecommand.traffic.data.microsoft.com',
    'settings-win.data.microsoft.com'
)

$allVerified = $true
$foundRules = 0

foreach ($endpoint in $endpoints) {
    $expectedRule = "Win11Opt-Block-$($endpoint -replace '[.-]', '')"
    $rule = Get-NetFirewallRule -Name $expectedRule -ErrorAction SilentlyContinue

    if ($rule) {
        $foundRules++
        if ($rule.Action -ne 'Block') {
            Write-Host "    Rule for $endpoint is not set to Block" -ForegroundColor Yellow
            $allVerified = $false
        }
        if ($rule.Enabled -ne 'True') {
            Write-Host "    Rule for $endpoint is not enabled" -ForegroundColor Yellow
            $allVerified = $false
        }
        if ($rule.Direction -ne 'Outbound') {
            Write-Host "    Rule for $endpoint is not Outbound" -ForegroundColor Yellow
            $allVerified = $false
        }
    } else {
        Write-Host "    Rule for $endpoint not found" -ForegroundColor Yellow
        $allVerified = $false
    }
}

if ($foundRules -eq 0) {
    Write-Host "    No blocking rules found" -ForegroundColor Yellow
    $allVerified = $false
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}