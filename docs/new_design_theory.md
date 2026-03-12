# Design Theory — Root Causes and Structural Recommendations

## Grounded Theory: Why This Repository Is Risky

1. **No state management architecture**: Modules write ad-hoc backups with timestamped directories but lack a canonical state file, causing rollback race conditions and cross-module interference (F2).
2. **Trust boundary violation**: Metadata YAML is parsed and fed into `Invoke-Expression`, creating a code injection path from configuration to execution (F3).
3. **Platform API misunderstanding**: `New-NetFirewallRule -RemoteAddress` silently ignores hostnames — the module appears to work but blocks nothing (F1).
4. **No CI gating on correctness**: The pipeline references nonexistent actions and has no Pester tests, so broken code merges without detection (F12, F9).
5. **PowerShell version mismatch**: Code uses PS7-only constructs (ternary, inline-if) while requiring PS5.1, causing parse-time crashes (F4).
6. **Missing separation between library and module**: `utils.ps1` uses `Export-ModuleMember` but is dot-sourced as a script, crashing on load (F7).
7. **Aspirational scope without foundation**: 90% of planned modules are stubs (F6), yet the framework lacks core infrastructure (logging, state, packaging) that the implemented 10% needs.
8. **Verification anti-patterns**: Verify scripts use inverted logic (F10), masking failures as successes, undermining the entire safety lifecycle.

## Recommended Long-Term Structural Changes

| Area | Recommendation |
|------|---------------|
| **State Management** | Implement `runtime/state.ps1` — every apply writes `<moduleId>.json`, every rollback reads it. No directory scanning. |
| **Module Schema** | Enforce a strict YAML schema with required fields (id, name, layer, description, reversible, risk_level, protected_components). Validate in CI. |
| **CI Gating** | Require Pester tests to pass, metadata to validate, and no exec bits before merge. Add VM integration gate for release branches. |
| **Script Signing** | Implement Authenticode + GPG signing in release pipeline on self-hosted runner with HSM access. |
| **Security Boundary** | Never execute content derived from YAML/JSON config. Use `& $path` with whitelist validation. |
| **Version Compatibility** | Target PS5.1 as minimum. Lint with PSScriptAnalyzer in CI. Avoid all PS7-only syntax. |
