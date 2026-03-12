# Unit Tests for disable-telemetry module

Describe 'disable-telemetry Module' -Tags @('Unit', 'Module', 'Minimal') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/minimal/disable-telemetry"
        $metadataPath = "$modulePath/metadata.yaml"
    }

    Context 'Module Metadata' {
        It 'has valid metadata.yaml' {
            $metadataPath | Should -Exist
            $content = Get-Content $metadataPath -Raw
            $content | Should -Not -BeNullOrEmpty
        }

        It 'has valid id field' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^id:\s*disable-telemetry' | Should -Be $true
        }

        It 'has valid layer' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^layer:\s*minimal' | Should -Be $true
        }

        It 'has valid severity' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^severity:\s*low' | Should -Be $true
        }

        It 'has valid reversibility' {
            $content = Get-Content $metadataPath -Raw
            $content -match '^reversible:\s*yes' | Should -Be $true
        }

        It 'has required fields' {
            $requiredFields = @('id', 'title', 'layer', 'severity', 'reversible', 'summary', 'whatChanges', 'riskLevel')
            $content = Get-Content $metadataPath -Raw

            foreach ($field in $requiredFields) {
                $content -match "^$field:" | Should -Be $true
            }
        }
    }

    Context 'Preview Script' {
        It 'preview.ps1 exists' {
            "$modulePath/preview.ps1" | Should -Exist
        }

        It 'preview.ps1 is not empty' {
            (Get-Content "$modulePath/preview.ps1" -Raw).Trim() | Should -Not -BeNullOrEmpty
        }

        It 'preview.ps1 contains Get-Service command' {
            $content = Get-Content "$modulePath/preview.ps1" -Raw
            $content -match 'Get-Service' | Should -Be $true
        }
    }

    Context 'Apply Script' {
        It 'apply.ps1 exists' {
            "$modulePath/apply.ps1" | Should -Exist
        }

        It 'apply.ps1 is not empty' {
            (Get-Content "$modulePath/apply.ps1" -Raw).Trim() | Should -Not -BeNullOrEmpty
        }

        It 'apply.ps1 contains Stop-Service command' {
            $content = Get-Content "$modulePath/apply.ps1" -Raw
            $content -match 'Stop-Service' | Should -Be $true
        }

        It 'apply.ps1 contains Set-Service command' {
            $content = Get-Content "$modulePath/apply.ps1" -Raw
            $content -match 'Set-Service' | Should -Be $true
        }
    }

    Context 'Rollback Script' {
        It 'rollback.ps1 exists' {
            "$modulePath/rollback.ps1" | Should -Exist
        }

        It 'rollback.ps1 is not empty' {
            (Get-Content "$modulePath/rollback.ps1" -Raw).Trim() | Should -Not -BeNullOrEmpty
        }

        It 'rollback.ps1 contains restore logic' {
            $content = Get-Content "$modulePath/rollback.ps1" -Raw
            $content -match 'Set-Service' | Should -Be $true
        }
    }

    Context 'Verify Script' {
        It 'verify.ps1 exists' {
            "$modulePath/verify.ps1" | Should -Exist
        }

        It 'verify.ps1 is not empty' {
            (Get-Content "$modulePath/verify.ps1" -Raw).Trim() | Should -Not -BeNullOrEmpty
        }

        It 'verify.ps1 contains exit statement' {
            $content = Get-Content "$modulePath/verify.ps1" -Raw
            $content -match 'exit' | Should -Be $true
        }
    }
}