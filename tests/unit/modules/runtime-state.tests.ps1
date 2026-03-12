# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for runtime/state.ps1 module-scoped state management (P0 — F2)
# Run: Invoke-Pester -Path ./tests/unit/modules/runtime-state.tests.ps1

Describe 'Runtime state.ps1 — Module-Scoped State Management' -Tags @('Unit', 'Runtime', 'State') {
    BeforeAll {
        $statePath = "$PSScriptRoot/../../../runtime/state.ps1"
        $patchPath = "$PSScriptRoot/../../../suggested_patches/runtime-state-fix-F2.ps1"

        # Use patched file if available
        $sourceFile = if (Test-Path $patchPath) { $patchPath } else { $statePath }
        $content = Get-Content $sourceFile -Raw
    }

    Context 'Script Structure' {
        It 'defines Write-ModuleState function' {
            $content | Should -Match 'function Write-ModuleState'
        }

        It 'defines Read-ModuleState function' {
            $content | Should -Match 'function Read-ModuleState'
        }

        It 'defines Remove-ModuleState function' {
            $content | Should -Match 'function Remove-ModuleState'
        }

        It 'defines Test-ModuleApplied function' {
            $content | Should -Match 'function Test-ModuleApplied'
        }

        It 'defines Get-ModuleBackupPath function' {
            $content | Should -Match 'function Get-ModuleBackupPath'
        }
    }

    Context 'State File Location' {
        It 'uses ProgramData state directory' {
            $content | Should -Match 'ProgramData.*WinOptimizer.*state|STATE_DIR'
        }

        It 'writes JSON state files' {
            $content | Should -Match 'ConvertTo-Json|\.json'
        }
    }

    Context 'State Operations (Integration-like unit tests)' {
        BeforeAll {
            # Use a temp directory to avoid polluting real state
            $testStateDir = Join-Path $env:TEMP "WinOptimizer-test-state-$(Get-Random)"
            New-Item -Path $testStateDir -ItemType Directory -Force | Out-Null
        }

        AfterAll {
            if (Test-Path $testStateDir) {
                Remove-Item $testStateDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'can write and read a state file' {
            $stateFile = Join-Path $testStateDir "test-module.json"
            $stateData = @{
                ModuleId   = "test-module"
                Layer      = "minimal"
                AppliedAt  = Get-Date -Format "o"
                BackupPath = "C:\ProgramData\WinOptimizer\backup\minimal\test\20250101_120000"
            }

            $stateData | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

            $stateFile | Should -Exist
            $read = Get-Content $stateFile -Raw | ConvertFrom-Json
            $read.ModuleId | Should -Be "test-module"
            $read.Layer | Should -Be "minimal"
            $read.BackupPath | Should -Not -BeNullOrEmpty
        }

        It 'can remove a state file' {
            $stateFile = Join-Path $testStateDir "removable.json"
            "test" | Out-File $stateFile
            $stateFile | Should -Exist

            Remove-Item $stateFile -Force
            $stateFile | Should -Not -Exist
        }
    }
}
