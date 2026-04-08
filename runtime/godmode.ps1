#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Win11 Optimizer - Production-Grade Windows 11 Optimization Runtime

.DESCRIPTION
    The main orchestrator for Win11 Optimizer. Applies optimization layers
    with preview, snapshot, verification, and rollback capabilities.

    Safety Features:
    - Never modifies protected Windows components
    - Creates system restore points
    - Captures baseline snapshots
    - Generates rollback scripts
    - Requires user consent per module

.PARAMETER Manifest
    Path to the layer manifest YAML file

.PARAMETER Preview
    Show what would change without applying (dry-run)

.PARAMETER Apply
    Apply the optimizations from the manifest

.PARAMETER Verify
    Verify that optimizations were applied correctly

.PARAMETER Rollback
    Rollback the layer

.PARAMETER RollbackAll
    Rollback all applied layers in reverse order

.PARAMETER Snapshot
    Create a baseline system snapshot

.PARAMETER Status
    Show current system status and applied layers

.PARAMETER VerifySystem
    Run full system integrity verification

.EXAMPLE
    .\godmode.ps1 --manifest .\manifests\minimal.yaml --preview

.EXAMPLE
    .\godmode.ps1 --manifest .\manifests\minimal.yaml --apply

.EXAMPLE
    .\godmode.ps1 --rollback --layer minimal

.NOTES
    Version: 1.0.0
    License: MIT
    Author: Win11 Optimizer Team

    SAFETY:
    - This script requires Administrator privileges
    - Always review disclaimers before applying
    - Create backups before using
    - Test in VM before production use
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Manifest', Mandatory = $true)]
    [ValidateScript({
        if (-not (Test-Path $_)) {
            throw "Manifest file not found: $_"
        }
        return $true
    })]
    [string]$Manifest,

    [Parameter(ParameterSetName = 'Manifest')]
    [switch]$Preview,

    [Parameter(ParameterSetName = 'Manifest')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Manifest')]
    [switch]$Verify,

    [Parameter(ParameterSetName = 'Manifest')]
    [switch]$Rollback,

    [Parameter(ParameterSetName = 'RollbackAll')]
    [switch]$RollbackAll,

    [Parameter(ParameterSetName = 'Snapshot')]
    [switch]$Snapshot,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'VerifySystem')]
    [switch]$VerifySystem
)

# ============================================================================
# CONFIGURATION
# ============================================================================

$Script:Version = "1.0.0"
$Script:BasePath = $PSScriptRoot
$Script:ProjectRoot = Split-Path -Parent $Script:BasePath
$Script:ModulesPath = Join-Path $Script:ProjectRoot "modules"
$Script:ManifestsPath = Join-Path $Script:BasePath "manifests"
$Script:BackupPath = "C:\ProgramData\WinOptimizer\backup"
$Script:LogPath = "C:\ProgramData\WinOptimizer\logs"
$Script:StatePath = "C:\ProgramData\WinOptimizer\state"
$Script:RollbackPath = Join-Path $Script:ProjectRoot "rollback"

# Protected services that must never be modified
$Script:ProtectedServices = @(
    'TrustedInstaller',
    'WinDefend',
    'WdNisSvc',
    'wuauserv',
    'UsoSvc',
    'DcomLaunch',
    'RpcSs',
    'RpcEptMapper',
    'PlugPlay',
    'EventLog',
    'Schedule',
    'LSM',
    'Winmgmt',
    'LanmanServer',
    'LanmanWorkstation',
    'Dnscache',
    'Dhcp',
    'NSI'
)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Console output
    switch ($Level) {
        'INFO'  { Write-Host $logEntry -ForegroundColor Cyan }
        'WARN'  { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR' { Write-Host $logEntry -ForegroundColor Red }
        'DEBUG' { Write-Host $logEntry -ForegroundColor DarkGray }
    }

    # File output
    $logFile = Join-Path $Script:LogPath "optimizer-$(Get-Date -Format 'yyyyMMdd').log"
    try {
        $logEntry | Out-File -FilePath $logFile -Append -Encoding UTF8
    } catch {
        Write-Verbose "Could not write to log file: $_"
    }
}

function New-Directory {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created directory: $Path" -Level DEBUG
    }
}

function Import-Manifest {
    param([string]$Path)

    try {
        $content = Get-Content $Path -Raw
        # Parse YAML (simplified - production would use PowerShell-Yaml module)
        $manifest = @{}
        $currentSection = $null

        foreach ($line in $content -split "`n") {
            $line = $line.Trim()
            if ($line -match '^#') { continue }  # Skip comments
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            if ($line -match '^(\w+):\s*(.*)$') {
                $key = $matches[1]
                $value = $matches[2] -replace '["'']', ''

                if ($key -eq 'modules') {
                    $currentSection = 'modules'
                    $manifest[$key] = @()
                } else {
                    $manifest[$key] = $value
                }
            } elseif ($currentSection -eq 'modules' -and $line -match '^\s*-\s*(.+)$') {
                $manifest['modules'] += $matches[1].Trim()
            }
        }

        return $manifest
    } catch {
        Write-Log -Message "Failed to parse manifest: $_" -Level ERROR
        throw
    }
}

function Test-ProtectedService {
    param([string]$ServiceName)

    return $Script:ProtectedServices -contains $ServiceName
}

function Get-ModuleState {
    param(
        [string]$Layer,
        [string]$ModuleId
    )

    $stateFile = Join-Path $Script:StatePath "applied.json"
    if (-not (Test-Path $stateFile)) {
        return @{ Applied = $false }
    }

    $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    $layerState = $state.PSObject.Properties[$Layer]

    if (-not $layerState) {
        return @{ Applied = $false }
    }

    $moduleState = $layerState.Value.PSObject.Properties[$ModuleId]
    if (-not $moduleState) {
        return @{ Applied = $false }
    }

    return @{
        Applied = $moduleState.Value.applied
        AppliedAt = $moduleState.Value.appliedAt
    }
}

function Set-ModuleState {
    param(
        [string]$Layer,
        [string]$ModuleId,
        [bool]$Applied,
        [string]$RollbackScript = $null
    )

    $stateFile = Join-Path $Script:StatePath "applied.json"

    # Initialize state file if needed
    if (-not (Test-Path $stateFile)) {
        $state = [PSCustomObject]@{
            Version = $Script:Version
            AppliedLayers = @()
        }
    } else {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    }

    # Initialize layer if needed
    $layerState = $state.PSObject.Properties[$Layer]
    if (-not $layerState) {
        Add-Member -InputObject $state -MemberType NoteProperty -Name $Layer -Value ([PSCustomObject]@{})
        $layerState = $state.$Layer
    }

    # Update module state
    $moduleState = @{
        applied = $Applied
        appliedAt = if ($Applied) { Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" } else { $null }
        rollbackScript = $RollbackScript
    }

    $layerState | Add-Member -MemberType NoteProperty -Name $ModuleId -Value ([PSCustomObject]$moduleState) -Force

    # Update applied layers list
    if ($Applied) {
        if ($state.AppliedLayers -notcontains $Layer) {
            $state.AppliedLayers += $Layer
        }
    }

    $state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8
    Write-Log -Message "Module state updated: $Layer/$ModuleId = $Applied" -Level DEBUG
}

function New-SystemRestorePoint {
    param([string]$Description)

    try {
        # Bypass 24-hour cooldown
        $frequencyKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        $originalFrequency = (Get-ItemProperty -Path $frequencyKey -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
        Set-ItemProperty -Path $frequencyKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force

        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
        Write-Log -Message "System Restore point created: $Description" -Level INFO

        # Restore original frequency
        if ($originalFrequency) {
            Set-ItemProperty -Path $frequencyKey -Name "SystemRestorePointCreationFrequency" -Value $originalFrequency -Type DWord -Force
        }

        return $true
    } catch {
        Write-Log -Message "Failed to create System Restore point: $_" -Level WARN
        return $false
    }
}

function Show-DisclaimerCard {
    param(
        [string]$TweakNumber,
        [string]$Layer,
        [string]$TweakName,
        [string]$Summary,
        [string]$WhatChanges,
        [string]$Reversible,
        [string]$RiskLevel
    )

    $cardWidth = 76
    $borderColor = if ($RiskLevel -eq 'HIGH') { 'Red' } elseif ($RiskLevel -eq 'MEDIUM') { 'Yellow' } else { 'Cyan' }

    Write-Host ""
    Write-Host ("═" * $cardWidth) -ForegroundColor $borderColor
    Write-Host ("║") -NoNewline -ForegroundColor $borderColor
    Write-Host (" DISCLAIMER #{0} [{1}] - {2}" -f $TweakNumber, $Layer.ToUpper(), $TweakName).PadRight($cardWidth - 2) -NoNewline -ForegroundColor White
    Write-Host ("║") -ForegroundColor $borderColor

    Write-Host ("║" + "─" * ($cardWidth - 2) + "║") -ForegroundColor $borderColor

    Write-Host ("║") -NoNewline -ForegroundColor $borderColor
    Write-Host (" PLAIN ENGLISH SUMMARY:").PadRight($cardWidth - 2) -NoNewline -ForegroundColor Cyan
    Write-Host ("║") -ForegroundColor $borderColor

    # Word-wrap summary
    $maxWidth = $cardWidth - 4
    $words = $Summary -split '\s+'
    $currentLine = ""
    foreach ($word in $words) {
        if ($currentLine.Length -eq 0) {
            $currentLine = $word
        } elseif (($currentLine.Length + 1 + $word.Length) -le $maxWidth) {
            $currentLine += " " + $word
        } else {
            Write-Host ("║ {0}{1}" -f $currentLine, (" " * ($maxWidth - $currentLine.Length))) -ForegroundColor White
            $currentLine = $word
        }
    }
    Write-Host ("║ {0}{1}" -f $currentLine, (" " * ($maxWidth - $currentLine.Length))) -ForegroundColor White

    Write-Host ("║" + "─" * ($cardWidth - 2) + "║") -ForegroundColor $borderColor

    Write-Host ("║") -NoNewline -ForegroundColor $borderColor
    Write-Host (" AFFECTS: {0}" -f $WhatChanges).PadRight($cardWidth - 2) -NoNewline -ForegroundColor Yellow
    Write-Host ("║") -ForegroundColor $borderColor

    Write-Host ("║" + "─" * ($cardWidth - 2) + "║") -ForegroundColor $borderColor

    Write-Host ("║") -NoNewline -ForegroundColor $borderColor
    $revColor = if ($Reversible -match '^YES') { 'Green' } elseif ($Reversible -match '^NO') { 'Red' } else { 'Yellow' }
    Write-Host (" REVERSIBLE: {0}" -f $Reversible).PadRight($cardWidth - 2) -NoNewline -ForegroundColor $revColor
    Write-Host ("║") -ForegroundColor $borderColor

    Write-Host ("║") -NoNewline -ForegroundColor $borderColor
    Write-Host (" RISK LEVEL: [{0}]" -f $RiskLevel.ToUpper()).PadRight($cardWidth - 2) -NoNewline -ForegroundColor $borderColor
    Write-Host ("║") -ForegroundColor $borderColor

    Write-Host ("═" * $cardWidth) -ForegroundColor $borderColor
}

function Get-UserConsent {
    param([string]$Layer)

    while ($true) {
        Write-Host ""
        Write-Host "  Proceed? " -NoNewline -ForegroundColor White
        Write-Host "[Y]es " -NoNewline -ForegroundColor Green
        Write-Host "[N]o " -NoNewline -ForegroundColor Yellow
        Write-Host "[A]ll " -NoNewline -ForegroundColor Magenta
        Write-Host "[D]ry-run " -NoNewline -ForegroundColor Cyan
        Write-Host "[Q]uit" -ForegroundColor White
        Write-Host "  Choice: " -NoNewline -ForegroundColor Gray

        $choice = Read-Host

        switch ($choice.ToUpper()) {
            'Y' { return 'APPLY' }
            'N' { return 'SKIP' }
            'A' {
                Write-Host ""
                Write-Host "  !! GOD MODE REQUEST !!" -ForegroundColor Red
                Write-Host "  Type GODMODE to confirm blanket approval: " -NoNewline -ForegroundColor White
                $confirm = Read-Host
                if ($confirm -eq 'GODMODE') {
                    return 'RUNALL'
                }
                Write-Host "  God Mode cancelled." -ForegroundColor Yellow
            }
            'D' { return 'DRYRUN' }
            'Q' { return 'EXIT' }
            default {
                Write-Host "  Invalid choice. Enter Y, N, A, D, or Q." -ForegroundColor Red
            }
        }
    }
}

# ============================================================================
# MODULE EXECUTION
# ============================================================================

function Invoke-ModulePreview {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata
    )

    Write-Host ""
    Show-DisclaimerCard `
        -TweakNumber $Metadata.Number `
        -Layer $Metadata.Layer `
        -TweakName $Metadata.Title `
        -Summary $Metadata.Summary `
        -WhatChanges $Metadata.WhatChanges `
        -Reversible $Metadata.Reversible `
        -RiskLevel $Metadata.RiskLevel

    if (Test-Path (Join-Path $ModulePath "preview.ps1")) {
        & (Join-Path $ModulePath "preview.ps1")
    } else {
        Write-Host "  Preview: $($Metadata.PreviewCommand)" -ForegroundColor DarkGray
    }
}

function Invoke-ModuleApply {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata,
        [bool]$DryRun
    )

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would apply: $($Metadata.Title)" -ForegroundColor Cyan
        return @{ Success = $true }
    }

    Write-Host "  Applying: $($Metadata.Title)..." -ForegroundColor Green

    # Check for protected service modifications
    if ($Metadata.ApplyCommands) {
        foreach ($cmd in $Metadata.ApplyCommands) {
            if ($cmd -match 'sc\s+(stop|disable|config)\s+(\w+)') {
                $svcName = $matches[2]
                if (Test-ProtectedService -ServiceName $svcName) {
                    Write-Log -Message "Refusing to modify protected service: $svcName" -Level ERROR
                    Write-Host "  [ERROR] Cannot modify protected service: $svcName" -ForegroundColor Red
                    return @{ Success = $false; Error = "Protected service" }
                }
            }
        }
    }

    try {
        if (Test-Path (Join-Path $ModulePath "apply.ps1")) {
            $result = & (Join-Path $ModulePath "apply.ps1")
            if ($LASTEXITCODE -ne 0) {
                throw "Apply script returned non-zero exit code"
            }
        } elseif ($Metadata.ApplyCommands) {
            foreach ($cmd in $Metadata.ApplyCommands) {
                Write-Log -Message "Executing: $cmd" -Level DEBUG
                # SEC-001: Validate and safely execute command without Invoke-Expression
                if ($cmd -match '\|') {
                    throw "Pipeline expressions are not permitted in module commands."
                }
                $cmdParts = $cmd -split '\s+', 2
                $executable = $cmdParts[0]
                $arguments = if ($cmdParts.Length -gt 1) { $cmdParts[1] } else { $null }
                # Validate executable is within module directory
                $resolvedPath = $null
                if (Test-Path $executable) {
                    $resolvedPath = (Resolve-Path $executable).Path
                    $moduleRoot = (Resolve-Path $ModulePath).Path
                    if (-not $resolvedPath.StartsWith($moduleRoot)) {
                        throw "Command executable must be within module directory: $executable"
                    }
                }
                if ($arguments) {
                    & $executable $arguments
                } else {
                    & $executable
                }
                if ($LASTEXITCODE -ne 0) {
                    throw "Command failed: $cmd"
                }
            }
        }

        Write-Log -Message "Module applied: $($Metadata.Id)" -Level INFO
        return @{ Success = $true }
    } catch {
        Write-Log -Message "Module apply failed: $($Metadata.Id) - $_" -Level ERROR
        Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Invoke-ModuleRollback {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata
    )

    Write-Host "  Rolling back: $($Metadata.Title)..." -ForegroundColor Yellow

    try {
        if (Test-Path (Join-Path $ModulePath "rollback.ps1")) {
            & (Join-Path $ModulePath "rollback.ps1")
        } elseif ($Metadata.RollbackCommands) {
            foreach ($cmd in $Metadata.RollbackCommands) {
                Write-Log -Message "Rollback: $cmd" -Level DEBUG
                # SEC-001: Validate and safely execute command without Invoke-Expression
                if ($cmd -match '\|') {
                    throw "Pipeline expressions are not permitted in module commands."
                }
                $cmdParts = $cmd -split '\s+', 2
                $executable = $cmdParts[0]
                $arguments = if ($cmdParts.Length -gt 1) { $cmdParts[1] } else { $null }
                # Validate executable is within module directory
                $resolvedPath = $null
                if (Test-Path $executable) {
                    $resolvedPath = (Resolve-Path $executable).Path
                    $moduleRoot = (Resolve-Path $ModulePath).Path
                    if (-not $resolvedPath.StartsWith($moduleRoot)) {
                        throw "Command executable must be within module directory: $executable"
                    }
                }
                if ($arguments) {
                    & $executable $arguments
                } else {
                    & $executable
                }
            }
        }

        Write-Log -Message "Module rolled back: $($Metadata.Id)" -Level INFO
        return @{ Success = $true }
    } catch {
        Write-Log -Message "Module rollback failed: $($Metadata.Id) - $_" -Level ERROR
        Write-Host "  [WARN] Rollback had issues: $($_.Exception.Message)" -ForegroundColor Yellow
        return @{ Success = $false; Error = $_.Exception.Message }
    }
}

function Invoke-ModuleVerify {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata
    )

    try {
        if (Test-Path (Join-Path $ModulePath "verify.ps1")) {
            & (Join-Path $ModulePath "verify.ps1")
            return $LASTEXITCODE -eq 0
        } elseif ($Metadata.Verify) {
            foreach ($check in $Metadata.Verify) {
                # SEC-001: Validate and safely execute verification command without Invoke-Expression
                if ($check -match '\|') {
                    throw "Pipeline expressions are not permitted in module commands."
                }
                $cmdParts = $check -split '\s+', 2
                $executable = $cmdParts[0]
                $arguments = if ($cmdParts.Length -gt 1) { $cmdParts[1] } else { $null }
                # Validate executable is within module directory
                $resolvedPath = $null
                if (Test-Path $executable) {
                    $resolvedPath = (Resolve-Path $executable).Path
                    $moduleRoot = (Resolve-Path $ModulePath).Path
                    if (-not $resolvedPath.StartsWith($moduleRoot)) {
                        throw "Command executable must be within module directory: $executable"
                    }
                }
                $result = if ($arguments) {
                    & $executable $arguments
                } else {
                    & $executable
                }
                if (-not $result) {
                    Write-Log -Message "Verification failed for: $check" -Level WARN
                    return $false
                }
            }
        }

        return $true
    } catch {
        Write-Log -Message "Module verify failed: $($Metadata.Id) - $_" -Level WARN
        return $false
    }
}

# ============================================================================
# LAYER EXECUTION
# ============================================================================

function Invoke-LayerPreview {
    param([string]$ManifestPath)

    $manifest = Import-Manifest -Path $ManifestPath
    Write-Log -Message "Previewing layer: $($manifest.name)" -Level INFO

    Write-Host ""
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ("║ {0} PREVIEW" -f $manifest.name.ToUpper()).PadRight(75) -ForegroundColor Cyan -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Description: $($manifest.description)" -ForegroundColor White
    # CODE-001: Extract inline if to variable for PS 5.1 compatibility
    $riskColor = if ($manifest.riskLevel -eq 'HIGH') { 'Red' } elseif ($manifest.riskLevel -eq 'MEDIUM') { 'Yellow' } else { 'Green' }
    Write-Host "  Risk Level:  $($manifest.riskLevel)" -ForegroundColor $riskColor
    Write-Host "  Modules:     $($manifest.modules.Count)" -ForegroundColor White
    Write-Host ""

    foreach ($moduleId in $manifest.modules) {
        $modulePath = Join-Path $Script:ModulesPath "$manifest.layer\$moduleId"
        $metadataPath = Join-Path $modulePath "metadata.yaml"

        if (Test-Path $metadataPath) {
            $metadata = Import-Manifest -Path $metadataPath
            $metadata['Number'] = $manifest.modules.IndexOf($moduleId) + 1
            $metadata['Layer'] = $manifest.layer

            Invoke-ModulePreview -ModulePath $modulePath -Metadata $metadata
        }
    }
}

function Invoke-LayerApply {
    param(
        [string]$ManifestPath,
        [bool]$DryRun = $false
    )

    $manifest = Import-Manifest -Path $ManifestPath
    Write-Log -Message "Applying layer: $($manifest.name)" -Level INFO

    if (-not $DryRun) {
        New-Directory -Path $Script:BackupPath
        New-Directory -Path $Script:LogPath
        New-Directory -Path $Script:StatePath
        New-Directory -Path $Script:RollbackPath

        New-SystemRestorePoint -Description "Before WinOptimizer - $($manifest.name) layer"
    }

    $results = @{
        Applied = 0
        Skipped = 0
        Failed = 0
        Errors = @()
    }

    $runAll = $false

    foreach ($moduleId in $manifest.modules) {
        $modulePath = Join-Path $Script:ModulesPath "$manifest.layer\$moduleId"
        $metadataPath = Join-Path $modulePath "metadata.yaml"

        if (-not (Test-Path $metadataPath)) {
            Write-Log -Message "Module metadata not found: $moduleId" -Level WARN
            continue
        }

        $metadata = Import-Manifest -Path $metadataPath
        $metadata['Number'] = $manifest.modules.IndexOf($moduleId) + 1
        $metadata['Layer'] = $manifest.layer

        # Show disclaimer
        Show-DisclaimerCard `
            -TweakNumber $metadata.Number `
            -Layer $metadata.Layer `
            -TweakName $metadata.Title `
            -Summary $metadata.Summary `
            -WhatChanges $metadata.WhatChanges `
            -Reversible $metadata.Reversible `
            -RiskLevel $metadata.RiskLevel

        if ($runAll) {
            $choice = 'APPLY'
        } else {
            $choice = Get-UserConsent -Layer $manifest.layer
        }

        if ($choice -eq 'EXIT') {
            Write-Host "`n  Exiting without applying remaining modules." -ForegroundColor Yellow
            break
        }

        if ($choice -eq 'SKIP') {
            $results.Skipped++
            continue
        }

        if ($choice -eq 'RUNALL') {
            $runAll = $true
        }

        $isDryRun = ($choice -eq 'DRYRUN') -or $DryRun
        $applyResult = Invoke-ModuleApply -ModulePath $modulePath -Metadata $metadata -DryRun $isDryRun

        if ($applyResult.Success) {
            $results.Applied++
            if (-not $isDryRun) {
                Set-ModuleState -Layer $manifest.layer -ModuleId $metadata.Id -Applied $true
            }
        } else {
            $results.Failed++
            $results.Errors += "$($metadata.Id): $($applyResult.Error)"
            Write-Host "  [ERROR] Module failed. Stopping layer application." -ForegroundColor Red
            break
        }

        Write-Host ""
    }

    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ("║ {0} SUMMARY" -f $manifest.name.ToUpper()).PadRight(75) -ForegroundColor Cyan -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host "  Applied:  $($results.Applied)" -ForegroundColor Green
    Write-Host "  Skipped:  $($results.Skipped)" -ForegroundColor Yellow
    Write-Host "  Failed:   $($results.Failed)" -ForegroundColor Red

    if ($results.Failed -gt 0) {
        Write-Host "`n  Errors:" -ForegroundColor Red
        foreach ($err in $results.Errors) {
            Write-Host "    - $err" -ForegroundColor Red
        }
    }

    return $results
}

function Invoke-LayerVerify {
    param([string]$ManifestPath)

    $manifest = Import-Manifest -Path $ManifestPath
    Write-Log -Message "Verifying layer: $($manifest.name)" -Level INFO

    $results = @{
        Passed = 0
        Failed = 0
    }

    foreach ($moduleId in $manifest.modules) {
        $modulePath = Join-Path $Script:ModulesPath "$manifest.layer\$moduleId"
        $metadataPath = Join-Path $modulePath "metadata.yaml"

        if (-not (Test-Path $metadataPath)) { continue }

        $metadata = Import-Manifest -Path $metadataPath

        if (Invoke-ModuleVerify -ModulePath $modulePath -Metadata $metadata) {
            $results.Passed++
            Write-Host "  [PASS] $($metadata.Title)" -ForegroundColor Green
        } else {
            $results.Failed++
            Write-Host "  [FAIL] $($metadata.Title)" -ForegroundColor Red
        }
    }

    Write-Host "`n  Verification Results:" -ForegroundColor Cyan
    Write-Host "    Passed: $($results.Passed)" -ForegroundColor Green
    # CODE-001: Fix PS5.1 syntax - extract conditional to variable
    $failedColor = if ($results.Failed -eq 0) { 'Green' } else { 'Red' }
    Write-Host "    Failed: $($results.Failed)" -ForegroundColor $failedColor

    return $results.Failed -eq 0
}

function Invoke-LayerRollback {
    param(
        [string]$ManifestPath,
        [bool]$AllLayers = $false
    )

    if ($AllLayers) {
        Write-Log -Message "Rolling back all layers" -Level INFO
        $stateFile = Join-Path $Script:StatePath "applied.json"

        if (-not (Test-Path $stateFile)) {
            Write-Host "  No layers have been applied." -ForegroundColor Yellow
            return
        }

        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        $appliedLayers = @($state.AppliedLayers)

        # Rollback in reverse order
        for ($i = $appliedLayers.Count - 1; $i -ge 0; $i--) {
            $layer = $appliedLayers[$i].ToLower()
            $manifestPath = Join-Path $Script:ManifestsPath "$layer.yaml"

            if (Test-Path $manifestPath) {
                Invoke-LayerRollback -ManifestPath $manifestPath -AllLayers $false
            }
        }

        # Clear state
        Remove-Item $stateFile -Force
        Write-Host "  All layers have been rolled back." -ForegroundColor Green
        return
    }

    $manifest = Import-Manifest -Path $ManifestPath
    Write-Log -Message "Rolling back layer: $($manifest.name)" -Level INFO

    Write-Host ""
    Write-Host ("═" * 76) -ForegroundColor Yellow
    Write-Host ("║ ROLLBACK: {0}" -f $manifest.name.ToUpper()).PadRight(75) -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Yellow
    Write-Host ("═" * 76) -ForegroundColor Yellow

    $results = @{
        Success = 0
        Failed = 0
    }

    # Rollback in reverse order
    $reversedModules = [System.Collections.Generic.List[string]]($manifest.modules)
    $reversedModules.Reverse()

    foreach ($moduleId in $reversedModules) {
        $modulePath = Join-Path $Script:ModulesPath "$manifest.layer\$moduleId"
        $metadataPath = Join-Path $modulePath "metadata.yaml"

        if (-not (Test-Path $metadataPath)) { continue }

        $metadata = Import-Manifest -Path $metadataPath

        $result = Invoke-ModuleRollback -ModulePath $modulePath -Metadata $metadata

        if ($result.Success) {
            $results.Success++
            Set-ModuleState -Layer $manifest.layer -ModuleId $metadata.Id -Applied $false
        } else {
            $results.Failed++
        }
    }

    Write-Host "  Rollback complete: $($results.Success) succeeded, $($results.Failed) failed" -ForegroundColor Cyan
}

# ============================================================================
# SNAPSHOT
# ============================================================================

function Invoke-Snapshot {
    Write-Log -Message "Creating baseline snapshot" -Level INFO

    New-Directory -Path $Script:BackupPath
    New-Directory -Path $Script:LogPath

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotDir = Join-Path $Script:BackupPath $timestamp
    New-Directory -Path $snapshotDir

    Write-Host "  Creating snapshot: $timestamp" -ForegroundColor Cyan

    # Export services
    Get-Service | Select-Object Name, DisplayName, Status, StartType |
        Export-Csv (Join-Path $snapshotDir "services.csv") -NoTypeInformation
    Write-Host "  - Services exported" -ForegroundColor Green

    # Export AppX packages
    Get-AppxPackage | Select-Object Name, PackageFullName, Version |
        Export-Csv (Join-Path $snapshotDir "appx.csv") -NoTypeInformation
    Write-Host "  - AppX packages exported" -ForegroundColor Green

    # Export scheduled tasks
    Get-ScheduledTask | Select-Object TaskName, TaskPath, State |
        Export-Csv (Join-Path $snapshotDir "tasks.csv") -NoTypeInformation
    Write-Host "  - Scheduled tasks exported" -ForegroundColor Green

    # Export firewall rules
    Get-NetFirewallRule | Select-Object Name, DisplayName, Direction, Action, Enabled |
        Export-Csv (Join-Path $snapshotDir "firewall.csv") -NoTypeInformation
    Write-Host "  - Firewall rules exported" -ForegroundColor Green

    Write-Host "  Snapshot complete: $snapshotDir" -ForegroundColor Green
}

# ============================================================================
# STATUS
# ============================================================================

function Show-Status {
    $stateFile = Join-Path $Script:StatePath "applied.json"

    Write-Host ""
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ("║ SYSTEM STATUS").PadRight(75) -ForegroundColor Cyan -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ""

    # WinOptimizer status
    Write-Host "  WinOptimizer Version: $Script:Version" -ForegroundColor White
    Write-Host ""

    # Applied layers
    if (Test-Path $stateFile) {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json

        Write-Host "  Applied Layers:" -ForegroundColor Cyan
        if ($state.AppliedLayers.Count -eq 0) {
            Write-Host "    None" -ForegroundColor DarkGray
        } else {
            foreach ($layer in $state.AppliedLayers) {
                $manifestPath = Join-Path $Script:ManifestsPath "$($layer.ToLower()).yaml"
                if (Test-Path $manifestPath) {
                    $manifest = Import-Manifest -Path $manifestPath
                    Write-Host "    - $($layer.ToUpper())" -NoNewline -ForegroundColor Green
                    Write-Host " ($($manifest.name))" -ForegroundColor DarkGray
                } else {
                    Write-Host "    - $($layer.ToUpper())" -ForegroundColor Green
                }
            }
        }
    } else {
        Write-Host "  No layers have been applied." -ForegroundColor DarkGray
    }

    Write-Host ""

    # Protected services check
    Write-Host "  Protected Services Status:" -ForegroundColor Cyan
    foreach ($svc in $Script:ProtectedServices) {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service) {
            $statusColor = if ($service.Status -eq 'Running') { 'Green' } else { 'Red' }
            Write-Host "    - $svc" -NoNewline -ForegroundColor White
            Write-Host " [$($service.Status)]" -ForegroundColor $statusColor
        } else {
            Write-Host "    - $svc" -NoNewline -ForegroundColor White
            Write-Host " [NOT FOUND]" -ForegroundColor Yellow
        }
    }

    Write-Host ""

    # System information
    Write-Host "  System Information:" -ForegroundColor Cyan
    Write-Host "    - OS Version: $((Get-CimInstance Win32_OperatingSystem).Caption)" -ForegroundColor White
    Write-Host "    - PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "    - Machine:   $env:COMPUTERNAME" -ForegroundColor White
}

# ============================================================================
# SYSTEM VERIFICATION
# ============================================================================

function Invoke-SystemVerification {
    Write-Host ""
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ("║ SYSTEM INTEGRITY VERIFICATION").PadRight(75) -ForegroundColor Cyan -NoNewline
    Write-Host "║" -ForegroundColor Cyan
    Write-Host ("═" * 76) -ForegroundColor Cyan
    Write-Host ""

    $allPassed = $true

    # Check protected services
    Write-Host "  Checking protected services..." -ForegroundColor Cyan
    foreach ($svc in $Script:ProtectedServices) {
        $service = Get-Service $svc -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') {
            Write-Host "    [PASS] $svc" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] $svc" -ForegroundColor Red
            $allPassed = $false
        }
    }

    Write-Host ""

    # Check Defender
    Write-Host "  Checking Windows Defender..." -ForegroundColor Cyan
    try {
        $defender = Get-MpComputerStatus
        if ($defender.RealTimeProtectionEnabled) {
            Write-Host "    [PASS] Real-time protection enabled" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] Real-time protection disabled" -ForegroundColor Red
            $allPassed = $false
        }
    } catch {
        Write-Host "    [FAIL] Could not check Defender status" -ForegroundColor Red
        $allPassed = $false
    }

    Write-Host ""

    # Check Windows Update service
    Write-Host "  Checking Windows Update..." -ForegroundColor Cyan
    $wu = Get-Service wuauserv -ErrorAction SilentlyContinue
    if ($wu -and $wu.Status -in @('Running', 'Stopped')) {
        Write-Host "    [PASS] Windows Update service accessible" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] Windows Update service not accessible" -ForegroundColor Red
        $allPassed = $false
    }

    Write-Host ""

    # Check networking
    Write-Host "  Checking network connectivity..." -ForegroundColor Cyan
    $testTargets = @(
        @{ Name = "www.microsoft.com"; Address = "www.microsoft.com" }
    )

    foreach ($target in $testTargets) {
        $result = Test-NetConnection -ComputerName $target.Address -InformationLevel Quiet -ErrorAction SilentlyContinue
        if ($result) {
            Write-Host "    [PASS] $($target.Name)" -ForegroundColor Green
        } else {
            Write-Host "    [FAIL] $($target.Name)" -ForegroundColor Red
            $allPassed = $false
        }
    }

    Write-Host ""

    # Check Explorer
    Write-Host "  Checking shell..." -ForegroundColor Cyan
    $explorer = Get-Process explorer -ErrorAction SilentlyContinue
    if ($explorer) {
        Write-Host "    [PASS] Explorer shell running" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] Explorer shell not running" -ForegroundColor Red
        $allPassed = $false
    }

    Write-Host ""
    Write-Host ("═" * 76) -ForegroundColor Cyan

    if ($allPassed) {
        Write-Host "  OVERALL RESULT: PASS" -ForegroundColor Green
        return 0
    } else {
        Write-Host "  OVERALL RESULT: FAIL" -ForegroundColor Red
        Write-Host "  Review the failures above. Consider rolling back recent changes." -ForegroundColor Yellow
        return 1
    }
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

try {
    Write-Host ""
    Write-Host "╔" + ("═" * 74) + "╗" -ForegroundColor Cyan
    Write-Host "║" + (" " * 74) + "║" -ForegroundColor Cyan
    Write-Host "║" + " WIN11 OPTIMIZER v$Script:Version".PadRight(74) + "║" -ForegroundColor Cyan
    Write-Host "║" + (" " * 74) + "║" -ForegroundColor Cyan
    Write-Host "╚" + ("═" * 74) + "╝" -ForegroundColor Cyan
    Write-Host ""

    switch ($PSCmdlet.ParameterSetName) {
        'Manifest' {
            if ($Preview) {
                Invoke-LayerPreview -ManifestPath $Manifest
            } elseif ($Apply) {
                Invoke-LayerApply -ManifestPath $Manifest -DryRun $false
            } elseif ($Verify) {
                $passed = Invoke-LayerVerify -ManifestPath $Manifest
                exit $(if ($passed) { 0 } else { 1 })
            } elseif ($Rollback) {
                Invoke-LayerRollback -ManifestPath $Manifest
            }
        }

        'RollbackAll' {
            Invoke-LayerRollback -ManifestPath $null -AllLayers $true
        }

        'Snapshot' {
            Invoke-Snapshot
        }

        'Status' {
            Show-Status
        }

        'VerifySystem' {
            exit Invoke-SystemVerification
        }

        'Default' {
            Write-Host "Usage: .\godmode.ps1 [options]" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Options:" -ForegroundColor White
            Write-Host "  --manifest <path>  Specify layer manifest file" -ForegroundColor Gray
            Write-Host "  --preview           Show what would change (dry-run)" -ForegroundColor Gray
            Write-Host "  --apply             Apply the optimizations" -ForegroundColor Gray
            Write-Host "  --verify            Verify changes were applied correctly" -ForegroundColor Gray
            Write-Host "  --rollback          Rollback the layer" -ForegroundColor Gray
            Write-Host "  --rollback-all      Rollback all applied layers" -ForegroundColor Gray
            Write-Host "  --snapshot          Create baseline system snapshot" -ForegroundColor Gray
            Write-Host "  --status            Show current system status" -ForegroundColor Gray
            Write-Host "  --verify-system     Run full system integrity verification" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Examples:" -ForegroundColor White
            Write-Host "  .\godmode.ps1 --manifest .\manifests\minimal.yaml --preview" -ForegroundColor Gray
            Write-Host "  .\godmode.ps1 --manifest .\manifests\minimal.yaml --apply" -ForegroundColor Gray
            Write-Host "  .\godmode.ps1 --rollback-all" -ForegroundColor Gray
            Write-Host ""
        }
    }
} catch {
    Write-Log -Message "Fatal error: $_" -Level ERROR
    Write-Host ""
    Write-Host "  [FATAL] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
exit 0