# Rollback: Disable Windows Widgets

$ErrorActionPreference = "Stop"

# Find most recent backup
$backupRoot = "C:\ProgramData\WinOptimizer\backup"
if (Test-Path $backupRoot) {
    $latestBackup = Get-ChildItem -Path $backupRoot -Directory |
                    Sort-Object Name -Descending |
                    Select-Object -First 1
    $backupDir = Join-Path $latestBackup.FullName "disable-widgets"

    if (Test-Path $backupDir -and (Test-Path "$backupDir\registry.json")) {
        $backup = Get-Content "$backupDir\registry.json" | ConvertFrom-Json

        # Restore taskbar setting
        if ($null -ne $backup.TaskbarDa) {
            $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            Set-ItemProperty -Path $regPath -Name "TaskbarDa" -Value $backup.TaskbarDa -Type DWord -Force
            Write-Host "    Restored taskbar Widgets setting" -ForegroundColor Green
        }
    }
}

# Remove policy
$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
Remove-ItemProperty -Path $policyPath -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue
Write-Host "    Removed Widgets policy" -ForegroundColor Green

exit 0