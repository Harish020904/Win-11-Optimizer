# Win11 Optimizer Installer
#
# SECURITY NOTICE: This script must be reviewed before execution.
# DO NOT pipe this script directly from a remote source using iex.
# Instead, download first, review the contents, then execute:
#   Invoke-WebRequest -Uri <url> -OutFile install.ps1
#   .\install.ps1
#
# This script downloads and installs the Win11 Optimizer TUI application.

$ErrorActionPreference = 'Stop'

# Configuration
$repo = "Harish020904/Win-11-Optimizer"
$installDir = "$env:LOCALAPPDATA\Win11Optimizer"
$binName = "win11-optimizer.exe"

function Write-Step {
    param([string]$Message)
    Write-Host "→ " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Header
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Win11 Optimizer - Installation                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check Windows
if ($env:OS -ne "Windows_NT") {
    Write-Error "This installer only works on Windows."
    exit 1
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "PowerShell 5.0 or higher is required."
    exit 1
}

try {
    # Get latest release
    Write-Step "Fetching latest release information..."
    $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"
    $headers = @{ "User-Agent" = "Win11Optimizer-Installer" }
    
    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers
        $version = $release.tag_name
        Write-Success "Found version $version"
    }
    catch {
        # Fall back to downloading from main branch if no releases yet
        Write-Step "No releases found, downloading development version..."
        $version = "dev"
    }

    # Create install directory
    Write-Step "Creating installation directory..."
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    }
    Write-Success "Directory: $installDir"

    # Download binary
    if ($version -ne "dev") {
        $asset = $release.assets | Where-Object { $_.name -like "win11-optimizer-*.exe" -or $_.name -eq "win11-optimizer.exe" } | Select-Object -First 1
        
        if ($asset) {
            Write-Step "Downloading $($asset.name)..."
            $exePath = Join-Path $installDir $binName
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exePath -UseBasicParsing
            Write-Success "Downloaded to $exePath"
            
            # Verify checksum if available
            $checksumAsset = $release.assets | Where-Object { $_.name -eq "checksums.txt" }
            if ($checksumAsset) {
                Write-Step "Verifying checksum..."
                $checksums = (Invoke-WebRequest -Uri $checksumAsset.browser_download_url -UseBasicParsing).Content
                $expectedHash = ($checksums -split "`n" | Where-Object { $_ -like "*$($asset.name)*" }) -replace "^(\S+).*", '$1'
                $actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash
                
                if ($expectedHash -and $expectedHash -eq $actualHash) {
                    Write-Success "Checksum verified"
                }
                else {
                    Write-Host "    Warning: Checksum verification skipped or failed" -ForegroundColor Yellow
                }
            }
        }
        else {
            Write-Error "Could not find binary in release assets"
            exit 1
        }
    }
    else {
        # Development version - just clone/copy modules
        Write-Step "Setting up development version..."
        
        # Download modules and runtime from GitHub
        $modulesUrl = "https://github.com/$repo/archive/refs/heads/main.zip"
        $zipPath = Join-Path $env:TEMP "win11-optimizer-main.zip"
        
        Write-Step "Downloading repository..."
        Invoke-WebRequest -Uri $modulesUrl -OutFile $zipPath -UseBasicParsing
        
        Write-Step "Extracting..."
        $extractPath = Join-Path $env:TEMP "win11-optimizer-extract"
        Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
        
        # Copy modules and runtime
        $srcPath = Join-Path $extractPath "Win-11-Optimizer-main"
        Copy-Item -Path (Join-Path $srcPath "modules") -Destination $installDir -Recurse -Force
        Copy-Item -Path (Join-Path $srcPath "runtime") -Destination $installDir -Recurse -Force
        
        # Cleanup
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-Success "Modules installed"
        
        Write-Host ""
        Write-Host "Note: Development version installed. Binary not available yet." -ForegroundColor Yellow
        Write-Host "Run the PowerShell scripts directly from: $installDir\runtime\godmode.ps1" -ForegroundColor Yellow
    }

    # Add to PATH if binary exists
    $exePath = Join-Path $installDir $binName
    if (Test-Path $exePath) {
        Write-Step "Adding to PATH..."
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        if ($userPath -notlike "*$installDir*") {
            [Environment]::SetEnvironmentVariable("PATH", "$userPath;$installDir", "User")
            $env:PATH = "$env:PATH;$installDir"
            Write-Success "Added to user PATH"
        }
        else {
            Write-Success "Already in PATH"
        }
    }

    # Success message
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║           Installation Complete!                         ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    if (Test-Path $exePath) {
        Write-Host "Run 'win11-optimizer' to start the TUI wizard." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor White
        Write-Host "  win11-optimizer              # Start TUI wizard" -ForegroundColor Gray
        Write-Host "  win11-optimizer --status     # Show current status" -ForegroundColor Gray
        Write-Host "  win11-optimizer --help       # Show help" -ForegroundColor Gray
    }
    else {
        Write-Host "Run the optimizer with:" -ForegroundColor Cyan
        Write-Host "  cd $installDir" -ForegroundColor Gray
        Write-Host "  .\runtime\godmode.ps1 --help" -ForegroundColor Gray
    }
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Error "Installation failed: $_"
    Write-Host ""
    Write-Host "Please report this issue at:" -ForegroundColor Yellow
    Write-Host "  https://github.com/$repo/issues" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
