# Unit Tests for disable-widgets module

Describe 'disable-widgets Module' -Tags @('Unit', 'Module', 'Minimal') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/minimal/disable-widgets"
        $metadataPath = "$modulePath/metadata.yaml"
    }

    Context 'Module Metadata' {
        It 'has valid metadata.yaml' {
            $metadataPath | Should -Exist
        }

        It 'has valid id field' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^id:\s*disable-widgets' | Should -Be $true
        }

        It 'has valid layer' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^layer:\s*minimal' | Should -Be $true
        }

        It 'has zero risk level' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^severity:\s*zero' | Should -Be $true
        }
    }

    Context 'Preview Script' {
        It 'preview.ps1 exists' {
            "$modulePath/preview.ps1" | Should -Exist
        }
    }

    Context 'Apply Script' {
        It 'apply.ps1 exists' {
            "$modulePath/apply.ps1" | Should -Exist
        }

        It 'apply.ps1 contains registry operations' {
            $content = Get-Content "$modulePath/apply.ps1" -Raw
            $content -match 'Set-ItemProperty' | Should -Be $true
        }
    }

    Context 'Rollback Script' {
        It 'rollback.ps1 exists' {
            "$modulePath/rollback.ps1" | Should -Exist
        }
    }

    Context 'Verify Script' {
        It 'verify.ps1 exists' {
            "$modulePath/verify.ps1" | Should -Exist
        }
    }
}