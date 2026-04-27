#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$dispatcher = Join-Path $repoRoot "WinOptimizer.ps1"

if (-not (Test-Path $dispatcher)) {
    throw "Dispatcher not found: $dispatcher"
}

$powershell = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $powershell) {
    $powershell = (Get-Command pwsh -ErrorAction Stop).Source
}

function Start-Backend {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $powershell
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$dispatcher`" --mode ipc"
    $psi.WorkingDirectory = $repoRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    return $process
}

function Send-Json {
    param(
        [Parameter(Mandatory)]$Process,
        [Parameter(Mandatory)]$Object
    )
    $Process.StandardInput.WriteLine(($Object | ConvertTo-Json -Compress -Depth 10))
    $Process.StandardInput.Flush()
}

function Read-Event {
    param([Parameter(Mandatory)]$Process)
    $line = $Process.StandardOutput.ReadLine()
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Backend returned an empty line."
    }
    return $line | ConvertFrom-Json
}

function Stop-Backend {
    param([Parameter(Mandatory)]$Process)
    try {
        $Process.StandardInput.Close()
        if (-not $Process.WaitForExit(2000)) {
            $Process.Kill()
        }
    } finally {
        $Process.Dispose()
    }
}

Write-Output "IPC smoke: get_state"
$backend = Start-Backend
try {
    Send-Json $backend @{ cmd = "get_state" }
    $event = Read-Event $backend
    if ($event.status -ne "state") { throw "Expected state, got $($event.status)" }
} finally {
    Stop-Backend $backend
}

Write-Output "IPC smoke: get_status"
$backend = Start-Backend
try {
    Send-Json $backend @{ cmd = "get_status" }
    $event = Read-Event $backend
    if ($event.status -ne "status") { throw "Expected status, got $($event.status)" }
} finally {
    Stop-Backend $backend
}

Write-Output "IPC smoke: apply_layer dryRun"
$backend = Start-Backend
try {
    Send-Json $backend @{ cmd = "apply_layer"; layer = "MINIMAL"; dryRun = $true }
    $done = $false
    $guard = 0
    while (-not $done -and $guard -lt 20) {
        $guard++
        $event = Read-Event $backend
        switch ($event.status) {
            "consent_required" {
                Send-Json $backend @{ cmd = "consent"; decision = "apply" }
            }
            "done" {
                if (-not $event.passed) { throw "Dry-run apply did not pass." }
                $done = $true
            }
            "error" {
                throw $event.message
            }
        }
    }
    if (-not $done) { throw "Timed out waiting for dry-run apply completion." }
} finally {
    Stop-Backend $backend
}

Write-Output "IPC smoke: GODMODE cancel"
$backend = Start-Backend
try {
    Send-Json $backend @{ cmd = "apply_layer"; layer = "GODMODE"; dryRun = $true }
    $event = Read-Event $backend
    if ($event.status -ne "consent_required") { throw "Expected GODMODE consent." }
    Send-Json $backend @{ cmd = "consent"; decision = "skip" }
    $done = $false
    while (-not $done) {
        $event = Read-Event $backend
        if ($event.status -eq "done") { $done = $true }
        if ($event.status -eq "error") { throw $event.message }
    }
} finally {
    Stop-Backend $backend
}

Write-Output "IPC smoke: backend death"
$backend = Start-Backend
$backend.Kill()
if (-not $backend.WaitForExit(2000)) {
    throw "Backend did not exit after kill."
}
$backend.Dispose()

Write-Output "IPC smoke tests passed."
