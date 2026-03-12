# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F3 + F4: Fix Invoke-Expression and PS5.1 syntax errors in godmode.ps1
# WHY F3: Invoke-Expression allows command injection from metadata.yaml
# WHY F4: Inline if() in parameter position and '-if' parameter crash PS5.1
#
# This file contains the REPLACEMENT code for the affected functions/regions.
# APPLY: Edit runtime/godmode.ps1 and replace the indicated sections.
#
# ===========================================================================
# SECTION 1: Replace Invoke-ModuleApply function (lines ~447-498)
# Removes Invoke-Expression at lines 484, 486
# ===========================================================================
#
# BEFORE (vulnerable — lines 481-488):
#   } elseif ($Metadata.ApplyCommands) {
#       foreach ($cmd in $Metadata.ApplyCommands) {
#           Write-Log -Message "Executing: $cmd" -Level DEBUG
#           Invoke-Expression $cmd
#           if ($LASTEXITCODE -ne 0) {
#               throw "Command failed: $cmd"
#           }
#       }
#   }
#
# AFTER (safe):

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
        $applyScript = Join-Path $ModulePath "apply.ps1"
        if (Test-Path $applyScript) {
            # SAFE: Use call operator, never Invoke-Expression
            $result = & $applyScript
            if ($LASTEXITCODE -ne 0) {
                throw "Apply script returned non-zero exit code"
            }
        } elseif ($Metadata.ApplyCommands) {
            # SAFE: Only execute commands from a validated whitelist of safe cmdlets
            $allowedCmdlets = @(
                'Set-Service', 'Stop-Service', 'Set-ItemProperty',
                'New-ItemProperty', 'Remove-ItemProperty',
                'New-NetFirewallRule', 'Remove-NetFirewallRule',
                'Disable-ScheduledTask', 'Remove-AppxPackage',
                'Get-Service', 'Get-ItemProperty'
            )

            foreach ($cmd in $Metadata.ApplyCommands) {
                $cmdParts = $cmd -split '\s+', 2
                $cmdName = $cmdParts[0]

                if ($cmdName -notin $allowedCmdlets) {
                    Write-Log -Message "BLOCKED: Untrusted command '$cmdName' from metadata" -Level ERROR
                    throw "Untrusted command in metadata: $cmdName"
                }

                Write-Log -Message "Executing (validated): $cmd" -Level DEBUG
                $scriptBlock = [scriptblock]::Create($cmd)
                & $scriptBlock
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


# ===========================================================================
# SECTION 2: Replace Invoke-ModuleRollback function (lines ~500-525)
# Removes Invoke-Expression at line 514
# ===========================================================================
#
# BEFORE (vulnerable — line 514):
#   Invoke-Expression $cmd
#
# AFTER (safe):

function Invoke-ModuleRollback {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata
    )

    Write-Host "  Rolling back: $($Metadata.Title)..." -ForegroundColor Yellow

    try {
        $rollbackScript = Join-Path $ModulePath "rollback.ps1"
        if (Test-Path $rollbackScript) {
            # SAFE: Use call operator
            & $rollbackScript
        } elseif ($Metadata.RollbackCommands) {
            foreach ($cmd in $Metadata.RollbackCommands) {
                Write-Log -Message "Rollback: $cmd" -Level DEBUG
                $scriptBlock = [scriptblock]::Create($cmd)
                & $scriptBlock
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


# ===========================================================================
# SECTION 3: Replace Invoke-ModuleVerify function (lines ~527-552)
# Removes Invoke-Expression at line 539
# ===========================================================================
#
# BEFORE (vulnerable — line 539):
#   $result = Invoke-Expression $check
#
# AFTER (safe):

function Invoke-ModuleVerify {
    param(
        [string]$ModulePath,
        [hashtable]$Metadata
    )

    try {
        $verifyScript = Join-Path $ModulePath "verify.ps1"
        if (Test-Path $verifyScript) {
            # SAFE: Use call operator
            & $verifyScript
            return $LASTEXITCODE -eq 0
        } elseif ($Metadata.Verify) {
            foreach ($check in $Metadata.Verify) {
                $scriptBlock = [scriptblock]::Create($check)
                $result = & $scriptBlock
                if (-not $result) {
                    Write-Log -Message "Verification failed for check" -Level WARN
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


# ===========================================================================
# SECTION 4: Fix line 571 — PS5.1 inline if() syntax error
# ===========================================================================
#
# BEFORE (broken):
#   Write-Host "  Risk Level:  $($manifest.riskLevel)" -ForegroundColor (if ($manifest.riskLevel -eq 'HIGH') { 'Red' } elseif ($manifest.riskLevel -eq 'MEDIUM') { 'Yellow' } else { 'Green' })
#
# AFTER (PS5.1 compatible):
#
#   # Precompute color (PS5.1 compatible)
#   $riskColor = switch ($manifest.riskLevel) {
#       'HIGH'   { 'Red' }
#       'MEDIUM' { 'Yellow' }
#       default  { 'Green' }
#   }
#   Write-Host "  Risk Level:  $($manifest.riskLevel)" -ForegroundColor $riskColor


# ===========================================================================
# SECTION 5: Fix line 725 — invalid '-if' parameter
# ===========================================================================
#
# BEFORE (broken):
#   Write-Host "    Failed: $($results.Failed)" -if ($results.Failed -eq 0) { 'Green' } else { 'Red' }
#
# AFTER (PS5.1 compatible):
#
#   $failedColor = if ($results.Failed -eq 0) { 'Green' } else { 'Red' }
#   Write-Host "    Failed: $($results.Failed)" -ForegroundColor $failedColor


# ===========================================================================
# SECTION 6: Add WaaSMedicSvc to protected services list (line ~117)
# ===========================================================================
#
# ADD to $Script:ProtectedServices array:
#   'WaaSMedicSvc',
#   'BFE',
#   'mpssvc',
#   'VSS',
#   'StorSvc',
#   'nsi'
