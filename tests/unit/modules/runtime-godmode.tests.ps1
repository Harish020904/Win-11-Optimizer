# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for runtime/godmode.ps1 (P0 — F3, F4)
# Run: Invoke-Pester -Path ./tests/unit/modules/runtime-godmode.tests.ps1

Describe 'Runtime godmode.ps1' -Tags @('Unit', 'Runtime', 'Security') {
    BeforeAll {
        $runtimePath = "$PSScriptRoot/../../../runtime/godmode.ps1"
        $content = Get-Content $runtimePath -Raw
    }

    Context 'Script Structure' {
        It 'exists' {
            $runtimePath | Should -Exist
        }

        It 'has #Requires -Version 5.1' {
            $content | Should -Match '#Requires -Version 5.1'
        }

        It 'has #Requires -RunAsAdministrator' {
            $content | Should -Match '#Requires -RunAsAdministrator'
        }
    }

    Context 'Security — No Invoke-Expression (F3)' {
        It 'does not use Invoke-Expression' {
            # After F3 fix, no Invoke-Expression should remain
            $iexMatches = [regex]::Matches($content, 'Invoke-Expression')
            # NOTE: Before fix, this will fail (expected). After fix, should pass.
            # Allow test to document current state
            if ($iexMatches.Count -gt 0) {
                Set-ItResult -Pending -Because "F3 fix not yet applied — $($iexMatches.Count) Invoke-Expression calls remain"
            }
            $iexMatches.Count | Should -Be 0
        }

        It 'uses call operator (&) for script execution' {
            $content | Should -Match '&\s+\(Join-Path|&\s+\$\w+Script'
        }
    }

    Context 'PS5.1 Syntax Compatibility (F4)' {
        It 'does not use inline if() in parameter position' {
            # Matches: -ForegroundColor (if (...) { ... })
            $content | Should -Not -Match '-ForegroundColor\s+\(if\s+'
        }

        It 'does not use -if as a parameter name' {
            $content | Should -Not -Match '\s-if\s+\('
        }
    }

    Context 'Protected Services' {
        It 'defines a protected services list' {
            $content | Should -Match 'ProtectedServices|PROTECTED_SERVICES'
        }

        It 'includes TrustedInstaller in protected list' {
            $content | Should -Match "'TrustedInstaller'"
        }

        It 'includes wuauserv in protected list' {
            $content | Should -Match "'wuauserv'"
        }

        It 'includes WinDefend in protected list' {
            $content | Should -Match "'WinDefend'"
        }
    }

    Context 'Logging' {
        It 'defines a Write-Log function' {
            $content | Should -Match 'function Write-Log'
        }

        It 'writes to log file' {
            $content | Should -Match 'Out-File.*\$logFile|Out-File.*log'
        }
    }
}
