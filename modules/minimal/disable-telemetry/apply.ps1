# Apply: Disable Diagnostic Telemetry

$ErrorActionPreference = "Stop"

$services = @('DiagTrack', 'dmwappushservice')

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\disable-telemetry"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# Backup current service states
$serviceStates = @()
foreach ($svc in $services) {
    try {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service) {
            $serviceStates += @{
                Name = $service.Name
                Status = $service.Status.ToString()
                StartType = $service.StartType.ToString()
            }
        }
    } catch {}
}
$serviceStates | ConvertTo-Json | Out-File "$backupDir\services.json"

# Stop and disable services
foreach ($svc in $services) {
    try {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Stop-Service -Name $svc -Force
            Write-Host "    Stopped $svc" -ForegroundColor Green
        }

        if ($service) {
            Set-Service -Name $svc -StartupType Disabled
            Write-Host "    Disabled $svc" -ForegroundColor Green
        }
    } catch {
        Write-Host "    Warning: Could not modify $svc - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Set telemetry policy
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}

# Backup current policy
$currentPolicy = Get-ItemProperty -Path $policyPath -ErrorAction SilentlyContinue
$currentPolicy | ConvertTo-Json | Out-File "$backupDir\registry.json"

# Set telemetry to minimal (0)
Set-ItemProperty -Path $policyPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force
Write-Host "    Set telemetry policy to 0 (minimal)" -ForegroundColor Green

exit 0