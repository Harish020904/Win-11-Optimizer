# Apply: Disable Windows Widgets

$ErrorActionPreference = "Stop"
$moduleId = "disable-widgets"

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

# Stop widget processes
$widgetProcesses = Get-Process 'WebExperience*' -ErrorAction SilentlyContinue
if ($widgetProcesses) {
    $widgetProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "    Stopped widget processes" -ForegroundColor Green
}

# Set taskbar policy to disable widgets
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# Backup current value
$currentValue = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).TaskbarDa
@{ TaskbarDa = $currentValue } | ConvertTo-Json | Out-File "$backupDir\registry.json"

# Set to 0 to disable
Set-ItemProperty -Path $regPath -Name "TaskbarDa" -Value 0 -Type DWord -Force
Write-Host "    Disabled Widgets in taskbar" -ForegroundColor Green

# Also disable via policy (enterprise)
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
if (-not (Test-Path $policyPath)) {
    New-Item -Path $policyPath -Force | Out-Null
}
Set-ItemProperty -Path $policyPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force
Write-Host "    Set policy to disable Widgets" -ForegroundColor Green

exit 0