# Apply: Disable Windows Widgets

$ErrorActionPreference = "Stop"

# Create backup directory
$backupDir = "C:\ProgramData\WinOptimizer\backup\$(Get-Date -Format 'yyyyMMdd_HHmmss')\disable-widgets"
New-Item -Path $backupDir -ItemType Directory -Force | Out-Null

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