# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F5: SKU-aware telemetry setting
# WHY: AllowTelemetry=0 only works on Enterprise/Education. On Pro/Home it's clamped to 1.
# APPLY: Replace the Set-ItemProperty call in modules/minimal/disable-telemetry/apply.ps1
#        with the SKU-aware version below.
#
# BEFORE (line 56 of apply.ps1):
#   Set-ItemProperty -Path $policyPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force
#
# AFTER:

# Detect Windows SKU
$sku = (Get-CimInstance -ClassName Win32_OperatingSystem).OperatingSystemSKU

# Enterprise and Education SKUs that support AllowTelemetry=0 (Security level)
$enterpriseSKUs = @(4, 27, 48, 49, 98, 100, 101, 103, 104, 121, 122, 125, 126, 129, 130)

if ($sku -in $enterpriseSKUs) {
    $telemetryValue = 0
    Write-Host "    Enterprise/Education detected (SKU=$sku) — setting AllowTelemetry=0 (Security)" -ForegroundColor Green
} else {
    $telemetryValue = 1
    Write-Host "    [INFO] Non-Enterprise SKU detected (SKU=$sku)" -ForegroundColor Yellow
    Write-Host "    [INFO] Setting AllowTelemetry=1 (Required Diagnostic Data — minimum for this edition)" -ForegroundColor Yellow
    Write-Host "    [INFO] AllowTelemetry=0 is only supported on Enterprise/Education editions" -ForegroundColor Yellow
}

Set-ItemProperty -Path $policyPath -Name "AllowTelemetry" -Value $telemetryValue -Type DWord -Force
Write-Host "    Set telemetry policy to $telemetryValue" -ForegroundColor Green
