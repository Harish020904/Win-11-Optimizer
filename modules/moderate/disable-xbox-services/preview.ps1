# Preview: Disable Xbox Services

Write-Host ""
Write-Host "  Current Xbox service status:" -ForegroundColor Cyan
Write-Host ""

$services = @('XboxNetApiSvc', 'XboxGipSvc', 'XblAuthManager', 'XblGameSave')
$found = $false

foreach ($svc in $services) {
    try {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service) {
            $found = $true
            $statusColor = switch ($service.Status) {
                'Running' { 'Green' }
                'Stopped' { 'Yellow' }
                default { 'DarkGray' }
            }
            Write-Host "    $($service.Name.PadRight(25)) - $($service.Status) (Start: $($service.StartType))" -ForegroundColor $statusColor
        }
    } catch {
        Write-Verbose "Could not get service info: $_"
    }
}

if (-not $found) {
    Write-Host "    No Xbox services found (already disabled or not installed)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "  After applying:" -ForegroundColor Green
Write-Host "    - Xbox services set to Manual startup" -ForegroundColor White
Write-Host "    - Running Xbox services will be stopped" -ForegroundColor White
Write-Host "    - Xbox gaming features will not function" -ForegroundColor Yellow
Write-Host ""