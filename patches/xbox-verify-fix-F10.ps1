# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F10: Fix inverted Xbox services verify logic
# WHY: verify.ps1 flags 'Disabled' as failure. apply.ps1 sets 'Manual'. Both Manual and
#      Disabled should be success states. 'Automatic' or 'Running' should be failures.
# APPLY: Copy to modules/moderate/disable-xbox-services/verify.ps1

$services = @('XboxNetApiSvc', 'XboxGipSvc', 'XblAuthManager', 'XblGameSave')
$allVerified = $true
$foundServices = $false

foreach ($svc in $services) {
    $service = Get-Service $svc -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Host "    [SKIP] $svc not found (already removed or not installed)" -ForegroundColor DarkGray
        continue
    }

    $foundServices = $true

    # SUCCESS: Service is Manual or Disabled AND not Running
    if ($service.StartType -in @('Manual', 'Disabled') -and $service.Status -ne 'Running') {
        Write-Host "    [PASS] $svc is $($service.StartType), $($service.Status)" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] $svc is $($service.StartType), $($service.Status)" -ForegroundColor Red
        $allVerified = $false
    }
}

if (-not $foundServices) {
    Write-Host "    [OK] No Xbox services found (already disabled or not installed)" -ForegroundColor Green
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}
