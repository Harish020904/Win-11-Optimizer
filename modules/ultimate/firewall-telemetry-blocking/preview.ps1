# Preview: Firewall Telemetry Endpoint Blocking

Write-Host ""
Write-Host "  Current firewall telemetry rules:" -ForegroundColor Cyan
Write-Host ""

$existingRules = Get-NetFirewallRule | Where-Object {
    $_.DisplayName -like '*telemetry*' -or
    $_.DisplayName -like '*Win11Opt*'
} | Select-Object DisplayName, Enabled, Direction, Action

if ($existingRules) {
    foreach ($rule in $existingRules) {
        $enabledColor = if ($rule.Enabled -eq 'True') { 'Green' } else { 'Yellow' }
        $actionColor = if ($rule.Action -eq 'Block') { 'Red' } else { 'Green' }
        Write-Host "    $($rule.DisplayName.PadRight(40)) [$($rule.Enabled)]" -ForegroundColor $enabledColor
    }
} else {
    Write-Host "    No telemetry blocking rules found" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  Will add firewall rules to block these endpoints:" -ForegroundColor Green
$endpoints = @(
    'vortex-win.data.microsoft.com',
    'vortex.data.microsoft.com',
    'telecommand.telemetry.microsoft.com',
    'telecommand.traffic.data.microsoft.com',
    'settings-win.data.microsoft.com'
)
foreach ($endpoint in $endpoints) {
    Write-Host "    - $endpoint" -ForegroundColor White
}

Write-Host ""
Write-Host "  Note: This may affect some Microsoft services temporarily." -ForegroundColor Yellow
Write-Host ""