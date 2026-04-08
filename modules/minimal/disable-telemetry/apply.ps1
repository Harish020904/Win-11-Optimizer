# Apply: Disable Diagnostic Telemetry

$ErrorActionPreference = "Stop"

$services = @('DiagTrack', 'dmwappushservice')
$moduleId = "disable-telemetry"

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\$moduleId"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

# ROLLBACK-001: Record backup path in state.json for explicit rollback tracking
$stateFile = "C:\ProgramData\WinOptimizer\state\state.json"
$stateDir = Split-Path $stateFile -Parent
if (-not (Test-Path $stateDir)) {
    New-Item -Path $stateDir -ItemType Directory -Force | Out-Null
}
$state = if (Test-Path $stateFile) {
    Get-Content $stateFile | ConvertFrom-Json
} else {
    @{ backups = @{} }
}
if (-not $state.backups) { $state | Add-Member -NotePropertyName "backups" -NotePropertyValue @{} -Force }
$state.backups | Add-Member -NotePropertyName $moduleId -NotePropertyValue $backupDir -Force
$state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8

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
    } catch {
        Write-Verbose "Could not get service state for $svc: $_"
    }
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