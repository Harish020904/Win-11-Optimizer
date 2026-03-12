# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# PROPOSED PATCH — F7: Remove Export-ModuleMember from .ps1 file
# WHY: Export-ModuleMember only works in .psm1 files. Crashes when dot-sourced.
# HOW TO TEST: Invoke-Pester -Path ./tests/unit/modules/runtime-utils.tests.ps1
# APPLY: Copy this file to runtime/utils.ps1 (replacing lines 406-423)
#
# The fix removes the Export-ModuleMember block (lines 406-423 of original).
# When dot-sourced (. .\runtime\utils.ps1), all functions are naturally
# available in the caller's scope without Export-ModuleMember.
#
# Alternatively, rename to utils.psm1 and use:
#   Import-Module .\runtime\utils.psm1 -Force
# But dot-sourcing is simpler and matches current godmode.ps1 usage.
#
# INSTRUCTIONS:
# 1. Open runtime/utils.ps1
# 2. Delete lines 406-423 (the Export-ModuleMember block)
# 3. Save file
#
# BEFORE (lines 406-423):
#   # Export functions
#   Export-ModuleMember -Function @(
#       'Get-WinOptimizerPath',
#       'Get-WinOptimizerConfigPath',
#       ... (all function names) ...
#   )
#
# AFTER:
#   (nothing — just remove the block entirely)
#
# No other changes needed. All functions remain defined and accessible
# via dot-sourcing.
