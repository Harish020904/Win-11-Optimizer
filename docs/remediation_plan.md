# Remediation Plan — Win-11-Debloat Security Audit

## Executive Summary

Security audit identified **20 findings** across modules, runtime, and CI.
**6 are P0** (critical: RCE, silent failures, runtime crashes), **8 are P1**, **6 are P2**.
This plan provides exact patches, tests, and CI changes for full remediation.

---

## P0 — Critical (Must fix before any release)

| ID | Title | File(s) | Effort | Patch |
|----|-------|---------|--------|-------|
| F1 | Firewall rules use hostnames (silent fail) | `modules/ultimate/firewall-telemetry-blocking/apply.ps1` | 4h | `suggested_patches/firewall-apply-fix-F1.ps1` |
| F2 | Rollback race condition (wrong backup) | All rollback.ps1 + new `runtime/state.ps1` | 6h | `suggested_patches/runtime-state-fix-F2.ps1` |
| F3 | Invoke-Expression allows command injection | `runtime/godmode.ps1` lines 484, 514, 539 | 3h | `suggested_patches/godmode-fix-F3-F4.ps1` |
| F4 | PS5.1 syntax errors crash runtime | `runtime/godmode.ps1` lines 571, 725 | 2h | `suggested_patches/godmode-fix-F3-F4.ps1` |
| F7 | Export-ModuleMember in .ps1 crashes on load | `runtime/utils.ps1` line 407 | 1h | `suggested_patches/utils-fix-F7.ps1` |
| F9 | Missing packaging script breaks release | `scripts/package.ps1` (nonexistent) | 3h | `suggested_patches/scripts-package-fix-F9.ps1` |

**Total P0 effort: ~19 hours**

### Acceptance Criteria — P0

**F1 (Firewall):**
- Firewall rules reference IP addresses, NOT hostnames
- `Get-NetFirewallRule | Get-NetFirewallAddressFilter` shows IPs in RemoteAddress
- `Test-NetConnection -ComputerName www.microsoft.com -Port 443` still works (Store not blocked)
- State file exists at `C:\ProgramData\WinOptimizer\state\firewall-telemetry-blocking.json`

**F2 (Rollback):**
- Each apply creates `C:\ProgramData\WinOptimizer\state\<moduleId>.json`
- Rollback reads exact backup path from state file
- No `Sort-Object | Select-Object -First 1` pattern in rollback scripts
- Concurrent module applies don't interfere with each other's rollback

**F3 (Invoke-Expression):**
- Zero occurrences of `Invoke-Expression` in godmode.ps1
- Module scripts invoked via `& $scriptPath` with path validation
- Malicious metadata.yaml with `; rm -rf /` in command field does NOT execute

**F4 (Syntax):**
- `pwsh -File runtime/godmode.ps1 -Layer minimal -DryRun` runs without parse errors
- `powershell -Version 5.1 -File runtime/godmode.ps1` runs without parse errors
- No `(if (...))` in parameter positions; no `-if` parameter names

**F7 (Export-ModuleMember):**
- `Export-ModuleMember` removed from utils.ps1
- `. .\runtime\utils.ps1` succeeds without error
- All functions remain accessible after dot-sourcing

**F9 (Packaging):**
- `scripts/package.ps1` exists and creates a .zip archive
- `release.yml` pipeline references a valid script
- Package includes version.json and SHA256 checksum

---

## P1 — High (Fix in next sprint)

| ID | Title | File(s) | Effort |
|----|-------|---------|--------|
| F5 | AllowTelemetry=0 fails on non-Enterprise | `modules/minimal/disable-telemetry/apply.ps1` | 2h |
| F8 | Plaintext logging, not JSON | `runtime/godmode.ps1` Write-Log | 3h |
| F10 | Xbox verify logic inverted | `modules/moderate/disable-xbox-services/verify.ps1` | 1h |
| F11 | disable-wer incomplete rollback | `modules/godmode/disable-wer/rollback.ps1` | 2h |
| F12 | CI references nonexistent action | `.github/workflows/ci.yml` line 22 | 1h |
| F14 | GPG signing step unreachable | `.github/workflows/release.yml` line 51 | 1h |
| F16 | Metadata schema inconsistent | All `metadata.yaml` files | 2h |

**Total P1 effort: ~12 hours**

---

## P2 — Medium (Backlog)

| ID | Title | Effort |
|----|-------|--------|
| F6 | 90% modules unimplemented | 40h+ |
| F13 | Checkpoint-Computer on ephemeral VM | 1h |
| F15 | Deprecated upload-artifact@v3 | 0.5h |
| F17 | No script annotations | 4h |
| F18 | No pre-commit hooks | 2h |
| F19 | Idempotency weaknesses | 4h |
| F20 | WaaSMedicSvc missing from protected list | 0.5h |

**Total P2 effort: ~52 hours**

---

## Owner Suggestions

| Area | Suggested Owner |
|------|----------------|
| P0 Patches (F1-F4, F7, F9) | Senior engineer with PowerShell + Windows internals |
| P1 Module Fixes (F5, F10, F11) | Module maintainer |
| CI Pipeline (F12, F14, F15) | DevOps / CI engineer |
| Testing (all Pester tests) | QA engineer or module maintainer |
| Documentation (F16, F17) | Any contributor |

---

## Verification Commands

All commands below must be run inside a Windows VM or CI runner:

```
# RUN INSIDE WINDOWS VM OR CI ONLY
# Run all unit tests
Invoke-Pester -Path ./tests/unit/ -Output Detailed

# Run integration tests (structural only)
Invoke-Pester -Path ./tests/integration/ -ExcludeTag VM -Output Detailed

# Run VM integration tests (requires admin + VM snapshot)
Invoke-Pester -Path ./tests/integration/ -Tag VM -Output Detailed

# Verify firewall fix
Get-NetFirewallRule -DisplayName "WinOptimizer*" | Get-NetFirewallAddressFilter | Select RemoteAddress
```
