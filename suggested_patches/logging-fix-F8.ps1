# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F8: Structured JSON logging per CLAUDE.md
# WHY: CLAUDE.md requires JSON logs with timestamp/layer/operation/result/rollbackRef.
#       Current Write-Log outputs plaintext.
# APPLY: Copy to runtime/logging.ps1 and dot-source from godmode.ps1.
#        Replace existing Write-Log function in godmode.ps1 with this version.

$Script:LogRoot = "C:\ProgramData\WinOptimizer\logs"

function Write-Log {
    <#
    .SYNOPSIS
        Structured JSON logger per CLAUDE.md specification.
    .DESCRIPTION
        Writes JSON log entries to C:\ProgramData\WinOptimizer\logs\optimizer-YYYYMMDD.log
        Each line is a standalone JSON object (JSONL format).
        Also writes to console with color-coded output.
    .PARAMETER Message
        The log message.
    .PARAMETER Level
        Log level: INFO, WARN, ERROR, DEBUG.
    .PARAMETER Operation
        The operation being performed (e.g., "apply", "rollback", "verify").
    .PARAMETER Layer
        The layer being processed (e.g., "minimal", "moderate").
    .PARAMETER RollbackRef
        Reference to rollback data (e.g., backup path or state file).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO',

        [string]$Operation = $null,
        [string]$Layer = $null,
        [string]$RollbackRef = $null
    )

    # Build structured log entry
    $logEntry = [ordered]@{
        timestamp   = Get-Date -Format "o"
        level       = $Level
        message     = $Message
    }

    # Add optional fields only if provided
    if ($Operation)   { $logEntry['operation']   = $Operation }
    if ($Layer)       { $logEntry['layer']       = $Layer }
    if ($RollbackRef) { $logEntry['rollbackRef'] = $RollbackRef }

    # Write JSON to log file
    $json = $logEntry | ConvertTo-Json -Compress
    $logFile = Join-Path $Script:LogRoot "optimizer-$(Get-Date -Format 'yyyyMMdd').log"

    try {
        if (-not (Test-Path $Script:LogRoot)) {
            New-Item -Path $Script:LogRoot -ItemType Directory -Force | Out-Null
        }
        $json | Out-File -FilePath $logFile -Append -Encoding UTF8
    } catch {
        # Silently fail if log directory cannot be created
    }

    # Console output with color
    $consoleColor = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'INFO'  { 'Cyan' }
        'DEBUG' { 'DarkGray' }
        default { 'White' }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $consoleColor
}
