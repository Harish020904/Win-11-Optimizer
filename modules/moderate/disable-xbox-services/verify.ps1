# Verify: Disable Xbox Services

$services = @('XboxNetApiSvc', 'XboxGipSvc', 'XblAuthManager', 'XblGameSave')
$allVerified = $true
$foundServices = $false

foreach ($svc in $services) {
    $service = Get-Service $svc -ErrorAction SilentlyContinue
    if ($service) {
        $foundServices = $true
        if ($service.StartType -eq 'Disabled') {
            Write-Host "    $svc is disabled (should be Manual)" -ForegroundColor Yellow
            $allVerified = $false
        }
        if ($service.Status -eq 'Running') {
            Write-Host "    $svc is still running" -ForegroundColor Yellow
            $allVerified = $false
        }
    }
}

if (-not $foundServices) {
    Write-Host "    No Xbox services found (already disabled or not installed)" -ForegroundColor Green
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}