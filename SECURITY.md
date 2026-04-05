# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly.

### Do NOT

- Create a public issue
- Discuss in public forums
- Disclose without coordination

### DO

- Send an email to: security@CHANGEME.invalid
- Include detailed description and reproduction steps
- Allow us time to respond (typically within 48 hours)

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest  | ✓ Yes     |
| Previous | ✓ Security fixes only |
| Older   | ✗ No      |

## Security Features

### Code Signing

- All release artifacts are signed with Authenticode
- PowerShell scripts verify signatures before execution
- Detached GPG signatures provided for Linux verification

### Checksum Verification

- SHA256 checksums published for all artifacts
- Installers verify checksums before extraction

### Execution Safety

- Modules never modify protected Windows components
- State checks before applying changes
- Rollback capability for all changes
- System Restore points created before each layer

### Protected Components

The optimizer will NEVER modify:

- **Kernel**: `ntoskrnl`, `hal.dll`, `win32k`
- **Security**: `LSASS`, `SAM`, `Credential Manager`, `Windows Defender Core`
- **System Processes**: `SMSS`, `CSRSS`, `Winlogon`, `Services.exe`
- **Shell**: `explorer.exe`, `StartMenuExperienceHost`, `ShellExperienceHost`
- **Infrastructure**: `RPC`, `WMI Core`, `Plug and Play`, `Task Scheduler`, `Event Log`
- **Servicing**: `TrustedInstaller`, `Windows Update Service`, `Windows Modules Installer`, `WinSxS`
- **Drivers**: `Windows Driver Framework`, `Kernel Driver Loader`, `Device Installation`
- **Networking**: `TCP/IP stack`, `DNS client`, `Network Location Awareness`, `DHCP Client`
- **File System**: `NTFS driver`, `Volume Shadow Copy`, `Storage Service`

## Secure Installation

Always verify signatures before running:

```powershell
# Download and verify
Invoke-WebRequest -Uri "https://github.com/yourorg/win11-optimizer/releases/latest/download/install.ps1" -OutFile "install.ps1"

# Verify SHA256
$hash = Get-FileHash -Algorithm SHA256 "install.ps1"
# Compare with published checksum

# Verify Authenticode signature
Get-AuthenticodeSignature "install.ps1" | Select-Object Status
```

## Signing Keys

- **Code Signing Certificate**: Stored in HSM/secure signing VM
- **GPG Key**: Available on public key servers
  - Key ID: `CHANGEME`
  - Fingerprint: `CHANGEME`

## Dependency Security

- Minimal dependencies (PowerShell 5.1+ only)
- No third-party executables
- All scripts are open source and auditable

## Incident Response

In case of a security incident:

1. Immediate assessment and containment
2. Notify security@yourorg.com
3. Coordinate disclosure timeline
4. Issue security advisory
5. Release fix in next version

## Acknowledgments

We thank all security researchers who help keep Win11 Optimizer safe.

---

**For immediate security concerns, email: security@CHANGEME.invalid**