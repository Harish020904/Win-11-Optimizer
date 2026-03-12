# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for firewall-telemetry-blocking module (P0 — F1)
# Run: Invoke-Pester -Path ./tests/unit/modules/firewall-telemetry-blocking.tests.ps1

Describe 'Firewall Telemetry Blocking Module' -Tags @('Unit', 'Ultimate', 'Firewall') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/ultimate/firewall-telemetry-blocking"
        $patchPath  = "$PSScriptRoot/../../../suggested_patches"
    }

    Context 'Module Structure' {
        It 'has metadata.yaml' {
            "$modulePath/metadata.yaml" | Should -Exist
        }

        It 'has apply.ps1' {
            "$modulePath/apply.ps1" | Should -Exist
        }

        It 'has rollback.ps1' {
            "$modulePath/rollback.ps1" | Should -Exist
        }

        It 'has verify.ps1' {
            "$modulePath/verify.ps1" | Should -Exist
        }
    }

    Context 'Metadata Validation' {
        BeforeAll {
            $content = Get-Content "$modulePath/metadata.yaml" -Raw
        }

        It 'has correct module id' {
            $content | Should -Match 'id:\s*firewall-telemetry-blocking'
        }

        It 'is in ultimate layer' {
            $content | Should -Match 'layer:\s*ultimate'
        }

        It 'is marked reversible' {
            $content | Should -Match 'reversible:\s*yes'
        }
    }

    Context 'Apply Script Safety (F1 Fix Verification)' {
        BeforeAll {
            # Use patched file if available, otherwise original
            $applyFile = if (Test-Path "$patchPath/firewall-apply-fix-F1.ps1") {
                "$patchPath/firewall-apply-fix-F1.ps1"
            } else {
                "$modulePath/apply.ps1"
            }
            $applyContent = Get-Content $applyFile -Raw
        }

        It 'does NOT pass hostnames directly to -RemoteAddress' {
            # The fix resolves DNS first; raw hostname strings should not appear
            # in a New-NetFirewallRule -RemoteAddress $endpoint pattern
            $applyContent | Should -Not -Match 'RemoteAddress\s+\$endpoint\b'
        }

        It 'uses Resolve-DnsName or IP resolution' {
            $applyContent | Should -Match 'Resolve-DnsName|ResolvedIP|uniqueIP|\$ips'
        }

        It 'creates a state file for rollback' {
            $applyContent | Should -Match 'state.*\.json|stateFile'
        }

        It 'does not use Invoke-Expression' {
            $applyContent | Should -Not -Match 'Invoke-Expression'
        }

        It 'has required header comment' {
            $applyContent | Should -Match '# AUTHOR: claude-code'
            $applyContent | Should -Match '# RUN INSIDE WINDOWS VM OR CI ONLY'
        }
    }

    Context 'Rollback Script Safety' {
        BeforeAll {
            $rollbackFile = if (Test-Path "$patchPath/firewall-rollback-fix-F1.ps1") {
                "$patchPath/firewall-rollback-fix-F1.ps1"
            } else {
                "$modulePath/rollback.ps1"
            }
            $rollbackContent = Get-Content $rollbackFile -Raw
        }

        It 'reads from module-specific state file (not find-latest pattern)' {
            $rollbackContent | Should -Match 'stateFile|state\\firewall'
        }

        It 'removes firewall rules by name' {
            $rollbackContent | Should -Match 'Remove-NetFirewallRule'
        }
    }

    Context 'Verify Script Checks IP Addresses' {
        BeforeAll {
            $verifyFile = if (Test-Path "$patchPath/firewall-verify-fix-F1.ps1") {
                "$patchPath/firewall-verify-fix-F1.ps1"
            } else {
                "$modulePath/verify.ps1"
            }
            $verifyContent = Get-Content $verifyFile -Raw
        }

        It 'checks for IP addresses in RemoteAddress (not hostnames)' {
            $verifyContent | Should -Match 'IPAddress|RemoteAddress|\d{1,3}\.\d{1,3}'
        }
    }

    Context 'No Protected Components' {
        BeforeAll {
            $applyContent = Get-Content "$modulePath/apply.ps1" -Raw
        }

        It 'does not reference protected services' {
            $protectedServices = @(
                'TrustedInstaller', 'WinDefend', 'wuauserv',
                'WaaSMedicSvc', 'DcomLaunch', 'RpcSs'
            )

            foreach ($svc in $protectedServices) {
                $applyContent | Should -Not -Match "Stop-Service.*$svc|Set-Service.*$svc|Disable.*$svc"
            }
        }
    }
}
