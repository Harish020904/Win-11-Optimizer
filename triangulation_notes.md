# Triangulation Notes — JSON vs Markdown Report Cross-Validation

## Methodology

Cross-validated all findings in `review-report.json` (JSON) against `REVIEW_SUMMARY.md` (MD).
Flagged contradictions, missing evidence, and ambiguities.

---

## Contradictions Found

### 1. Priority Assignment for Invoke-Expression (F3)

**JSON**: Lists Invoke-Expression removal as `P1-002` (priority 1)
**MD**: Describes it as "Critical" severity, "high" risk with RCE potential
**User Rules**: Command injection = P0

**Resolution**: User's prioritization rules override both. Assigned P0.
**No VM test needed** — this is a classification disagreement, not a factual one.

### 2. File Path for Test Files

**JSON**: References `tests/unit/modules/disable-telemetry.tests.ps1`
**MD**: References `tests/unit/disable-telemetry.tests.ps1` (no `modules/` subdir)
**Actual repo**: Has `tests/unit/modules/` directory structure

**Resolution**: JSON path is correct. MD omits `modules/` subdirectory.
**VM test to verify**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
Test-Path tests/unit/modules/disable-telemetry.tests.ps1
```

### 3. Manifest Path

**JSON**: References manifests at `runtime/manifests/`
**MD**: References layers at `layers/` in some places
**Actual repo**: Uses `runtime/manifests/`

**Resolution**: JSON path is correct. MD uses informal naming.
**VM test to verify**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
Test-Path runtime/manifests/minimal.yaml
```

### 4. Finding Count Discrepancy

**JSON**: Lists ~28 individual items across modules, runtime, and CI sections
**MD**: Lists exactly 20 findings (F1-F20)

**Resolution**: JSON is more granular (e.g., separate entries for "backup accumulation" in disable-telemetry AND disable-widgets). MD groups related issues. The 20 MD findings cover all JSON items when accounting for grouping. No actual missing findings.

### 5. Severity Labels

**JSON**: Uses "critical", "high", "medium", "low"
**MD**: Uses "Critical", "High", "Medium" (capitalized, slightly different scale)

**Resolution**: Both use the same scale with different casing. No substantive conflict.

---

## Ambiguous Statements Requiring Investigation

### A1. "WaaSMedicSvc should be in protected list" (F20)

**JSON**: Mentions WaaSMedicSvc in documentation section
**MD**: F20 says "WaaSMedicSvc missing from protected services list"
**Question**: Is WaaSMedicSvc actually referenced anywhere in the codebase?

**VM test**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
Select-String -Path runtime/godmode.ps1 -Pattern 'WaaSMedicSvc'
Select-String -Path runtime/utils.ps1 -Pattern 'WaaSMedicSvc'
Get-Service WaaSMedicSvc | Select Status, StartType
```

### A2. "AllowTelemetry=0 only works on Enterprise" (F5)

**Claim**: Setting AllowTelemetry=0 has no effect on Pro/Home editions
**Verification needed**: Does the registry key still get set? Does it silently fail or is it clamped?

**VM test (requires Windows 11 Pro)**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
# Check current SKU
(Get-CimInstance Win32_OperatingSystem).OperatingSystemSKU
# Set to 0 and read back
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name AllowTelemetry -Value 0 -Type DWord
(Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection").AllowTelemetry
# Expected on Pro: value is set to 0 but effective level is clamped to 1
```

### A3. Firewall Hostname Resolution

**Claim (F1)**: `New-NetFirewallRule -RemoteAddress` silently ignores hostnames
**Verification**: Does it error out or does it create the rule with no match?

**VM test**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
New-NetFirewallRule -DisplayName "TestHostname" -Direction Outbound -RemoteAddress "example.com" -Action Block
Get-NetFirewallRule -DisplayName "TestHostname" | Get-NetFirewallAddressFilter
# Expect: RemoteAddress shows "example.com" as literal string (not IP) — no actual blocking
Remove-NetFirewallRule -DisplayName "TestHostname"
```

### A4. Checkpoint-Computer on Ephemeral VMs (F13)

**Claim**: `Checkpoint-Computer` fails on GitHub-hosted runners
**Verification**: Does it throw or silently skip?

**VM test**:
```
# RUN INSIDE WINDOWS VM OR CI ONLY
try {
    Enable-ComputerRestore -Drive 'C:\'
    Checkpoint-Computer -Description 'Test' -RestorePointType MODIFY_SETTINGS
    Write-Host 'SUCCESS: Restore point created'
} catch {
    Write-Host "EXPECTED FAILURE: $_"
}
```

---

## Priority for Resolving Contradictions

| # | Item | Must resolve before P1? | Reason |
|---|------|------------------------|--------|
| 1 | Invoke-Expression priority | No | Already resolved by user rules → P0 |
| 2 | Test file paths | No | Path verified correct in actual repo |
| 3 | Manifest paths | No | Path verified correct in actual repo |
| 4 | Finding count | No | Grouping difference, no missing items |
| 5 | Severity labels | No | Same scale, different casing |
| A1 | WaaSMedicSvc | **Yes** | Affects protected services list completeness |
| A2 | AllowTelemetry SKU | **Yes** | Affects whether F5 fix is necessary on target VMs |
| A3 | Firewall hostname | **Yes** | Confirms F1 is a real vulnerability (not theoretical) |
| A4 | Checkpoint-Computer | No | Low-priority CI improvement |

**Recommendation**: Run A1, A2, A3 VM tests before beginning P1 fixes to validate assumptions.
