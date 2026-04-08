# Verify: Disable Windows Widgets

$allVerified = $true

# Check taskbar setting
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $taskbarDa = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).TaskbarDa
    if ($taskbarDa -ne 0) {
        Write-Host "    Taskbar Widgets not disabled (value: $taskbarDa)" -ForegroundColor Yellow
        $allVerified = $false
    }
} catch {
    Write-Host "    Could not verify taskbar Widgets setting" -ForegroundColor Yellow
    $allVerified = $false
}

# Check policy
try {
    $policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (Test-Path $policyPath) {
        $policy = (Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue).AllowNewsAndInterests
        if ($policy -ne 0) {
            Write-Host "    Widgets policy not set to 0 (value: $policy)" -ForegroundColor Yellow
            $allVerified = $false
        }
    }
} catch {
    Write-Verbose "Policy might not exist, which is acceptable: $_"
}

if ($allVerified) {
    exit 0
} else {
    exit 1
}