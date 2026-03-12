# Win11 Optimizer

A production-grade, auditable, reversible Windows 11 optimization framework that applies four escalating layers (Minimal → Moderate → Ultimate → GodMode) with preview, snapshot, verification, and rollback.

## Overview

**Win11 Optimizer** transforms a default Windows 11 installation into a minimal, efficient, and controlled environment while preserving full system functionality and stability.

### Core Principles

1. **Stability First** - Never break the Windows operating system
2. **Reversible Operations** - Every change can be undone
3. **Modular Architecture** - Each optimization is an independent module
4. **Transparent Execution** - Full visibility into what changes are made
5. **Production-Grade Reliability** - Tested, auditable, and enterprise-ready

### The Four Layers

| Layer | Goal | Risk | Reversible |
|-------|------|------|------------|
| **Minimal** | Reduce UI noise, telemetry, background activity | Low | Yes |
| **Moderate** | Optimize for developer/workstation use | Low-Medium | Mostly |
| **Ultimate** | Enterprise hardening, deeper optimization | Medium | Partially |
| **GodMode** | Minimal runtime (~60 services), Linux-like efficiency | High | Partially |

## Safety Guarantees

The optimizer will **never** modify these protected Windows components:

- Kernel: `ntoskrnl`, `hal.dll`, `win32k`
- Security Core: `LSASS`, `SAM`, `Credential Manager`, `Windows Defender Core`
- System Process Chain: `SMSS`, `CSRSS`, `Winlogon`, `Services.exe`
- Shell: `explorer.exe`, `StartMenuExperienceHost`, `ShellExperienceHost`
- Infrastructure: `RPC`, `WMI Core`, `Plug and Play`, `Task Scheduler`, `Event Log`
- Servicing: `TrustedInstaller`, `Windows Update Service`, `Windows Modules Installer`, `WinSxS`
- Drivers: `Windows Driver Framework`, `Kernel Driver Loader`, `Device Installation`
- Networking: `TCP/IP stack`, `DNS client`, `Network Location Awareness`, `DHCP Client`
- File System: `NTFS driver`, `Volume Shadow Copy`, `Storage Service`

## Quick Start

### Prerequisites

- Windows 11
- Administrator privileges
- PowerShell 5.1+ (built into Windows 11)

### Installation

```powershell
# Download and run (verify signature first)
Invoke-WebRequest -Uri "https://github.com/yourorg/win11-optimizer/releases/latest/download/install.ps1" -OutFile "install.ps1"

# Verify SHA256 (check against published checksums)
$hash = Get-FileHash -Algorithm SHA256 "install.ps1"
# Compare $hash.Hash with the published SHA256

# Run installer
powershell -ExecutionPolicy Bypass -File "install.ps1"
```

### Usage

```powershell
# Preview what Minimal layer would do (dry-run)
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --preview

# Apply Minimal layer
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply

# Verify system after applying
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --verify

# Rollback Minimal layer
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --rollback
```

## Documentation

- [Installation Guide](docs/install.md) - Detailed installation instructions
- [Runbook](docs/runbook.md) - Operations guide and troubleshooting
- [Testing Guide](docs/testing.md) - Testing and verification procedures
- [Security](SECURITY.md) - Security policy and vulnerability reporting
- [Contributing](CONTRIBUTING.md) - Contribution guidelines

## Architecture

### Execution Lifecycle

Every optimization layer follows this lifecycle:

```
preview → snapshot → apply → verify → observe → commit/rollback
```

### Module Structure

Each module contains:

```
module.yaml      - Module metadata (id, title, severity, reversible, dependencies)
preview.ps1      - Show what changes will be made
apply.ps1        - Apply the changes (idempotent)
rollback.ps1     - Revert the changes
verify.ps1       - Verify the changes were applied correctly
test.ps1         - Pester unit tests
```

### Snapshots & Rollback

- **Snapshots** are stored in `C:\ProgramData\WinOptimizer\backup\`
- **Rollback scripts** are auto-generated during apply
- **System Restore points** are created before each layer
- Each module produces tested rollback fragments

## Development

### Building from Source

This project uses a read/write-only build host. All execution, testing, and signing happens in Windows VMs or CI runners.

```bash
# On build host - create repository structure
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

# In Windows VM - run tests and packaging
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package-and-sign.ps1
```

### Running Tests

```powershell
# Install Pester
Install-Module -Name Pester -Force -Scope CurrentUser

# Run unit tests
Invoke-Pester -Path ./tests -OutputFormat NUnitXml -OutputFile test-results.xml
```

## Security

- All releases are signed with Authenticode
- SHA256 checksums are published for all artifacts
- Scripts verify signatures before execution
- See [SECURITY.md](SECURITY.md) for details

## License

MIT License - see [LICENSE](LICENSE) for details

## Disclaimer

This tool modifies system configuration. Always:
1. Create a system backup before using
2. Test in a VM first
3. Read all disclaimers before applying changes
4. Use rollback if issues occur

**Use at your own risk.**