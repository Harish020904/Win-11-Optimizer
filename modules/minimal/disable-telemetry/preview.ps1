# Preview: Disable Diagnostic Telemetry

$services = @('DiagTrack', 'dmwappushservice')

Write-Host ""
Write-Host "  Current state of diagnostic services:" -ForegroundColor Cyan
Write-Host ""

foreach ($svc in $services) {
    try {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service) {
            $statusColor = if ($service.Status -eq 'Running') { 'Green' } else { 'Yellow' }
            Write-Host "    $($service.Name.PadRight(20)) - $($service.Status) (Start: $($service.StartType))" -ForegroundColor $statusColor
        } else {
            Write-Host "    $($svc.PadRight(20)) - Not found" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "    $($svc.PadRight(20)) - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check current telemetry setting
try {
    $telemetryKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (Test-Path $telemetryKey) {
        $telemetry = (Get-ItemProperty -Path $telemetryKey -ErrorAction SilentlyContinue).AllowTelemetry
        Write-Host ""
        Write-Host "  Current telemetry policy: $telemetry" -ForegroundColor Cyan
    }
} catch {
    Write-Host ""
    Write-Host "  Could not read telemetry policy" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  After applying:" -ForegroundColor Green
Write-Host "    - DiagTrack service will be stopped and disabled" -ForegroundColor White
Write-Host "    - dmwappushservice will be stopped and disabled" -ForegroundColor White
Write-Host "    - Telemetry policy set to 0 (minimal)" -ForegroundColor White
Write-Host ""