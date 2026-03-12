# Contributing to Win11 Optimizer

Thank you for your interest in contributing to Win11 Optimizer!

## Build Host Policy

**Important:** This project uses a read/write-only build host (Arch Linux). The build environment:

- Has **only read & write permissions** for files and folders
- Has **no execution permission** for any file
- Serves as a source-artifact generator only

All execution, testing, packaging, and signing must occur in:
- Windows 11 Virtual Machine
- CI runner (GitHub Actions Windows runner or self-hosted)

### File Permissions

On the build host:
```bash
# Set non-executable permissions (no execution on build host)
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;
```

Execution bits are set only in the VM or CI when needed.

## Code of Conduct

- Be respectful and constructive
- Focus on what is best for the community
- Show empathy towards other community members

## Development Workflow

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes (files only, no execution)
4. Commit with clear messages
5. Push to your fork
6. Open a Pull Request

### Branch Protection

- `main` branch requires:
  - 2 reviewers approval
  - All CI checks must pass
  - No force pushes

## Module Guidelines

### Module Structure

Each module must contain:

```
module.yaml      - Metadata (id, title, layer, severity, reversible, dependencies)
preview.ps1      - Preview changes (no modification)
apply.ps1        - Apply changes (idempotent, state checks first)
rollback.ps1     - Revert changes (inverse of apply)
verify.ps1       - Verify changes (exit 0 on success)
test.ps1         - Pester unit tests
```

### Module Rules

1. **Never modify protected components** (see CLAUDE.md)
2. **Be idempotent** - safe to re-run
3. **Be reversible** when possible
4. **State the reversibility level**: `yes`, `partial`, or `no`
5. **Include clear disclaimers** (100-word plain English summary)
6. **Add verification checks** to validate changes

### Module Schema

```yaml
id: disable-diagtrack
title: "Disable Diagnostic Telemetry"
layer: minimal
severity: low
reversible: yes
dependencies: []
preview_cmd: 'sc query DiagTrack'
apply_cmds:
  - 'sc stop DiagTrack'
  - 'sc config DiagTrack start=disabled'
rollback_cmds:
  - 'sc config DiagTrack start=auto'
  - 'sc start DiagTrack'
verify:
  - '(Get-Service DiagTrack).Status -eq "Stopped"'
```

### Approval for Irreversible Modules

Modules with `reversible: partial` or `reversible: no` require:
- Extra documentation in the module's disclaimer
- 3 reviewers approval (instead of 2)
- Explicit warning in the PR description

## Testing

### Unit Tests

All modules must have Pester tests:

```powershell
# test.ps1 example
Describe 'Disable DiagTrack' {
    It 'should have a valid module.yaml' {
        $module = Get-Content .\module.yaml | ConvertFrom-Yaml
        $module.id | Should -Be 'disable-diagtrack'
    }

    It 'preview should run without errors' {
        { .\preview.ps1 } | Should -Not -Throw
    }
}
```

### Integration Tests

Run integration tests in Windows VM:

```powershell
# 1. Apply layer
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply

# 2. Run verification
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --verify

# 3. Rollback
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --rollback

# 4. Verify rollback
Get-Service TrustedInstaller | Should -Be 'Running'
```

## Documentation

- Update relevant documentation when adding features
- Include examples for new modules
- Document any breaking changes
- Update CHANGELOG.md for user-visible changes

## Commit Messages

Use conventional commits:

```
feat: add disable-diagtrack module
fix: correct rollback for windows-search
docs: update installation guide
test: add integration tests for minimal layer
```

## Pull Request Process

1. Ensure your PR description clearly describes the changes
2. Link related issues
3. Include tests for new functionality
4. Update documentation
5. Ensure CI passes
6. Request reviews from maintainers

## Release Process

Releases are automated via GitHub Actions:

1. Create release branch: `release/vX.Y.Z`
2. Update version in all manifests
3. Update CHANGELOG.md
4. Merge to `main`
5. CI automatically builds, tests, signs, and publishes

## Questions?

- Open an issue for questions
- Check existing documentation
- Join discussions in issues

Thank you for contributing!