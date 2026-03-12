@{
    # PSScriptAnalyzer settings for Win11 Optimizer
    # Use: Invoke-ScriptAnalyzer -Settings .github/psscriptanalyzer.psd1

    Severity     = @('Error', 'Warning')
    IncludeRules = @(
        # Basic best practices
        'PSAvoidDefaultValueSwitchParameter',
        'PSMissingModuleManifestField',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSShouldProcess',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidUsingComputerNameHardcoded',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWMICmdlet',
        'PSAvoidUsingWriteHost',
        'PSDSCReturnCorrectTypesForDSCFunctions',
        'PSDSCUseIdenticalParametersForDSC',
        'PSDSCUseIdenticalModuleParametersForDSC',
        'PSMisleadingBacktick',
        'PSMissingModuleManifestField',
        'PSPossibleIncorrectComparisonWithNull',
        'PSProvideCommentHelp',
        'PSUseApprovedVerbs',
        'PSUseCmdletCorrectly',
        'PSUseOutputTypeCorrectly',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseSingularNouns',
        'PSUseToExportFieldsInManifest'
    )

    ExcludeRules = @(
        # Exceptions for this project
        'PSUseShouldProcessForStateChangingFunctions'  # Some internal functions don't need it
        'PSAvoidUsingWriteHost'                        # Used for TUI output
        'PSProvideCommentHelp'                         # Help provided in other formats
    )

    Rules        = @{
        PSAvoidUsingWriteHost = @{
            Enable = $true
            # Allow Write-Host for TUI and user-facing messages
            Whitelist = @(
                'Show-DisclaimerCard',
                'Get-UserConsent',
                'Show-Header',
                'Show-Menu',
                'Write-Log'
            )
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
            # Ignore certain variables that are intentionally used in specific contexts
            IgnoreVariables = @(
                'ErrorActionPreference',
                'ProgressPreference'
            )
        }
        PSAvoidUsingPositionalParameters = @{
            Enable = $true
            # Allow positional parameters for common cmdlets
            Whitelist = @('Write-Host', 'Write-Output', 'Write-Verbose')
        }
    }
}