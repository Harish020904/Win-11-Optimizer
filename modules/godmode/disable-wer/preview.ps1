# Preview: Disable Windows Error Reporting

Write-Host ""
Write-Host "  Current Windows Error Reporting status:" -ForegroundColor Cyan
Write-Host ""

# Check service
$service = Get-Service WerSvc -ErrorAction SilentlyContinue
if ($service) {
    $statusColor = switch ($service.Status) {
        'Running' { 'Green' }
        'Stopped' { 'Yellow' }
        default { 'DarkGray' }
    }
    Write-Host "    Service: $($service.Name) - $($service.Status) (Start: $($service.StartType))" -ForegroundColor $statusColor
} else {
    Write-Host "    Service: Not found" -ForegroundColor DarkGray
}

# Check registry settings
Write-Host ""
Write-Host "  Registry settings:" -ForegroundColor Cyan
try {
    $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (Test-Path $werPath) {
        $disabled = (Get-ItemProperty -Path $werPath -ErrorAction SilentlyContinue).Disabled
        Write-Host "    WER Disabled: $disabled" -ForegroundColor Cyan
    }
} catch {
    Write-Host "    Could not read WER registry settings" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  After applying:" -ForegroundColor Green
Write-Host "    - WerSvc service will be stopped and disabled" -ForegroundColor White
Write-Host "    - Error reports will not be sent to Microsoft" -ForegroundColor White
Write-Host "    - Crash dumps will not be automatically collected" -ForegroundColor Yellow
Write-Host "    - System errors may not be logged for troubleshooting" -ForegroundColor Yellow
Write-Host ""