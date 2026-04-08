# Win11 Optimizer - Utility Functions Module
# This module provides helper functions for the optimizer

function Get-WinOptimizerPath {
    <#
    .SYNOPSIS
        Get the WinOptimizer installation path
    #>
    $scriptPath = $PSScriptRoot
    return Split-Path -Parent $scriptPath
}

function Get-WinOptimizerConfigPath {
    <#
    .SYNOPSIS
        Get the configuration directory path
    #>
    return "C:\ProgramData\WinOptimizer"
}

function Get-WinOptimizerBackupPath {
    <#
    .SYNOPSIS
        Get the backup directory path
    #>
    return Join-Path (Get-WinOptimizerConfigPath) "backup"
}

function Get-WinOptimizerLogPath {
    <#
    .SYNOPSIS
        Get the log directory path
    #>
    return Join-Path (Get-WinOptimizerConfigPath) "logs"
}

function Get-WinOptimizerStatePath {
    <#
    .SYNOPSIS
        Get the state directory path
    #>
    return Join-Path (Get-WinOptimizerConfigPath) "state"
}

function Test-AdminPrivilege {
    <#
    .SYNOPSIS
        Check if the current session has administrator privileges

    .OUTPUTS
        Boolean indicating admin status
    #>
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ProtectedComponent {
    <#
    .SYNOPSIS
        Check if a component is protected from modification

    .PARAMETER Component
        The component name or path to check

    .OUTPUTS
        Boolean indicating if the component is protected
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Component
    )

    $protectedServices = @(
        'TrustedInstaller',
        'WinDefend',
        'WdNisSvc',
        'wuauserv',
        'UsoSvc',
        'DcomLaunch',
        'RpcSs',
        'RpcEptMapper',
        'PlugPlay',
        'EventLog',
        'Schedule',
        'LSM',
        'Winmgmt',
        'LanmanServer',
        'LanmanWorkstation',
        'Dnscache',
        'Dhcp',
        'NSI'
    )

    $protectedProcesses = @(
        'lsass',
        'smss',
        'csrss',
        'winlogon',
        'services',
        'explorer'
    )

    $protectedRegistry = @(
        'HKLM:\SYSTEM\CurrentControlSet\Services\TrustedInstaller',
        'HKLM:\SOFTWARE\Microsoft\Windows Defender'
    )

    # Check services
    if ($protectedServices -contains $Component) {
        return $true
    }

    # Check processes
    if ($protectedProcesses -contains $Component.ToLower()) {
        return $true
    }

    # Check registry paths
    foreach ($path in $protectedRegistry) {
        if ($Component -like "$path*") {
            return $true
        }
    }

    return $false
}

function New-WinOptimizerDirectory {
    <#
    .SYNOPSIS
        Create a directory if it doesn't exist

    .PARAMETER Path
        The directory path to create
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Export-WinOptimizerSnapshot {
    <#
    .SYNOPSIS
        Export a system snapshot for backup/verification

    .PARAMETER OutputPath
        The directory path where the snapshot will be saved
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    New-WinOptimizerDirectory -Path $OutputPath
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $snapshotDir = Join-Path $OutputPath $timestamp
    New-WinOptimizerDirectory -Path $snapshotDir

    # Export services
    Get-Service | Select-Object Name, DisplayName, Status, StartType |
        Export-Csv (Join-Path $snapshotDir "services.csv") -NoTypeInformation

    # Export AppX packages
    Get-AppxPackage | Select-Object Name, PackageFullName, Version |
        Export-Csv (Join-Path $snapshotDir "appx.csv") -NoTypeInformation

    # Export scheduled tasks
    Get-ScheduledTask | Select-Object TaskName, TaskPath, State |
        Export-Csv (Join-Path $snapshotDir "tasks.csv") -NoTypeInformation

    # Export firewall rules
    Get-NetFirewallRule | Select-Object Name, DisplayName, Direction, Action, Enabled |
        Export-Csv (Join-Path $snapshotDir "firewall.csv") -NoTypeInformation

    # Export registry keys
    $registryPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    )

    $registryData = foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $item = Get-Item -Path $path
            foreach ($property in $item.Property) {
                [PSCustomObject]@{
                    Path   = $path
                    Name   = $property
                    Value  = ($item.GetValue($property) -as [string])
                    Type   = $item.GetValueKind($property)
                }
            }
        }
    }

    $registryData | Export-Csv (Join-Path $snapshotDir "registry.csv") -NoTypeInformation

    return $snapshotDir
}

function Test-WindowsUpdateAccess {
    <#
    .SYNOPSIS
        Test if Windows Update is accessible

    .OUTPUTS
        Boolean indicating if Windows Update is accessible
    #>
    $service = Get-Service wuauserv -ErrorAction SilentlyContinue
    return $null -ne $service -and $service.Status -in @('Running', 'Stopped')
}

function Test-DefenderStatus {
    <#
    .SYNOPSIS
        Test if Windows Defender is running properly

    .OUTPUTS
        Hashtable with Defender status information
    #>
    try {
        $status = Get-MpComputerStatus -ErrorAction Stop
        return @{
            Available = $true
            RealTimeEnabled = $status.RealTimeProtectionEnabled
            IoavProtectionEnabled = $status.IoavProtectionEnabled
            AntispywareEnabled = $status.AntispywareEnabled
            AntivirusEnabled = $status.AntivirusEnabled
        }
    } catch {
        return @{
            Available = $false
            Error = $_.Exception.Message
        }
    }
}

function Compare-Snapshot {
    <#
    .SYNOPSIS
        Compare two system snapshots

    .PARAMETER BeforePath
        Path to the 'before' snapshot

    .PARAMETER AfterPath
        Path to the 'after' snapshot

    .OUTPUTS
        Hashtable with comparison results
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$BeforePath,

        [Parameter(Mandatory = $true)]
        [string]$AfterPath
    )

    # Initialize result hashtable (modified and returned below)
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
    $result = @{
        ServicesAdded = @()
        ServicesRemoved = @()
        ServicesChanged = @()
    }

    if (Test-Path (Join-Path $BeforePath "services.csv") -and
        Test-Path (Join-Path $AfterPath "services.csv")) {

        $before = Import-Csv (Join-Path $BeforePath "services.csv")
        $after = Import-Csv (Join-Path $AfterPath "services.csv")

        $beforeServices = @($before | Select-Object -ExpandProperty Name)
        $afterServices = @($after | Select-Object -ExpandProperty Name)

        $result.ServicesAdded = $afterServices | Where-Object { $_ -notin $beforeServices }
        $result.ServicesRemoved = $beforeServices | Where-Object { $_ -notin $afterServices }
    }

    return $result
}

function ConvertFrom-YamlSimple {
    <#
    .SYNOPSIS
        Simple YAML parser (for module metadata)

    .PARAMETER Path
        Path to the YAML file

    .OUTPUTS
        Hashtable with parsed data
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = @{}
    $content = Get-Content $Path -Raw

    foreach ($line in $content -split "`n") {
        $line = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line -match '^#') { continue }

        if ($line -match '^(\w+):\s*(.*)$') {
            $key = $matches[1]
            $value = $matches[2] -replace '["'']', ''
            $result[$key] = $value
        } elseif ($line -match '^\s*-\s*(.+)$') {
            $item = $matches[1].Trim()
            if (-not $result.ContainsKey('items')) {
                $result['items'] = @()
            }
            $result['items'] += $item
        }
    }

    return $result
}

function Get-WinOptimizerState {
    <#
    .SYNOPSIS
        Get the current optimizer state (applied layers)

    .OUTPUTS
        Hashtable with state information
    #>
    $stateFile = Join-Path (Get-WinOptimizerStatePath) "applied.json"

    if (-not (Test-Path $stateFile)) {
        return @{
            Version = $null
            AppliedLayers = @()
            LastRun = $null
        }
    }

    try {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
        return @{
            Version = $state.Version
            AppliedLayers = $state.AppliedLayers
            LastRun = $state.LastRun
        }
    } catch {
        return @{
            Version = $null
            AppliedLayers = @()
            LastRun = $null
        }
    }
}

function Set-WinOptimizerState {
    <#
    .SYNOPSIS
        Set the optimizer state

    .PARAMETER Layer
        The layer name to add/remove from applied layers

    .PARAMETER Applied
        Whether the layer is being applied or removed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Layer,

        [Parameter(Mandatory = $true)]
        [bool]$Applied
    )

    $statePath = Get-WinOptimizerStatePath
    New-WinOptimizerDirectory -Path $statePath

    $stateFile = Join-Path $statePath "applied.json"

    if (Test-Path $stateFile) {
        $state = Get-Content $stateFile -Raw | ConvertFrom-Json
    } else {
        $state = @{
            Version = "1.0.0"
            AppliedLayers = @()
        }
    }

    if ($Applied) {
        if ($state.AppliedLayers -notcontains $Layer) {
            $state.AppliedLayers += $Layer
        }
    } else {
        $state.AppliedLayers = @($state.AppliedLayers | Where-Object { $_ -ne $Layer })
    }

    $state.LastRun = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $state | ConvertTo-Json -Depth 10 | Out-File $stateFile -Encoding UTF8
}

# CODE-002: Removed Export-ModuleMember - this cmdlet only works in .psm1 module files,
# not in .ps1 scripts. Function visibility in dot-sourced scripts is controlled by scope.