# Win11 Optimizer Runbook

Operations guide for using Win11 Optimizer safely and effectively.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Layer-by-Layer Guide](#layer-by-layer-guide)
3. [Common Operations](#common-operations)
4. [Troubleshooting](#troubleshooting)
5. [Emergency Recovery](#emergency-recovery)
6. [Best Practices](#best-practices)

## Quick Start

```powershell
# Navigate to installation directory
cd C:\Win11Optimizer

# Run as Administrator
.\runtime\godmode.ps1

# Or use CLI directly
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --preview
```

## Layer-by-Layer Guide

### Layer 1: Minimal

**Risk Level:** Low
**Reversible:** Yes
**Estimated Time:** 5-10 minutes

**What it does:**
- Disables telemetry personalization
- Removes Windows tips and suggestions
- Disables Spotlight content
- Disables Widgets
- Reduces background Edge processes
- Disables Delivery Optimization
- Stops Activity History

**Pre-requisites:**
- None

**Steps:**

```powershell
# 1. Preview what will change
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --preview

# 2. Review each disclaimer card
# Each tweak will show:
# - Plain English summary
# - What changes
# - Reversibility status
# - Risk level

# 3. Apply (review each prompt carefully)
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply

# 4. Verify changes
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --verify

# 5. Observe for 24-48 hours
# Monitor for:
# - UI issues
# - Performance problems
# - Unexpected behavior
```

**Verification Checklist:**
- [ ] Windows boots normally
- [ ] Start menu works
- [ ] Search functions
- [ ] Windows Update accessible
- [ ] Defender is running

### Layer 2: Moderate

**Risk Level:** Low to Medium
**Reversible:** Mostly
**Estimated Time:** 10-15 minutes

**What it does:**
- Disables Xbox services
- Removes unnecessary scheduled tasks
- Removes consumer AppX packages
- Tunes Defender exclusions
- Optional OneDrive removal
- SysMain (Superfetch) evaluation

**Pre-requisites:**
- Minimal layer completed
- System stable for 24-48 hours after Minimal

**Steps:**

```powershell
# 1. Preview
.\runtime\godmode.ps1 --manifest runtime\manifests\moderate.yaml --preview

# 2. Create System Restore point
Checkpoint-Computer -Description "Before Moderate layer" -RestorePointType "MODIFY_SETTINGS"

# 3. Apply
.\runtime\godmode.ps1 --manifest runtime\manifests\moderate.yaml --apply

# 4. Verify
.\runtime\godmode.ps1 --manifest runtime\manifests\moderate.yaml --verify
```

**Verification Checklist:**
- [ ] All Minimal checks pass
- [ ] OneDrive (if kept) syncs properly
- [ ] Installed games launch correctly
- [ ] No service errors in Event Viewer

### Layer 3: Ultimate

**Risk Level:** Medium
**Reversible:** Partially
**Estimated Time:** 15-20 minutes

**What it does:**
- Policy-based telemetry restriction
- Firewall telemetry endpoint blocking
- Advanced service lockdown
- Full AppX provisioning cleanup
- OEM software removal

**Pre-requisites:**
- Moderate layer completed
- System stable for 24-48 hours after Moderate
- Full system backup created

**Steps:**

```powershell
# 1. PRE-BACKUP CRITICAL
# Create full system image backup before proceeding

# 2. Preview
.\runtime\godmode.ps1 --manifest runtime\manifests\ultimate.yaml --preview

# 3. Create System Restore point
Checkpoint-Computer -Description "Before Ultimate layer" -RestorePointType "MODIFY_SETTINGS"

# 4. Apply
.\runtime\godmode.ps1 --manifest runtime\manifests\ultimate.yaml --apply

# 5. Verify
.\runtime\godmode.ps1 --manifest runtime\manifests\ultimate.yaml --verify
```

**Verification Checklist:**
- [ ] All Moderate checks pass
- [ ] Microsoft Store opens (if expected)
- [ ] Office activation works
- [ ] Network connectivity to Microsoft services
- [ ] No activation warnings

### Layer 4: GodMode

**Risk Level:** High
**Reversible:** Partially
**Estimated Time:** 20-30 minutes

**What it does:**
- Disables background UWP infrastructure
- Disables consumer frameworks
- Disables unused services
- Disables system synchronization services
- Removes gaming ecosystem
- Disables error reporting
- Target: ~60 active services

**Pre-requisites:**
- Ultimate layer completed
- System stable for 48-72 hours after Ultimate
- Full system backup created
- Recovery media prepared

**Steps:**

```powershell
# 1. FINAL WARNING
# This layer significantly reduces system services
# Some features may never work the same way again
# Have recovery media ready

# 2. Preview
.\runtime\godmode.ps1 --manifest runtime\manifests\godmode.yaml --preview

# 3. Create System Restore point
Checkpoint-Computer -Description "Before GodMode" -RestorePointType "MODIFY_SETTINGS"

# 4. Apply
.\runtime\godmode.ps1 --manifest runtime\manifests\godmode.yaml --apply

# 5. Verify
.\runtime\godmode.ps1 --manifest runtime\manifests\godmode.yaml --verify
```

**Verification Checklist:**
- [ ] All Ultimate checks pass
- [ ] System boots
- [ ] Windows Update works
- [ ] Defender is active
- [ ] Explorer shell works
- [ ] Basic apps function

## Common Operations

### Create Baseline Snapshot

```powershell
.\runtime\godmode.ps1 --snapshot
```

This captures:
- All services
- AppX packages
- Scheduled tasks
- Firewall rules
- Registry keys
- System configuration

### View Applied Layers

```powershell
.\runtime\godmode.ps1 --status
```

### Rollback a Layer

```powershell
# Rollback specific layer
.\runtime\godmode.ps1 --rollback --layer minimal

# Rollback all layers (reverse order)
.\runtime\godmode.ps1 --rollback-all
```

### Verify System Integrity

```powershell
.\runtime\godmode.ps1 --verify-system
```

## Troubleshooting

### Issue: Windows Won't Boot After Applying Layer

**Solution:**

1. Boot into Safe Mode
2. Run rollback script:
   ```powershell
   # From WinRE
   cd C:\Win11Optimizer\rollback
   powershell -ExecutionPolicy Bypass -File rollback_<layer>.ps1
   ```
3. Reboot normally

### Issue: Windows Update Fails

**Solution:**

```powershell
# Check Windows Update service
Get-Service wuauserv

# Reset Windows Update components
# (use Microsoft's official reset script)

# If persists, rollback last layer
.\runtime\godmode.ps1 --rollback --layer <last-applied>
```

### Issue: Defender Shows Errors

**Solution:**

```powershell
# Verify Defender is running
Get-MpComputerStatus

# If not running, check service
Get-Service WinDefend

# Reset Defender settings via Security app
# Or rollback if issue appeared after applying layer
```

### Issue: Certain Apps Won't Launch

**Solution:**

```powershell
# Check if AppX package was removed
Get-AppxPackage | Where-Object {$_.Name -like "*appname*"}

# Check event logs for errors
Get-EventLog -LogName Application -Newest 50

# Consider rolling back if critical apps are affected
```

## Emergency Recovery

### Priority 1: System Restore Point

```powershell
# List available restore points
Get-ComputerRestorePoint

# Restore to specific point
Restore-Computer -RestorePoint <point-id>
```

### Priority 2: Rollback Scripts

```powershell
# Rollback from last layer backwards
.\runtime\godmode.ps1 --rollback-all
```

### Priority 3: Full Image Restore

Use your system image backup (created before Ultimate/GodMode layers):

```powershell
# From WinRE
# Navigate to: Troubleshoot → Advanced Options → System Image Recovery
```

### Priority 4: In-Place Repair Install

1. Download Windows 11 ISO
2. Mount and run `setup.exe`
3. Select "Keep personal files and apps"
4. Complete the repair install

## Best Practices

### Before Applying Each Layer

1. **Review disclaimers** - Read each tweak's disclaimer card
2. **Create restore point** - Always have a rollback path
3. **Backup important data** - Don't rely solely on rollback
4. **Test in VM first** - If possible, test on a virtual machine
5. **Document custom settings** - Note any custom configurations

### During Application

1. **Go slow** - Don't use GODMODE blanket approval for first run
2. **Read prompts** - Understand what each tweak does
3. **Verify after each tweak** - Check system behavior
4. **Stop if issues** - Don't continue if something seems wrong

### After Applying Each Layer

1. **Observe for 24-48 hours** - Watch for subtle issues
2. **Run verification** - `.\runtime\godmode.ps1 --verify`
3. **Check Event Logs** - Look for errors or warnings
4. **Test critical functionality** - Update, Defender, networking
5. **Create new baseline** - After stable period

### Long-term Maintenance

1. **Keep rollback scripts** - Store externally for recovery
2. **Document what was applied** - Track which layers were used
3. **Test after Windows updates** - Verify optimizer didn't interfere
4. **Review new versions** - Check for updates before applying

## CLI Reference

```powershell
# Full usage
.\runtime\godmode.ps1 [options]

# Options:
--manifest <path>      # Specify layer manifest file
--preview              # Show what would change (dry-run)
--apply                # Apply the optimizations
--verify               # Verify changes were applied correctly
--rollback             # Rollback the layer
--rollback-all         # Rollback all layers (reverse order)
--snapshot             # Create baseline snapshot
--status               # Show current system status
--verify-system        # Run full system integrity check
--help                 # Show help

# Examples:
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --preview
.\runtime\godmode.ps1 --manifest runtime\manifests\minimal.yaml --apply
.\runtime\godmode.ps1 --rollback --layer moderate
```

## Contact and Support

- **Issues:** Report on [GitHub Issues](https://github.com/yourorg/win11-optimizer/issues)
- **Security:** Email security@yourorg.com
- **Documentation:** See [Testing Guide](testing.md) for verification procedures