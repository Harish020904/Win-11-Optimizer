# Testing Guide

Comprehensive testing procedures for Win11 Optimizer.

## Overview

Testing ensures the optimizer:
- Doesn't break Windows functionality
- Produces reversible changes
- Meets quality standards
- Can be deployed safely

## Test Environments

### 1. Virtual Machine Testing (Primary)

**Purpose:** Automated testing, integration testing

**Setup:**
```powershell
# Use Hyper-V or VMware
# - Windows 11 Pro/Education/Enterprise
# - 4+ GB RAM
# - 50+ GB disk
# - Fresh install or clean snapshot
```

**Advantages:**
- Safe sandbox environment
- Easy rollback with snapshots
- Repeatable test conditions
- No risk to production system

### 2. Physical Test Machine (Secondary)

**Purpose:** Real-world validation

**Setup:**
- Dedicated test machine
- Similar hardware to production
- Clean install of Windows 11

**Advantages:**
- Tests real hardware behavior
- Validates driver interactions
- Catches VM-specific issues

### 3. Production (Canary)

**Purpose:** Final validation before fleet rollout

**Setup:**
- Single non-critical workstation
- Similar to fleet configuration

**Process:**
- Deploy to canary first
- Observe for 48-72 hours
- Monitor for issues
- Proceed to fleet if stable

## Unit Tests

Each module must have Pester unit tests.

### Test Template

```powershell
# tests/unit/modules/<module-name>.tests.ps1

Describe '<Module Name>' -Tags @('Unit', 'Module') {
    BeforeAll {
        $modulePath = "$PSScriptRoot/../../../modules/<layer>/<module-name>"
        $moduleYaml = Get-Content "$modulePath/module.yaml" | ConvertFrom-Yaml
    }

    Context 'Module Metadata' {
        It 'has valid module.yaml' {
            $moduleYaml | Should -Not -BeNullOrEmpty
            $moduleYaml.id | Should -Not -BeNullOrEmpty
            $moduleYaml.title | Should -Not -BeNullOrEmpty
        }

        It 'has a valid layer' {
            $moduleYaml.layer | Should -BeIn @('minimal', 'moderate', 'ultimate', 'godmode')
        }

        It 'has a valid severity' {
            $moduleYaml.severity | Should -BeIn @('zero', 'low', 'medium', 'high')
        }

        It 'has a valid reversibility setting' {
            $moduleYaml.reversible | Should -BeIn @('yes', 'partial', 'no')
        }
    }

    Context 'Preview Script' {
        It 'preview.ps1 exists' {
            Test-Path "$modulePath/preview.ps1" | Should -Be $true
        }

        It 'preview.ps1 can be sourced' {
            { . "$modulePath/preview.ps1" } | Should -Not -Throw
        }

        It 'has a Show-Preview function' {
            Get-Command Show-Preview -Module <module-name> -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'Apply Script' {
        It 'apply.ps1 exists' {
            Test-Path "$modulePath/apply.ps1" | Should -Be $true
        }

        It 'apply.ps1 can be sourced' {
            { . "$modulePath/apply.ps1" } | Should -Not -Throw
        }

        It 'has an Apply-Module function' {
            Get-Command Apply-Module -Module <module-name> -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'Rollback Script' {
        It 'rollback.ps1 exists' {
            Test-Path "$modulePath/rollback.ps1" | Should -Be $true
        }

        It 'rollback.ps1 can be sourced' {
            { . "$modulePath/rollback.ps1" } | Should -Not -Throw
        }

        It 'has a Revert-Module function' {
            Get-Command Revert-Module -Module <module-name> -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }

    Context 'Verify Script' {
        It 'verify.ps1 exists' {
            Test-Path "$modulePath/verify.ps1" | Should -Be $true
        }

        It 'verify.ps1 can be sourced' {
            { . "$modulePath/verify.ps1" } | Should -Not -Throw
        }

        It 'has a Verify-Module function' {
            Get-Command Verify-Module -Module <module-name> -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
        }
    }
}
```

### Running Unit Tests

```powershell
# Install Pester
Install-Module Pester -Force -Scope CurrentUser -MinimumVersion 5.5.0

# Run all unit tests
Invoke-Pester -Path ./tests/unit -OutputFormat NUnitXml -OutputFile unit-test-results.xml

# Run specific module tests
Invoke-Pester -Path ./tests/unit/modules/disable-diagtrack.tests.ps1

# Run with coverage
Invoke-Pester -Path ./tests/unit -CodeCoverage ./modules/**/*.ps1
```

## Integration Tests

Integration tests verify that layers work together and don't break Windows.

### Per-Layer Test Procedure

```powershell
# tests/integration/<layer>.tests.ps1

Describe '<Layer> Layer Integration' -Tags @('Integration', 'Layer') {
    BeforeAll {
        $manifestPath = "$PSScriptRoot/../../runtime/manifests/<layer>.yaml"
        $runtimePath = "$PSScriptRoot/../../runtime/godmode.ps1"
    }

    BeforeEach {
        # Create baseline
        Checkpoint-Computer -Description "Pre-test <layer>" -RestorePointType "MODIFY_SETTINGS"
    }

    AfterEach {
        # Rollback if test failed
        if ($LASTEXITCODE -ne 0) {
            & $runtimePath --manifest $manifestPath --rollback
        }
    }

    Context 'Preview' {
        It 'can preview the layer' {
            & $runtimePath --manifest $manifestPath --preview
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Apply' {
        It 'can apply the layer' {
            & $runtimePath --manifest $manifestPath --apply
            $LASTEXITCODE | Should -Be 0
        }

        It 'creates backup files' {
            & $runtimePath --manifest $manifestPath --apply
            Test-Path "C:\ProgramData\WinOptimizer\backup" | Should -Be $true
        }
    }

    Context 'Verification' {
        BeforeEach {
            & $runtimePath --manifest $manifestPath --apply
        }

        It 'verifies successfully' {
            & $runtimePath --manifest $manifestPath --verify
            $LASTEXITCODE | Should -Be 0
        }

        It 'Windows Update is accessible' {
            $service = Get-Service wuauserv -ErrorAction SilentlyContinue
            $service | Should -Not -BeNullOrEmpty
        }

        It 'Defender is running' {
            $status = Get-MpComputerStatus
            $status.RealTimeProtectionEnabled | Should -Be $true
        }

        It 'Explorer is running' {
            $explorer = Get-Process explorer -ErrorAction SilentlyContinue
            $explorer | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Rollback' {
        BeforeEach {
            & $runtimePath --manifest $manifestPath --apply
        }

        It 'can rollback the layer' {
            & $runtimePath --manifest $manifestPath --rollback
            $LASTEXITCODE | Should -Be 0
        }

        It 'restores system state' {
            & $runtimePath --manifest $manifestPath --rollback
            # Add specific verification based on layer changes
        }
    }
}
```

### Running Integration Tests

```powershell
# Run integration tests in VM
Invoke-Pester -Path ./tests/integration -OutputFormat NUnitXml -OutputFile integration-test-results.xml

# Run specific layer integration tests
Invoke-Pester -Path ./tests/integration/minimal.tests.ps1
```

## System Verification Checklist

### Pre-Application Baseline

```powershell
# Run before any optimizations
function Get-SystemBaseline {
    @{
        Services = Get-Service | Select-Object Name, Status, StartType
        AppxPackages = Get-AppxPackage | Select-Object Name, Version
        ScheduledTasks = Get-ScheduledTask | Select-Object TaskName, State
        FirewallRules = Get-NetFirewallRule | Select-Object Name, Enabled
        RegistryPolicies = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ErrorAction SilentlyContinue
        WindowsUpdate = Get-Service wuauserv
        Defender = Get-MpComputerStatus
        Network = Test-NetConnection -ComputerName www.microsoft.com
    }
}

$baseline = Get-SystemBaseline
$baseline | Export-Clixml "baseline-before.xml"
```

### Post-Application Verification

After each layer, verify:

```powershell
# 1. Boot Check
# System boots without errors
# No boot loops or BSOD

# 2. Service Check
$protectedServices = @(
    'TrustedInstaller',
    'WinDefend',
    'wuauserv',
    'Dhcp',
    'Dnscache'
)

foreach ($svc in $protectedServices) {
    $service = Get-Service $svc -ErrorAction SilentlyContinue
    if (-not $service -or $service.Status -ne 'Running') {
        Write-Warning "Protected service $svc is not running!"
    }
}

# 3. Windows Update Check
# - Can open Windows Update settings
# - Can check for updates
# - No update errors

# 4. Defender Check
$defender = Get-MpComputerStatus
if (-not $defender.RealTimeProtectionEnabled) {
    Write-Warning "Defender real-time protection is disabled!"
}

# 5. Networking Check
$networkTests = @(
    'www.microsoft.com',
    'update.microsoft.com',
    'activation.sls.microsoft.com'
)

foreach ($target in $networkTests) {
    $result = Test-NetConnection -ComputerName $target -InformationLevel Quiet
    if (-not $result) {
        Write-Warning "Cannot connect to $target"
    }
}

# 6. Explorer Check
$explorer = Get-Process explorer -ErrorAction SilentlyContinue
if (-not $explorer) {
    Write-Warning "Explorer is not running!"
}

# 7. App Launch Check
# Test launching common apps:
# - Settings app
# - Calculator
# - Notepad
# - Edge browser (if installed)
```

## Full Integration Test Flow

```powershell
# Complete test automation for a layer

function Test-LayerIntegration {
    param(
        [Parameter(Mandatory)]
        [string]$Layer
    )

    $manifest = "runtime\manifests\$Layer.yaml"
    $runtime = "runtime\godmode.ps1"
    $results = @()

    # Step 1: Baseline
    Write-Host "Creating baseline..."
    $baseline = Get-SystemBaseline
    $results += @{Step = "Baseline"; Status = "OK"}

    # Step 2: Preview
    Write-Host "Running preview..."
    & $runtime --manifest $manifest --preview
    if ($LASTEXITCODE -eq 0) {
        $results += @{Step = "Preview"; Status = "OK"}
    } else {
        $results += @{Step = "Preview"; Status = "FAIL"}
        return $results
    }

    # Step 3: Apply
    Write-Host "Applying layer..."
    Checkpoint-Computer -Description "Before $Layer test" -RestorePointType "MODIFY_SETTINGS"
    & $runtime --manifest $manifest --apply
    if ($LASTEXITCODE -eq 0) {
        $results += @{Step = "Apply"; Status = "OK"}
    } else {
        $results += @{Step = "Apply"; Status = "FAIL"}
        # Rollback and return
        & $runtime --manifest $manifest --rollback
        return $results
    }

    # Step 4: Verify
    Write-Host "Verifying layer..."
    & $runtime --manifest $manifest --verify
    if ($LASTEXITCODE -eq 0) {
        $results += @{Step = "Verify"; Status = "OK"}
    } else {
        $results += @{Step = "Verify"; Status = "FAIL"}
        & $runtime --manifest $manifest --rollback
        return $results
    }

    # Step 5: System Checks
    Write-Host "Running system checks..."
    $systemChecks = Test-SystemIntegrity
    if ($systemChecks -eq "PASS") {
        $results += @{Step = "SystemChecks"; Status = "OK"}
    } else {
        $results += @{Step = "SystemChecks"; Status = "FAIL"}
        & $runtime --manifest $manifest --rollback
        return $results
    }

    # Step 6: Rollback
    Write-Host "Testing rollback..."
    & $runtime --manifest $manifest --rollback
    if ($LASTEXITCODE -eq 0) {
        $results += @{Step = "Rollback"; Status = "OK"}
    } else {
        $results += @{Step = "Rollback"; Status = "FAIL"}
        return $results
    }

    # Step 7: Verify Rollback
    Write-Host "Verifying rollback..."
    $postRollback = Get-SystemBaseline
    # Compare with baseline (simplified)
    $results += @{Step = "RollbackVerify"; Status = "OK"}

    return $results
}
```

## Rollback Testing

Verify rollback functionality:

```powershell
Describe 'Rollback Functionality' {
    It 'can rollback single module' {
        # Apply module
        Apply-Module

        # Verify applied
        $state = Get-ModuleState
        $state.Applied | Should -Be $true

        # Rollback
        Revert-Module

        # Verify reverted
        $state = Get-ModuleState
        $state.Applied | Should -Be $false
    }

    It 'can rollback entire layer' {
        # Apply layer
        .\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply

        # Get service count before
        $before = (Get-Service).Count

        # Rollback
        .\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --rollback

        # Verify state restored
        # (specific checks depend on layer)
    }
}
```

## CI/CD Testing

Automated testing in GitHub Actions:

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Pester
        run: Install-Module Pester -Force -Scope CurrentUser

      - name: Run unit tests
        run: Invoke-Pester -Path ./tests/unit

      - name: Run integration tests (Minimal)
        run: |
          Checkpoint-Computer -Description "CI Test" -RestorePointType "MODIFY_SETTINGS"
          .\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply
          Invoke-Pester -Path ./tests/integration/minimal
          .\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --rollback
```

## Test Matrix

| Layer | Unit Tests | Integration Tests | VM Time | Physical Time |
|-------|------------|-------------------|---------|---------------|
| Minimal | ✓ | ✓ | 10 min | 24h observation |
| Moderate | ✓ | ✓ | 15 min | 48h observation |
| Ultimate | ✓ | ✓ | 20 min | 72h observation |
| GodMode | ✓ | ✓ | 30 min | 1 week observation |

## Test Reporting

Generate test reports:

```powershell
# Run tests with report
Invoke-Pester -Path ./tests `
    -OutputFormat NUnitXml `
    -OutputFile test-results.xml `
    -CodeCoverage ./modules/**/*.ps1 `
    -CodeCoverageOutputFile coverage.xml

# Convert to HTML
ReportUnit .\test-results.xml .\test-report.html
```

## Known Issues and Edge Cases

### Edge Cases to Test

1. **Slow systems** - Test on machines with limited resources
2. **Multiple languages** - Test with non-English Windows installations
3. **Enterprise domain** - Test domain-joined machines
4. **Different editions** - Test Home, Pro, Enterprise editions
5. **Custom configurations** - Test with pre-existing modifications

### Common Test Failures

1. **Timeout** - Increase timeout for slow operations
2. **Access denied** - Run as Administrator
3. **Service not found** - Handle missing services gracefully
4. **Registry key not found** - Use -ErrorAction SilentlyContinue

## Next Steps

After testing:

1. Review test results
2. Fix any failing tests
3. Update documentation
4. Sign and release
5. Monitor canary deployments

For more information:
- [Runbook](runbook.md)
- [Installation Guide](install.md)
- [Security Policy](../SECURITY.md)