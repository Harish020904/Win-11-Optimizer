#Requires -Version 5.1
<#
.SYNOPSIS
    Headless IPC dispatcher for Win11 Optimizer.

.DESCRIPTION
    The Rust ratatui binary owns the terminal. This script is a JSON-lines
    backend that routes commands to the existing PowerShell module scripts.
#>

[CmdletBinding()]
param(
    [string]$Mode,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

$Script:Version = "2.0.0"
$Script:ProjectRoot = $PSScriptRoot
$Script:ModulesPath = Join-Path $Script:ProjectRoot "modules"
$Script:ManifestsPath = Join-Path $Script:ProjectRoot "runtime\manifests"
$Script:IsWinOptimizerWindows = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
$Script:ProgramDataPath = if ($Script:IsWinOptimizerWindows) {
    "C:\ProgramData\WinOptimizer"
} else {
    Join-Path $Script:ProjectRoot ".winoptimizer-data"
}
$Script:BackupPath = Join-Path $Script:ProgramDataPath "backup"
$Script:LogPath = Join-Path $Script:ProgramDataPath "logs"
$Script:StatePath = Join-Path $Script:ProgramDataPath "state"
$Script:ProtectedServices = @(
    'TrustedInstaller', 'WinDefend', 'WdNisSvc', 'wuauserv', 'UsoSvc',
    'DcomLaunch', 'RpcSs', 'RpcEptMapper', 'PlugPlay', 'EventLog',
    'Schedule', 'LSM', 'Winmgmt', 'LanmanServer', 'LanmanWorkstation',
    'Dnscache', 'Dhcp', 'NSI'
)

function New-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')][string]$Level = 'INFO'
    )

    New-Directory -Path $Script:LogPath
    $entry = [PSCustomObject]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        level = $Level
        message = $Message
    }
    $logFile = Join-Path $Script:LogPath "optimizer-$(Get-Date -Format 'yyyyMMdd').log"
    $entry | ConvertTo-Json -Compress | Out-File -FilePath $logFile -Append -Encoding UTF8
}

function Write-JsonEvent {
    param([Parameter(Mandatory)]$Event)
    $json = $Event | ConvertTo-Json -Compress -Depth 20
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function Read-JsonCommand {
    $line = [Console]::In.ReadLine()
    if ($null -eq $line) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($line)) {
        return [PSCustomObject]@{ cmd = "noop" }
    }
    return $line | ConvertFrom-Json
}

function Convert-ScalarValue {
    param([string]$Value)
    if ($null -eq $Value) { return "" }
    $trimmed = $Value.Trim()
    if (($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or
        ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'"))) {
        return $trimmed.Substring(1, $trimmed.Length - 2)
    }
    return $trimmed
}

function Import-SimpleYaml {
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -Path $Path
    $result = @{}
    $i = 0
    while ($i -lt $lines.Count) {
        $raw = $lines[$i]
        $trimmed = $raw.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            $i++
            continue
        }

        if ($trimmed -match '^([A-Za-z0-9_]+):\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2]
            if ($key -eq "modules") {
                $items = @()
                $i++
                while ($i -lt $lines.Count) {
                    $itemLine = $lines[$i]
                    $itemTrimmed = $itemLine.Trim()
                    if ($itemTrimmed -match '^-\s*(.+)$') {
                        $items += (Convert-ScalarValue $matches[1])
                        $i++
                        continue
                    }
                    if (-not [string]::IsNullOrWhiteSpace($itemTrimmed) -and -not $itemLine.StartsWith(" ")) {
                        break
                    }
                    $i++
                }
                $result[$key] = $items
                continue
            }

            if ($value.Trim() -in @(">", "|")) {
                $parts = @()
                $i++
                while ($i -lt $lines.Count) {
                    $blockLine = $lines[$i]
                    if (-not [string]::IsNullOrWhiteSpace($blockLine) -and -not $blockLine.StartsWith(" ")) {
                        break
                    }
                    $blockTrimmed = $blockLine.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($blockTrimmed)) {
                        $parts += $blockTrimmed
                    }
                    $i++
                }
                $result[$key] = ($parts -join " ")
                continue
            }

            $result[$key] = Convert-ScalarValue $value
        }
        $i++
    }

    return $result
}

function Get-ManifestPath {
    param([Parameter(Mandatory)][string]$Layer)
    $normalized = $Layer.ToLowerInvariant()
    return Join-Path $Script:ManifestsPath "$normalized.yaml"
}

function Get-LayerManifest {
    param([Parameter(Mandatory)][string]$Layer)
    $manifestPath = Get-ManifestPath -Layer $Layer
    if (-not (Test-Path $manifestPath)) {
        throw "Unknown layer '$Layer'"
    }
    return Import-SimpleYaml -Path $manifestPath
}

function Get-ModuleMetadata {
    param(
        [Parameter(Mandatory)]$Manifest,
        [Parameter(Mandatory)][string]$ModuleId,
        [Parameter(Mandatory)][int]$Number
    )

    $modulePath = Join-Path $Script:ModulesPath "$($Manifest.layer)\$ModuleId"
    $metadataPath = Join-Path $modulePath "metadata.yaml"
    if (-not (Test-Path $metadataPath)) {
        throw "Module metadata not found: $ModuleId"
    }

    $metadata = Import-SimpleYaml -Path $metadataPath
    $metadata["number"] = $Number
    $metadata["layer"] = $Manifest.layer
    $metadata["modulePath"] = $modulePath
    return $metadata
}

function Get-StateObject {
    $stateFile = Join-Path $Script:StatePath "applied_layers.json"
    if (-not (Test-Path $stateFile)) {
        return [PSCustomObject]@{
            version = 1
            layers = [PSCustomObject]@{}
            last_modified = $null
        }
    }
    return Get-Content -Path $stateFile -Raw | ConvertFrom-Json
}

function Save-StateObject {
    param([Parameter(Mandatory)]$State)
    New-Directory -Path $Script:StatePath
    $stateFile = Join-Path $Script:StatePath "applied_layers.json"
    if ($State.PSObject.Properties["last_modified"]) {
        $State.last_modified = (Get-Date).ToUniversalTime().ToString("o")
    } else {
        $State | Add-Member -MemberType NoteProperty -Name "last_modified" -Value ((Get-Date).ToUniversalTime().ToString("o")) -Force
    }
    $State | ConvertTo-Json -Depth 20 | Out-File -FilePath $stateFile -Encoding UTF8
}

function Get-AppliedLayerNames {
    param([Parameter(Mandatory)]$State)
    if (-not $State.PSObject.Properties["layers"]) {
        return @()
    }
    return @($State.layers.PSObject.Properties | ForEach-Object { $_.Name })
}

function Set-ModuleState {
    param(
        [Parameter(Mandatory)][string]$Layer,
        [Parameter(Mandatory)][string]$ModuleId,
        [Parameter(Mandatory)][bool]$Applied
    )

    $state = Get-StateObject
    if (-not $state.PSObject.Properties["layers"]) {
        $state | Add-Member -MemberType NoteProperty -Name "layers" -Value ([PSCustomObject]@{}) -Force
    }

    $layerKey = $Layer.ToLowerInvariant()
    $existing = $state.layers.PSObject.Properties[$layerKey]
    $modules = if ($existing) { @($existing.Value.modules) } else { @() }

    if ($Applied) {
        if ($modules -notcontains $ModuleId) {
            $modules += $ModuleId
        }
        $state.layers | Add-Member -MemberType NoteProperty -Name $layerKey -Value ([PSCustomObject]@{
            applied_at = (Get-Date).ToUniversalTime().ToString("o")
            modules = @($modules)
            snapshot_id = $null
        }) -Force
    } elseif ($existing) {
        $modules = @($modules | Where-Object { $_ -ne $ModuleId })
        if ($modules.Count -gt 0) {
            $state.layers | Add-Member -MemberType NoteProperty -Name $layerKey -Value ([PSCustomObject]@{
                applied_at = $existing.Value.applied_at
                modules = @($modules)
                snapshot_id = $existing.Value.snapshot_id
            }) -Force
        } else {
            $state.layers.PSObject.Properties.Remove($layerKey)
        }
    }

    Save-StateObject -State $state
}

function Invoke-ModuleScript {
    param(
        [Parameter(Mandatory)][string]$ModulePath,
        [Parameter(Mandatory)][ValidateSet("apply", "rollback", "verify")][string]$Action
    )

    $scriptPath = Join-Path $ModulePath "$Action.ps1"
    if (-not (Test-Path $scriptPath)) {
        return [PSCustomObject]@{ success = $true; exitCode = 0; output = "No $Action script present." }
    }

    $powershell = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
    if (-not $powershell) {
        $powershell = "powershell.exe"
    }

    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $powershell
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.WorkingDirectory = $ModulePath
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
        Write-Log -Level DEBUG -Message "[$Action stdout] $stdout"
    }
    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        Write-Log -Level WARN -Message "[$Action stderr] $stderr"
    }

    return [PSCustomObject]@{
        success = ($process.ExitCode -eq 0)
        exitCode = $process.ExitCode
        output = (($stdout + "`n" + $stderr).Trim())
    }
}

function Send-ConsentRequired {
    param([Parameter(Mandatory)]$Metadata)
    Write-JsonEvent ([PSCustomObject]@{
        status = "consent_required"
        tweakNumber = [int]$Metadata.number
        layer = ([string]$Metadata.layer).ToUpperInvariant()
        tweakName = $Metadata.title
        summary = $Metadata.summary
        whatChanges = $Metadata.whatChanges
        reversible = ([string]$Metadata.reversible).ToUpperInvariant()
        riskLevel = ([string]$Metadata.riskLevel).ToUpperInvariant()
    })
}

function Read-ConsentDecision {
    while ($true) {
        $command = Read-JsonCommand
        if ($null -eq $command) {
            return "quit"
        }
        if ($command.cmd -eq "consent") {
            $decision = ([string]$command.decision).ToLowerInvariant()
            if ($decision -eq "cancel") {
                return "skip"
            }
            return $decision
        }
    }
}

function Invoke-ApplyLayer {
    param(
        [Parameter(Mandatory)][string]$Layer,
        [bool]$DryRun = $false
    )

    $manifest = Get-LayerManifest -Layer $Layer
    New-Directory -Path $Script:BackupPath
    New-Directory -Path $Script:LogPath
    New-Directory -Path $Script:StatePath
    Write-Log -Message "Applying layer $($manifest.layer), dryRun=$DryRun" -Level INFO

    $runAll = $false
    $passed = $true
    $index = 0
    foreach ($moduleId in @($manifest.modules)) {
        $index++
        $metadata = Get-ModuleMetadata -Manifest $manifest -ModuleId $moduleId -Number $index
        if (-not $runAll) {
            Send-ConsentRequired -Metadata $metadata
            $decision = Read-ConsentDecision
            switch ($decision) {
                "skip" {
                    Write-JsonEvent ([PSCustomObject]@{
                        status = "progress"; tweakId = $index; tweakName = $metadata.title
                        message = "Skipped $($metadata.title)"; state = "skipped"
                    })
                    continue
                }
                "run_all" { $runAll = $true }
                "dry_run" { $DryRun = $true }
                "quit" {
                    $passed = $false
                    break
                }
            }
        }

        Write-JsonEvent ([PSCustomObject]@{
            status = "progress"; tweakId = $index; tweakName = $metadata.title
            message = "Applying $($metadata.title)..."; state = "in_progress"
        })

        if ($DryRun) {
            Start-Sleep -Milliseconds 150
            Write-JsonEvent ([PSCustomObject]@{
                status = "progress"; tweakId = $index; tweakName = $metadata.title
                message = "[dry-run] Would apply $($metadata.title)"; state = "done"
            })
            continue
        }

        $result = Invoke-ModuleScript -ModulePath $metadata.modulePath -Action "apply"
        if ($result.success) {
            Set-ModuleState -Layer $manifest.layer -ModuleId $metadata.id -Applied $true
            Write-JsonEvent ([PSCustomObject]@{
                status = "progress"; tweakId = $index; tweakName = $metadata.title
                message = "Applied $($metadata.title)"; state = "done"
            })
        } else {
            $passed = $false
            Write-JsonEvent ([PSCustomObject]@{
                status = "error"; tweakId = $index; tweakName = $metadata.title
                message = "Failed $($metadata.title): exit $($result.exitCode)"
            })
            break
        }
    }

    Write-JsonEvent ([PSCustomObject]@{
        status = "done"
        layer = ([string]$manifest.layer).ToUpperInvariant()
        passed = $passed
    })
}

function Invoke-RollbackLayer {
    param([Parameter(Mandatory)][string]$Layer)

    $manifest = Get-LayerManifest -Layer $Layer
    $modules = @($manifest.modules)
    [array]::Reverse($modules)
    $passed = $true
    $index = 0

    foreach ($moduleId in $modules) {
        $index++
        $metadata = Get-ModuleMetadata -Manifest $manifest -ModuleId $moduleId -Number $index
        Write-JsonEvent ([PSCustomObject]@{
            status = "progress"; tweakId = $index; tweakName = $metadata.title
            message = "Rolling back $($metadata.title)..."; state = "in_progress"
        })
        $result = Invoke-ModuleScript -ModulePath $metadata.modulePath -Action "rollback"
        if ($result.success) {
            Set-ModuleState -Layer $manifest.layer -ModuleId $metadata.id -Applied $false
            Write-JsonEvent ([PSCustomObject]@{
                status = "progress"; tweakId = $index; tweakName = $metadata.title
                message = "Rolled back $($metadata.title)"; state = "done"
            })
        } else {
            $passed = $false
            Write-JsonEvent ([PSCustomObject]@{
                status = "error"; tweakId = $index; tweakName = $metadata.title
                message = "Rollback failed $($metadata.title): exit $($result.exitCode)"
            })
        }
    }

    Write-JsonEvent ([PSCustomObject]@{
        status = "done"; layer = ([string]$manifest.layer).ToUpperInvariant(); passed = $passed
    })
}

function Invoke-VerifySystem {
    $failures = 0
    foreach ($svc in $Script:ProtectedServices) {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        $ok = $service -and $service.Status -eq "Running"
        if (-not $ok) { $failures++ }
        Write-JsonEvent ([PSCustomObject]@{
            status = "verify"
            test = "Service $svc"
            expected = "Running"
            actual = if ($service) { [string]$service.Status } else { "Not found" }
            passed = [bool]$ok
        })
    }

    try {
        $defender = Get-MpComputerStatus -ErrorAction Stop
        $ok = [bool]$defender.RealTimeProtectionEnabled
        if (-not $ok) { $failures++ }
        Write-JsonEvent ([PSCustomObject]@{
            status = "verify"; test = "Windows Defender"; expected = "Real-time protection enabled"
            actual = if ($ok) { "Enabled" } else { "Disabled" }; passed = $ok
        })
    } catch {
        $failures++
        Write-JsonEvent ([PSCustomObject]@{
            status = "verify"; test = "Windows Defender"; expected = "Readable status"
            actual = "Unavailable"; passed = $false
        })
    }

    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    $wuOk = $null -ne $wu
    if (-not $wuOk) { $failures++ }
    Write-JsonEvent ([PSCustomObject]@{
        status = "verify"; test = "Windows Update"; expected = "Service accessible"
        actual = if ($wu) { [string]$wu.Status } else { "Not found" }; passed = [bool]$wuOk
    })

    Write-JsonEvent ([PSCustomObject]@{ status = "done"; layer = "VERIFY"; passed = ($failures -eq 0) })
}

function Invoke-Snapshot {
    New-Directory -Path $Script:BackupPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotDir = Join-Path $Script:BackupPath $timestamp
    New-Directory -Path $snapshotDir
    Write-JsonEvent ([PSCustomObject]@{ status = "progress"; tweakId = 1; message = "Exporting services"; state = "in_progress" })
    Get-Service | Select-Object Name, DisplayName, Status, StartType |
        Export-Csv (Join-Path $snapshotDir "services.csv") -NoTypeInformation
    Write-JsonEvent ([PSCustomObject]@{ status = "progress"; tweakId = 1; message = "Snapshot created: $snapshotDir"; state = "done" })
    Write-JsonEvent ([PSCustomObject]@{ status = "done"; layer = "SNAPSHOT"; passed = $true })
}

function Invoke-SnapshotPlainText {
    New-Directory -Path $Script:BackupPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotDir = Join-Path $Script:BackupPath $timestamp
    New-Directory -Path $snapshotDir
    Write-Output "Creating snapshot: $snapshotDir"
    Get-Service | Select-Object Name, DisplayName, Status, StartType |
        Export-Csv (Join-Path $snapshotDir "services.csv") -NoTypeInformation
    Write-Output "Snapshot complete."
}

function Invoke-VerifySystemPlainText {
    $failures = 0
    foreach ($svc in $Script:ProtectedServices) {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        $ok = $service -and $service.Status -eq "Running"
        if ($ok) {
            Write-Output "[PASS] Service $svc is running"
        } else {
            Write-Output "[FAIL] Service $svc is not running or not found"
            $failures++
        }
    }

    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wu) {
        Write-Output "[PASS] Windows Update service accessible: $($wu.Status)"
    } else {
        Write-Output "[FAIL] Windows Update service not found"
        $failures++
    }

    if ($failures -eq 0) {
        Write-Output "ALL CHECKS PASSED"
    } else {
        Write-Output "$failures failures found."
    }
}

function Invoke-ApplyLayerPlainText {
    param(
        [Parameter(Mandatory)][string]$Layer,
        [bool]$DryRun = $false
    )

    $manifest = Get-LayerManifest -Layer $Layer
    New-Directory -Path $Script:BackupPath
    New-Directory -Path $Script:LogPath
    New-Directory -Path $Script:StatePath

    Write-Output ""
    Write-Output "Applying $(([string]$manifest.layer).ToUpperInvariant()) layer"
    Write-Output "Dry-run: $DryRun"
    Write-Output ""

    $runAll = $false
    $index = 0
    foreach ($moduleId in @($manifest.modules)) {
        $index++
        $metadata = Get-ModuleMetadata -Manifest $manifest -ModuleId $moduleId -Number $index

        Write-Output "[$index] $($metadata.title)"
        Write-Output $metadata.summary
        Write-Output "Affects: $($metadata.whatChanges)"
        Write-Output "Reversible: $($metadata.reversible)  Risk: $($metadata.riskLevel)"

        if (-not $runAll) {
            $choice = Read-Host "Apply this tweak? [Y]es [N]o [A]ll [D]ry-run [Q]uit"
            switch ($choice.ToUpperInvariant()) {
                "N" {
                    Write-Output "Skipped."
                    continue
                }
                "A" {
                    if (([string]$manifest.layer).Equals("godmode", [System.StringComparison]::OrdinalIgnoreCase)) {
                        $confirm = Read-Host "Type GODMODE to approve all God Mode tweaks"
                        if ($confirm -ne "GODMODE") {
                            Write-Output "Run-all cancelled."
                            continue
                        }
                    }
                    $runAll = $true
                }
                "D" { $DryRun = $true }
                "Q" {
                    Write-Output "Exiting."
                    return
                }
            }
        }

        if ($DryRun) {
            Write-Output "[dry-run] Would apply $($metadata.title)"
            continue
        }

        $result = Invoke-ModuleScript -ModulePath $metadata.modulePath -Action "apply"
        if ($result.success) {
            Set-ModuleState -Layer $manifest.layer -ModuleId $metadata.id -Applied $true
            Write-Output "Applied."
        } else {
            Write-Output "Failed: exit $($result.exitCode)"
            return
        }
    }

    Write-Output "Layer complete."
}

function Get-SystemMetrics {
    $hasCim = $null -ne (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)
    $hasService = $null -ne (Get-Command Get-Service -ErrorAction SilentlyContinue)
    $os = if ($hasCim) { Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } else { $null }
    $ramTotal = if ($os) { [math]::Round($os.TotalVisibleMemorySize / 1MB, 1) } else { 0 }
    $ramFree = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 1) } else { 0 }
    $cpu = if ($hasCim) {
        Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
    } else {
        $null
    }
    $serviceCount = if ($hasService) {
        @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }).Count
    } else {
        0
    }
    $defender = "Unknown"
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $defender = if ($mp.RealTimeProtectionEnabled) { "Enabled" } else { "Disabled" }
    } catch {}
    $wu = if ($hasService) { Get-Service wuauserv -ErrorAction SilentlyContinue } else { $null }
    $state = Get-StateObject
    $appliedLayers = Get-AppliedLayerNames -State $state

    return [PSCustomObject]@{
        ramUsedGb = [math]::Max(0, [math]::Round($ramTotal - $ramFree, 1))
        ramTotalGb = $ramTotal
        cpuIdlePercent = if ($cpu) { [int](100 - $cpu.PercentProcessorTime) } else { 0 }
        processCount = @(Get-Process -ErrorAction SilentlyContinue).Count
        runningServices = $serviceCount
        defenderStatus = $defender
        windowsUpdateStatus = if ($wu) { [string]$wu.Status } else { "Not found" }
        appliedLayers = @($appliedLayers)
    }
}

function Invoke-IpcLoop {
    while ($true) {
        try {
            $command = Read-JsonCommand
            if ($null -eq $command) {
                break
            }

            switch ([string]$command.cmd) {
                "noop" {}
                "get_status" {
                    Write-JsonEvent ([PSCustomObject]@{ status = "status"; metrics = (Get-SystemMetrics) })
                }
                "get_state" {
                    Write-JsonEvent ([PSCustomObject]@{ status = "state"; state = (Get-StateObject) })
                }
                "apply_layer" {
                    Invoke-ApplyLayer -Layer ([string]$command.layer) -DryRun ([bool]$command.dryRun)
                }
                "rollback_layer" {
                    Invoke-RollbackLayer -Layer ([string]$command.layer)
                }
                "verify_system" {
                    Invoke-VerifySystem
                }
                "snapshot" {
                    Invoke-Snapshot
                }
                default {
                    Write-JsonEvent ([PSCustomObject]@{ status = "error"; tweakId = 0; message = "Unknown command: $($command.cmd)" })
                }
            }
        } catch {
            Write-Log -Level ERROR -Message $_.Exception.Message
            Write-JsonEvent ([PSCustomObject]@{ status = "error"; tweakId = 0; message = $_.Exception.Message })
        }
    }
}

function Invoke-PlainTextFallback {
    Write-Output "Win11 Optimizer fallback mode"
    Write-Output "Install/build the Rust TUI and launch .\win11-optimizer-tui.exe for the full interface."
    Write-Output ""
    Write-Output "1. Apply MINIMAL"
    Write-Output "2. Apply MODERATE"
    Write-Output "3. Apply ULTIMATE"
    Write-Output "4. Apply GODMODE"
    Write-Output "5. Verify System"
    Write-Output "6. Snapshot"
    $choice = Read-Host "Choice"
    switch ($choice) {
        "1" { Invoke-ApplyLayerPlainText -Layer "MINIMAL" -DryRun $false }
        "2" { Invoke-ApplyLayerPlainText -Layer "MODERATE" -DryRun $false }
        "3" { Invoke-ApplyLayerPlainText -Layer "ULTIMATE" -DryRun $false }
        "4" { Invoke-ApplyLayerPlainText -Layer "GODMODE" -DryRun $false }
        "5" { Invoke-VerifySystemPlainText }
        "6" { Invoke-SnapshotPlainText }
        default { Write-Output "No action selected." }
    }
}

$isIpc = ($Mode -eq "ipc") -or ($RemainingArgs -contains "--mode" -and $RemainingArgs -contains "ipc") -or ($args -contains "--mode" -and $args -contains "ipc")
if ($isIpc) {
    Invoke-IpcLoop
} else {
    Invoke-PlainTextFallback
}
