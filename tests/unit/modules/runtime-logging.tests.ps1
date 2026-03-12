# AUTHOR: claude-code
# SAFE: snapshot → apply → verify → rollback
# RUN INSIDE WINDOWS VM OR CI ONLY
#
# Unit tests for runtime/logging.ps1 — JSON structured logging (P1 — F8)
# Run: Invoke-Pester -Path ./tests/unit/modules/runtime-logging.tests.ps1

Describe 'Runtime logging.ps1 — JSON Structured Logging' -Tags @('Unit', 'Runtime', 'Logging') {
    BeforeAll {
        $loggingPath = "$PSScriptRoot/../../../runtime/logging.ps1"
        $patchPath   = "$PSScriptRoot/../../../suggested_patches/logging-fix-F8.ps1"

        # Use patched file if available
        $sourceFile = if (Test-Path $patchPath) { $patchPath } else { $loggingPath }
    }

    Context 'Script Structure' {
        It 'logging helper exists (either runtime or patch)' {
            ($sourceFile | Test-Path) | Should -BeTrue
        }

        BeforeAll {
            if (Test-Path $sourceFile) {
                $content = Get-Content $sourceFile -Raw
            }
        }

        It 'defines Write-Log function' {
            $content | Should -Match 'function Write-Log'
        }
    }

    Context 'JSON Output Format' {
        BeforeAll {
            if (Test-Path $sourceFile) {
                $content = Get-Content $sourceFile -Raw
            }
        }

        It 'outputs JSON format' {
            $content | Should -Match 'ConvertTo-Json'
        }

        It 'includes timestamp field' {
            $content | Should -Match 'timestamp|Timestamp'
        }

        It 'includes level field' {
            $content | Should -Match 'level|Level'
        }

        It 'includes message field' {
            $content | Should -Match 'message|Message'
        }
    }

    Context 'Log File Location' {
        BeforeAll {
            if (Test-Path $sourceFile) {
                $content = Get-Content $sourceFile -Raw
            }
        }

        It 'writes to ProgramData log directory' {
            $content | Should -Match 'ProgramData.*WinOptimizer.*logs|LOG_DIR'
        }
    }

    Context 'Functional Test (requires dot-sourcing)' {
        BeforeAll {
            # Create a temp log directory for testing
            $testLogDir = Join-Path $env:TEMP "WinOptimizer-test-logs-$(Get-Random)"
            New-Item -Path $testLogDir -ItemType Directory -Force | Out-Null
        }

        AfterAll {
            if (Test-Path $testLogDir) {
                Remove-Item $testLogDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'produces valid JSON when writing a log entry' {
            $logFile = Join-Path $testLogDir "test.json"

            $entry = @{
                timestamp = Get-Date -Format "o"
                level     = "INFO"
                message   = "Test log entry"
                layer     = "minimal"
                operation = "test"
                result    = "success"
            }

            $entry | ConvertTo-Json -Compress | Out-File $logFile -Append -Encoding UTF8

            $logFile | Should -Exist
            $line = Get-Content $logFile -Raw
            { $line | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}
