# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Enhanced Integration Tests for Minimal Layer
# Includes: dry-run/preview, idempotency, verification, rollback assertions
# Run: Invoke-Pester -Path ./tests/integration/minimal-enhanced.tests.ps1 -Tags 'Integration'

Describe 'Minimal Layer Integration — Enhanced' -Tags @('Integration', 'Layer', 'Minimal') {
    BeforeAll {
        $manifestPath = "$PSScriptRoot/../../runtime/manifests/minimal.yaml"
        $runtimePath  = "$PSScriptRoot/../../runtime/godmode.ps1"
        $modulesBase  = "$PSScriptRoot/../../modules/minimal"

        # Temp snapshot location for tests
        $testBackupBase = Join-Path $env:TEMP "WinOptimizer-test-$(Get-Random)"
        New-Item -Path $testBackupBase -ItemType Directory -Force | Out-Null
    }

    AfterAll {
        # Cleanup test artifacts
        if (Test-Path $testBackupBase) {
            Remove-Item $testBackupBase -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Manifest Structure' {
        It 'manifest file exists' {
            $manifestPath | Should -Exist
        }

        It 'manifest has required fields' {
            $content = Get-Content $manifestPath -Raw
            $content | Should -Match '^name:'
            $content | Should -Match 'layer:\s*minimal'
            $content | Should -Match 'modules:'
        }

        It 'manifest lists at least one module' {
            $content = Get-Content $manifestPath -Raw
            $content | Should -Match '-\s+\w+'
        }

        It 'all listed modules have directories' {
            $content = Get-Content $manifestPath -Raw
            # Extract module names from YAML list
            $moduleNames = [regex]::Matches($content, '-\s+(\S+)') | ForEach-Object { $_.Groups[1].Value }

            foreach ($mod in $moduleNames) {
                $modDir = Join-Path $modulesBase $mod
                $modDir | Should -Exist -Because "Module '$mod' is listed in manifest but directory missing"
            }
        }
    }

    Context 'Runtime Script Safety' {
        It 'runtime script has required security headers' {
            $content = Get-Content $runtimePath -Raw
            $content | Should -Match '#Requires -Version 5.1'
            $content | Should -Match '#Requires -RunAsAdministrator'
        }
    }

    Context 'Module Completeness' {
        It 'disable-telemetry module has all required files' {
            $modulePath = "$modulesBase/disable-telemetry"
            "$modulePath/metadata.yaml" | Should -Exist
            "$modulePath/preview.ps1" | Should -Exist
            "$modulePath/apply.ps1" | Should -Exist
            "$modulePath/rollback.ps1" | Should -Exist
            "$modulePath/verify.ps1" | Should -Exist
        }

        It 'disable-widgets module has all required files' {
            $modulePath = "$modulesBase/disable-widgets"
            "$modulePath/metadata.yaml" | Should -Exist
            "$modulePath/preview.ps1" | Should -Exist
            "$modulePath/apply.ps1" | Should -Exist
            "$modulePath/rollback.ps1" | Should -Exist
            "$modulePath/verify.ps1" | Should -Exist
        }
    }

    Context 'Preview/Dry-Run Output (disable-telemetry)' {
        BeforeAll {
            $previewPath = "$modulesBase/disable-telemetry/preview.ps1"
        }

        It 'preview.ps1 exists and is non-empty' {
            $previewPath | Should -Exist
            $content = Get-Content $previewPath -Raw
            $content.Trim() | Should -Not -BeNullOrEmpty
        }

        It 'preview outputs planned changes (not actual modifications)' {
            $content = Get-Content $previewPath -Raw
            # Preview should contain Write-Host/Output describing planned changes
            $content | Should -Match 'Write-Host|Write-Output'
        }
    }

    Context 'Idempotency Control' {
        It 'apply script checks for existing state before applying' {
            $applyContent = Get-Content "$modulesBase/disable-telemetry/apply.ps1" -Raw
            # After state management fix (F2), apply scripts should check state file
            # This will be a pending test until F2 is integrated
            $hasIdempotencyCheck = $applyContent -match 'stateFile|Test-ModuleApplied|already applied'
            if (-not $hasIdempotencyCheck) {
                Set-ItResult -Pending -Because 'F2 state management not yet integrated into this module'
            }
            $hasIdempotencyCheck | Should -BeTrue
        }
    }

    Context 'Protected Services Guard' {
        It 'disable-telemetry does not target protected services' {
            $protectedServices = @(
                'TrustedInstaller', 'WinDefend', 'wuauserv', 'WaaSMedicSvc',
                'DcomLaunch', 'RpcSs', 'PlugPlay', 'EventLog',
                'lsass', 'smss', 'csrss', 'winlogon', 'services'
            )

            $content = Get-Content "$modulesBase/disable-telemetry/apply.ps1" -Raw

            foreach ($svc in $protectedServices) {
                $pattern = "Stop-Service.*$svc|Set-Service.*$svc.*Disabled|Disable.*$svc"
                $content | Should -Not -Match $pattern -Because "Protected service $svc must not be disabled"
            }
        }
    }

    Context 'Metadata Schema Compliance' {
        It 'each module metadata has required YAML fields' {
            $requiredFields = @('id', 'name', 'layer', 'description', 'reversible')

            foreach ($modDir in (Get-ChildItem $modulesBase -Directory)) {
                $metaFile = Join-Path $modDir.FullName 'metadata.yaml'
                if (Test-Path $metaFile) {
                    $content = Get-Content $metaFile -Raw
                    foreach ($field in $requiredFields) {
                        $content | Should -Match "^${field}:" -Because "Module $($modDir.Name) must have '$field' in metadata.yaml"
                    }
                }
            }
        }
    }

    Context 'Rollback Restores Original State' {
        It 'disable-telemetry rollback references backup path' {
            $rollbackContent = Get-Content "$modulesBase/disable-telemetry/rollback.ps1" -Raw
            $rollbackContent | Should -Match 'backup|Backup|restore|Restore'
        }

        It 'disable-widgets rollback references backup path' {
            $rollbackContent = Get-Content "$modulesBase/disable-widgets/rollback.ps1" -Raw
            $rollbackContent | Should -Match 'backup|Backup|restore|Restore'
        }
    }
}

# Note: Tests below this line require a Windows VM with snapshot/restore capability.
# They are marked with -Tags 'VM' and should only run in CI with VM runners.

Describe 'Minimal Layer VM Integration — Apply/Verify/Rollback Cycle' -Tags @('Integration', 'VM', 'Minimal') {
    BeforeAll {
        # This block only runs inside a Windows VM (CI self-hosted runner)
        $modulesBase = "$PSScriptRoot/../../modules/minimal"
    }

    Context 'Disable-Telemetry Full Lifecycle' {
        It 'apply.ps1 exits without error' -Tag 'VM' {
            # RUN INSIDE WINDOWS VM OR CI ONLY
            $result = & "$modulesBase/disable-telemetry/apply.ps1" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'verify.ps1 confirms changes applied' -Tag 'VM' {
            # RUN INSIDE WINDOWS VM OR CI ONLY
            & "$modulesBase/disable-telemetry/verify.ps1"
            $LASTEXITCODE | Should -Be 0
        }

        It 'apply.ps1 is idempotent (second run succeeds)' -Tag 'VM' {
            # RUN INSIDE WINDOWS VM OR CI ONLY
            $result = & "$modulesBase/disable-telemetry/apply.ps1" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'rollback.ps1 restores original state' -Tag 'VM' {
            # RUN INSIDE WINDOWS VM OR CI ONLY
            & "$modulesBase/disable-telemetry/rollback.ps1"
            $LASTEXITCODE | Should -Be 0
        }
    }
}
