# Verify: Disable Diagnostic Telemetry

$services = @('DiagTrack', 'dmwappushservice')
$allVerified = $true

# Check services
foreach ($svc in $services) {
    $service = Get-Service $svc -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.StartType -ne 'Disabled') {
            Write-Host "    $svc not disabled (StartType: $($service.StartType))" -ForegroundColor Yellow
            $allVerified = $false
        }
        if ($service.Status -eq 'Running') {
            Write-Host "    $svc is still running" -ForegroundColor Yellow
            $allVerified = $false
        }
    }
}

# Check telemetry policy
try {
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    if (Test-Path $policyPath) {
        $telemetry = (Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue).AllowTelemetry
        if ($telemetry -ne 0) {
            Write-Host "    Telemetry policy not set to 0 (current: $telemetry)" -ForegroundColor Yellow
            $allVerified = $false
        }
    }
} catch {
    Write-Host "    Could not verify telemetry policy" -ForegroundColor Yellow
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}