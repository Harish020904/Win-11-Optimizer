# Preview: Disable Windows Widgets

Write-Host ""
Write-Host "  Current Widget status:" -ForegroundColor Cyan
Write-Host ""

# Check widget processes
$widgetProcesses = Get-Process 'WebExperience*' -ErrorAction SilentlyContinue
if ($widgetProcesses) {
    Write-Host "    Widget processes running:" -ForegroundColor Green
    $widgetProcesses | ForEach-Object {
        Write-Host "      - $($_.Name) (CPU: $($_.CPU))" -ForegroundColor White
    }
} else {
    Write-Host "    No widget processes running" -ForegroundColor DarkGray
}

# Check taskbar setting
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $taskbarDa = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).TaskbarDa
    Write-Host ""
    Write-Host "  Taskbar Widgets setting: $taskbarDa (1 = enabled)" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "  Could not read taskbar Widgets setting" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  After applying:" -ForegroundColor Green
Write-Host "    - Widgets taskbar button will be hidden" -ForegroundColor White
Write-Host "    - WebExperience background processes will not auto-start" -ForegroundColor White
Write-Host ""