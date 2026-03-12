# Integration Tests for Minimal Layer

Describe 'Minimal Layer Integration' -Tags @('Integration', 'Layer', 'Minimal') {
    BeforeAll {
        $manifestPath = "$PSScriptRoot/../../runtime/manifests/minimal.yaml"
        $runtimePath = "$PSScriptRoot/../../runtime/godmode.ps1"
    }

    Context 'Manifest' {
        It 'manifest file exists' {
            $manifestPath | Should -Exist
        }

        It 'manifest has required fields' {
            $content = Get-Content $manifestPath -Raw
            $content -match '^name:' | Should -Be $true
            $content -match '^layer:\s*minimal' | Should -Be $true
            $content -match '^modules:' | Should -Be $true
        }

        It 'manifest lists at least one module' {
            $content = Get-Content $manifestPath -Raw
            $content -match '-\s+\w+' | Should -Be $true
        }
    }

    Context 'Runtime Script' {
        It 'runtime script exists' {
            $runtimePath | Should -Exist
        }

        It 'runtime script has #Requires statements' {
            $content = Get-Content $runtimePath -Raw
            $content -match '#Requires -Version' | Should -Be $true
            $content -match '#Requires -RunAsAdministrator' | Should -Be $true
        }
    }

    Context 'Module Files' {
        It 'disable-telemetry module has all required files' {
            $modulePath = "$PSScriptRoot/../../modules/minimal/disable-telemetry"
            "$modulePath/metadata.yaml" | Should -Exist
            "$modulePath/preview.ps1" | Should -Exist
            "$modulePath/apply.ps1" | Should -Exist
            "$modulePath/rollback.ps1" | Should -Exist
            "$modulePath/verify.ps1" | Should -Exist
        }

        It 'disable-widgets module has all required files' {
            $modulePath = "$PSScriptRoot/../../modules/minimal/disable-widgets"
            "$modulePath/metadata.yaml" | Should -Exist
            "$modulePath/preview.ps1" | Should -Exist
            "$modulePath/apply.ps1" | Should -Exist
            "$modulePath/rollback.ps1" | Should -Exist
            "$modulePath/verify.ps1" | Should -Exist
        }
    }

    Context 'Protected Services' {
        It 'module does not target protected services' {
            $protectedServices = @(
                'TrustedInstaller',
                'WinDefend',
                'wuauserv',
                'DcomLaunch',
                'RpcSs',
                'PlugPlay',
                'EventLog'
            )

            $modulePath = "$PSScriptRoot/../../modules/minimal/disable-telemetry/apply.ps1"
            $content = Get-Content $modulePath -Raw

            foreach ($svc in $protectedServices) {
                $content -match [regex]::Escape($svc) | Should -Be $false
            }
        }
    }
}

# Note: Actual integration tests that apply changes should only run in VMs.
# These structural tests verify that all components exist and are properly formed.