# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F2: Module-scoped state management helper
# WHY: Eliminates rollback race condition by writing per-module state files.
# APPLY: Copy to runtime/state.ps1 and dot-source from godmode.ps1
#
# Usage in apply.ps1:
#   . "$PSScriptRoot\..\..\runtime\state.ps1"
#   Write-ModuleState -ModuleId "disable-telemetry" -Layer "minimal" -BackupPath $backupDir
#
# Usage in rollback.ps1:
#   . "$PSScriptRoot\..\..\runtime\state.ps1"
#   $state = Read-ModuleState -ModuleId "disable-telemetry"
#   $backupDir = $state.BackupPath

$Script:StateRoot = "C:\ProgramData\WinOptimizer\state"

function Write-ModuleState {
    <#
    .SYNOPSIS
        Writes a module-scoped state file after successful apply.
    .PARAMETER ModuleId
        The module identifier (e.g., "disable-telemetry").
    .PARAMETER Layer
        The layer name (e.g., "minimal").
    .PARAMETER BackupPath
        Exact path to the backup directory created during apply.
    .PARAMETER ExtraData
        Optional hashtable of additional data to store.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleId,

        [Parameter(Mandatory)]
        [string]$Layer,

        [Parameter(Mandatory)]
        [string]$BackupPath,

        [hashtable]$ExtraData = @{}
    )

    if (-not (Test-Path $Script:StateRoot)) {
        New-Item -Path $Script:StateRoot -ItemType Directory -Force | Out-Null
    }

    $stateFile = Join-Path $Script:StateRoot "$ModuleId.json"

    $state = @{
        ModuleId   = $ModuleId
        Layer      = $Layer
        AppliedAt  = Get-Date -Format "o"
        BackupPath = $BackupPath
    }

    # Merge extra data
    foreach ($key in $ExtraData.Keys) {
        $state[$key] = $ExtraData[$key]
    }

    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $stateFile -Encoding UTF8
}

function Read-ModuleState {
    <#
    .SYNOPSIS
        Reads the module state file. Returns $null if not applied.
    .PARAMETER ModuleId
        The module identifier.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleId
    )

    $stateFile = Join-Path $Script:StateRoot "$ModuleId.json"

    if (-not (Test-Path $stateFile)) {
        return $null
    }

    return (Get-Content $stateFile -Raw | ConvertFrom-Json)
}

function Remove-ModuleState {
    <#
    .SYNOPSIS
        Removes the module state file after successful rollback.
    .PARAMETER ModuleId
        The module identifier.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleId
    )

    $stateFile = Join-Path $Script:StateRoot "$ModuleId.json"

    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force
    }
}

function Test-ModuleApplied {
    <#
    .SYNOPSIS
        Returns $true if the module has been applied (state file exists).
    .PARAMETER ModuleId
        The module identifier.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleId
    )

    $stateFile = Join-Path $Script:StateRoot "$ModuleId.json"
    return (Test-Path $stateFile)
}

function Get-ModuleBackupPath {
    <#
    .SYNOPSIS
        Returns the exact backup path from the module state file.
        Dies with error if module was never applied.
    .PARAMETER ModuleId
        The module identifier.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ModuleId
    )

    $state = Read-ModuleState -ModuleId $ModuleId

    if ($null -eq $state) {
        throw "Module '$ModuleId' has no state file. It was never applied or was already rolled back."
    }

    if (-not (Test-Path $state.BackupPath)) {
        throw "Backup path '$($state.BackupPath)' from state file does not exist."
    }

    return $state.BackupPath
}
