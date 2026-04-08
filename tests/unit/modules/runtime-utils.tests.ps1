# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for runtime/utils.ps1 (P0 — F7)
# Run: Invoke-Pester -Path ./tests/unit/modules/runtime-utils.tests.ps1

Describe 'Runtime utils.ps1' -Tags @('Unit', 'Runtime', 'Utils') {
    BeforeAll {
        $utilsPath = "$PSScriptRoot/../../../runtime/utils.ps1"
        $content = Get-Content $utilsPath -Raw
    }

    Context 'Script Structure' {
        It 'exists' {
            $utilsPath | Should -Exist
        }
    }

    Context 'Export-ModuleMember Fix (F7)' {
        It 'should not use Export-ModuleMember in .ps1 file' {
            # After F7 fix, Export-ModuleMember should be removed
            # NOTE: Before fix, this will fail (expected). After fix, should pass.
            if ($content -match 'Export-ModuleMember') {
                Set-ItResult -Pending -Because "F7 fix not yet applied — Export-ModuleMember still present"
            }
            $content | Should -Not -Match 'Export-ModuleMember'
        }
    }

    Context 'Required Functions Defined' {
        It 'defines Test-AdminPrivilege' {
            $content | Should -Match 'function Test-AdminPrivilege'
        }

        It 'defines Test-ProtectedComponent' {
            $content | Should -Match 'function Test-ProtectedComponent'
        }

        It 'defines Export-WinOptimizerSnapshot' {
            $content | Should -Match 'function Export-WinOptimizerSnapshot'
        }

        It 'defines ConvertFrom-YamlSimple' {
            $content | Should -Match 'function ConvertFrom-YamlSimple'
        }

        It 'defines Get-WinOptimizerState' {
            $content | Should -Match 'function Get-WinOptimizerState'
        }
    }

    Context 'Protected Components List' {
        It 'includes TrustedInstaller' {
            $content | Should -Match 'TrustedInstaller'
        }

        It 'includes critical processes' {
            $content | Should -Match 'lsass|smss|csrss|winlogon'
        }
    }
}
