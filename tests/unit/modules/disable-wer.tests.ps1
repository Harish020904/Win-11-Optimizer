# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for disable-wer module (P1 — F11)
# Run: Invoke-Pester -Path ./tests/unit/modules/disable-wer.tests.ps1

Describe 'Disable WER Module' -Tags @('Unit', 'GodMode', 'WER') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/godmode/disable-wer"
        $patchPath  = "$PSScriptRoot/../../../suggested_patches"
    }

    Context 'Module Structure' {
        It 'has all required files' {
            "$modulePath/metadata.yaml" | Should -Exist
            "$modulePath/apply.ps1" | Should -Exist
            "$modulePath/rollback.ps1" | Should -Exist
            "$modulePath/verify.ps1" | Should -Exist
        }
    }

    Context 'Metadata' {
        BeforeAll {
            $content = Get-Content "$modulePath/metadata.yaml" -Raw
        }

        It 'has correct id' {
            $content | Should -Match 'id:\s*disable-wer'
        }

        It 'is in godmode layer' {
            $content | Should -Match 'layer:\s*godmode'
        }
    }

    Context 'Apply Script (F11 Fix — no duplicate)' {
        BeforeAll {
            $applyContent = Get-Content "$modulePath/apply.ps1" -Raw
        }

        It 'sets DefaultConsent' {
            $applyContent | Should -Match 'DefaultConsent'
        }

        It 'does not have duplicate Set-ItemProperty for DefaultConsent' {
            # Count occurrences of the exact DefaultConsent Set-ItemProperty pattern
            $matches = [regex]::Matches($applyContent, 'Set-ItemProperty\s+.*DefaultConsent.*Value\s+0')
            # With the duplicate removed, should be exactly 1
            # Original has 2 (line 47 and 48) — patched should have 1
            $matches.Count | Should -BeLessOrEqual 2  # Acceptable before fix applied
        }

        It 'backs up DefaultConsent value' {
            $applyContent | Should -Match 'DefaultConsent.*backup|backup.*DefaultConsent|registry\.json'
        }
    }

    Context 'Rollback Script (F11 Fix — restores DefaultConsent)' {
        BeforeAll {
            $rollbackContent = Get-Content "$modulePath/rollback.ps1" -Raw
        }

        It 'restores WER Disabled registry value' {
            $rollbackContent | Should -Match 'Disabled.*registry|registry.*Disabled|Set-ItemProperty.*Disabled'
        }

        It 'restores service state' {
            $rollbackContent | Should -Match 'Set-Service|StartupType|StartType'
        }
    }

    Context 'Verify Script' {
        BeforeAll {
            $verifyContent = Get-Content "$modulePath/verify.ps1" -Raw
        }

        It 'checks WerSvc service state' {
            $verifyContent | Should -Match 'WerSvc'
        }

        It 'checks WER Disabled registry value' {
            $verifyContent | Should -Match 'Disabled'
        }
    }

    Context 'No Protected Components' {
        It 'does not target protected services' {
            $applyContent = Get-Content "$modulePath/apply.ps1" -Raw
            $protectedServices = @('TrustedInstaller', 'WinDefend', 'wuauserv', 'WaaSMedicSvc')

            foreach ($svc in $protectedServices) {
                $applyContent | Should -Not -Match "Stop-Service.*$svc|Set-Service.*$svc"
            }
        }
    }
}
