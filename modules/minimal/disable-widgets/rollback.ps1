# Rollback: Disable Windows Widgets

$ErrorActionPreference = "Stop"
$moduleId = "disable-widgets"

# ROLLBACK-001: Read backup path from state.json instead of timestamp-based selection
$stateFile = "C:\ProgramData\WinOptimizer\state\state.json"
$backupDir = $null

if (Test-Path $stateFile) {
    $state = Get-Content $stateFile | ConvertFrom-Json
    if ($state.backups -and $state.backups.$moduleId) {
        $backupDir = $state.backups.$moduleId
    }
}

if (-not $backupDir -or -not (Test-Path $backupDir)) {
    Write-Host "ERROR: No backup record found for module $moduleId. Cannot rollback safely." -ForegroundColor Red
    exit 1
}

if (Test-Path "$backupDir\registry.json") {
    $backup = Get-Content "$backupDir\registry.json" | ConvertFrom-Json

    # Restore taskbar setting
    if ($null -ne $backup.TaskbarDa) {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Set-ItemProperty -Path $regPath -Name "TaskbarDa" -Value $backup.TaskbarDa -Type DWord -Force
        Write-Host "    Restored taskbar Widgets setting" -ForegroundColor Green
    }
}

# Remove policy
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
Remove-ItemProperty -Path $policyPath -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue
Write-Host "    Removed Widgets policy" -ForegroundColor Green

# ROLLBACK-001: Remove backup entry from state.json after successful rollback
if (Test-Path $stateFile) {
    $state = Get-Content $stateFile | ConvertFrom-Json
    if ($state.backups -and $state.backups.$moduleId) {
        $state.backups.PSObject.Properties.Remove($moduleId)
        $state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8
    }
}

exit 0