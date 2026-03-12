# Verify: Disable Windows Error Reporting

$allVerified = $true

# Check service
$service = Get-Service WerSvc -ErrorAction SilentlyContinue
if ($service) {
    if ($service.StartType -ne 'Disabled') {
        Write-Host "    WerSvc not disabled (StartType: $($service.StartType))" -ForegroundColor Yellow
        $allVerified = $false
    }
    if ($service.Status -eq 'Running') {
        Write-Host "    WerSvc is still running" -ForegroundColor Yellow
        $allVerified = $false
    }
} else {
    Write-Host "    WerSvc service not found" -ForegroundColor Green
}

# Check registry
try {
    $werPath = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
    if (Test-Path $werPath) {
        $disabled = (Get-ItemProperty -Path $werPath -ErrorAction SilentlyContinue).Disabled
        if ($disabled -ne 1) {
            Write-Host "    WER not disabled in registry (value: $disabled)" -ForegroundColor Yellow
            $allVerified = $false
        }
    }
} catch {
    Write-Host "    Could not verify WER registry setting" -ForegroundColor Yellow
    $allVerified = $false
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}