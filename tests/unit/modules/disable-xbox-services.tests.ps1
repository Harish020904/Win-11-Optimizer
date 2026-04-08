# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for disable-xbox-services module (P1 — F10)
# Run: Invoke-Pester -Path ./tests/unit/modules/disable-xbox-services.tests.ps1

Describe 'Disable Xbox Services Module' -Tags @('Unit', 'Moderate', 'Xbox') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/moderate/disable-xbox-services"
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
            $content | Should -Match 'id:\s*disable-xbox-services'
        }

        It 'is in moderate layer' {
            $content | Should -Match 'layer:\s*moderate'
        }
    }

    Context 'Apply Sets Services to Manual (not Disabled)' {
        BeforeAll {
            $applyContent = Get-Content "$modulePath/apply.ps1" -Raw
        }

        It 'sets startup type to Manual' {
            $applyContent | Should -Match 'StartupType\s+Manual'
        }

        It 'does not set startup type to Disabled' {
            $applyContent | Should -Not -Match 'StartupType\s+Disabled'
        }

        It 'creates backup of service states' {
            $applyContent | Should -Match 'services\.json|serviceStates|ConvertTo-Json'
        }
    }

    Context 'Verify Logic Correctness (F10 Fix)' {
        BeforeAll {
            $verifyContent = Get-Content "$modulePath/verify.ps1" -Raw
        }

        It 'checks service StartType against expected states' {
            $verifyContent | Should -Match 'StartType'
        }

        It 'checks service Status' {
            $verifyContent | Should -Match 'Status.*Running|Running.*Status'
        }
    }

    Context 'No Protected Components' {
        It 'only targets Xbox services' {
            $applyContent = Get-Content "$modulePath/apply.ps1" -Raw
            $applyContent | Should -Match 'Xbox|Xbl'
            $applyContent | Should -Not -Match 'TrustedInstaller|WinDefend|wuauserv|WaaSMedicSvc'
        }
    }
}
