#Requires -Version 5.1
<#
.SYNOPSIS
    NinjaOne RMM Script: Egnyte Install/Update (Stage 2 of 2)
    
.DESCRIPTION
    Downloads and installs/updates Egnyte Desktop App (Connect).
    Designed for mass deployment via NinjaOne RMM.
    
    This script:
    1. Validates prerequisites and network connectivity
    2. Downloads the latest Egnyte MSI from official CDN
    3. Performs silent installation with logging
    4. Validates installation success
    5. Cleans up temporary files
    
.PARAMETER DownloadUrl
    URL to download Egnyte MSI. Defaults to latest official release.
    
.PARAMETER SkipIfInstalled
    If $true and Egnyte is already installed, skip installation.
    Default: $false (always install/update)
    
.PARAMETER MinimumVersion
    Only install if current version is below this version.
    Example: "3.26.0"
    
.NOTES
    Exit Codes (NinjaOne compatible):
    0    = Success - Egnyte installed/updated successfully
    1    = Installation failed
    2    = Critical error (prerequisites not met)
    3    = Download failed
    4    = MSI installation failed
    5    = Post-installation verification failed
    100  = Skipped - Already installed and SkipIfInstalled is true
    3010 = Success - Reboot required
    
    Author: Optimized for NinjaOne RMM deployment
    Version: 2.0
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DownloadUrl = 'https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/EgnyteConnectWin.msi',
    
    [Parameter()]
    [bool]$SkipIfInstalled = $false,
    
    [Parameter()]
    [string]$MinimumVersion = ''
)

#region Configuration
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

# Paths
$tempDir = Join-Path $env:TEMP 'EgnyteInstall'
$msiPath = Join-Path $tempDir 'EgnyteConnect.msi'
$logPath = Join-Path $tempDir "EgnyteInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$transcriptPath = Join-Path $env:TEMP "EgnyteInstall_Transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Retry configuration
$maxRetries = 3
$retryDelaySeconds = 10

# Installation timeout (10 minutes)
$installTimeoutSeconds = 600

try { Start-Transcript -Path $transcriptPath -Force } catch { }
#endregion

#region Helper Functions
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        'ERROR'   { Write-Error $Message }
        'WARNING' { Write-Warning $Message }
        default   { Write-Host $logMessage }
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-InstalledEgnyteVersion {
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    foreach ($path in $uninstallPaths) {
        $product = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -like '*Egnyte*' -and $_.DisplayName -notlike '*WebEdit*' } |
            Select-Object -First 1
        
        if ($product -and $product.DisplayVersion) {
            return [PSCustomObject]@{
                Name = $product.DisplayName
                Version = $product.DisplayVersion
                UninstallString = $product.UninstallString
            }
        }
    }
    
    return $null
}

function Test-VersionNeedsUpdate {
    param(
        [string]$CurrentVersion,
        [string]$MinVersion
    )
    
    if ([string]::IsNullOrWhiteSpace($MinVersion)) {
        return $true  # No minimum specified, always update
    }
    
    try {
        $current = [Version]($CurrentVersion -replace '[^0-9.]', '')
        $minimum = [Version]$MinVersion
        return $current -lt $minimum
    } catch {
        Write-Log "Could not compare versions: $_" -Level 'WARNING'
        return $true  # If we can't compare, proceed with update
    }
}

function Test-NetworkConnectivity {
    Write-Log "Testing network connectivity..."
    
    # Test DNS resolution
    try {
        $null = [System.Net.Dns]::GetHostAddresses('egnyte-cdn.egnyte.com')
        Write-Log "DNS resolution: OK"
    } catch {
        Write-Log "DNS resolution failed for egnyte-cdn.egnyte.com" -Level 'ERROR'
        return $false
    }
    
    # Test HTTPS connectivity
    try {
        $testRequest = [System.Net.WebRequest]::Create('https://egnyte-cdn.egnyte.com')
        $testRequest.Method = 'HEAD'
        $testRequest.Timeout = 30000
        $response = $testRequest.GetResponse()
        $response.Close()
        Write-Log "HTTPS connectivity: OK"
        return $true
    } catch {
        Write-Log "HTTPS connectivity test failed: $_" -Level 'ERROR'
        return $false
    }
}

function Get-FileWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxRetries = 3,
        [int]$RetryDelaySeconds = 10
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        Write-Log "Download attempt $attempt of $MaxRetries..."
        
        try {
            # Use BITS for more reliable download
            $bitsJob = Start-BitsTransfer -Source $Url -Destination $OutFile -ErrorAction Stop -Asynchronous
            
            # Wait for BITS transfer with timeout
            $timeout = New-TimeSpan -Minutes 10
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            while ($bitsJob.JobState -eq 'Transferring' -or $bitsJob.JobState -eq 'Connecting') {
                if ($stopwatch.Elapsed -gt $timeout) {
                    $bitsJob | Remove-BitsTransfer
                    throw "Download timed out after 10 minutes"
                }
                
                $percentComplete = 0
                if ($bitsJob.BytesTotal -gt 0) {
                    $percentComplete = [math]::Round(($bitsJob.BytesTransferred / $bitsJob.BytesTotal) * 100, 0)
                }
                Write-Progress -Activity "Downloading Egnyte" -Status "$percentComplete% Complete" -PercentComplete $percentComplete
                Start-Sleep -Seconds 2
            }
            
            Write-Progress -Activity "Downloading Egnyte" -Completed
            
            if ($bitsJob.JobState -eq 'Transferred') {
                $bitsJob | Complete-BitsTransfer
                
                # Verify file exists and has content
                if ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -gt 1MB) {
                    $fileSize = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
                    Write-Log "Download complete: $fileSize MB"
                    return $true
                } else {
                    throw "Downloaded file is missing or too small"
                }
            } else {
                $errorMsg = $bitsJob.ErrorDescription
                $bitsJob | Remove-BitsTransfer -ErrorAction SilentlyContinue
                throw "BITS transfer failed: $errorMsg"
            }
            
        } catch {
            Write-Log "Download attempt $attempt failed: $_" -Level 'WARNING'
            
            # Cleanup failed download
            if (Test-Path $OutFile) {
                Remove-Item -Path $OutFile -Force -ErrorAction SilentlyContinue
            }
            
            # Fallback to Invoke-WebRequest on last BITS attempt
            if ($attempt -eq 2) {
                Write-Log "Falling back to direct download method..."
                try {
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                    $ProgressPreference = 'SilentlyContinue'  # Speeds up Invoke-WebRequest
                    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 600
                    
                    if ((Test-Path $OutFile) -and (Get-Item $OutFile).Length -gt 1MB) {
                        $fileSize = [math]::Round((Get-Item $OutFile).Length / 1MB, 2)
                        Write-Log "Direct download complete: $fileSize MB"
                        return $true
                    }
                } catch {
                    Write-Log "Direct download also failed: $_" -Level 'WARNING'
                }
            }
            
            if ($attempt -lt $MaxRetries) {
                Write-Log "Waiting $RetryDelaySeconds seconds before retry..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }
    
    return $false
}

function Install-EgnyteMSI {
    param(
        [string]$MsiPath,
        [string]$LogPath
    )
    
    Write-Log "Starting MSI installation..."
    Write-Log "MSI Path: $MsiPath"
    Write-Log "Log Path: $LogPath"
    
    # Validate MSI file
    if (-not (Test-Path $MsiPath)) {
        throw "MSI file not found: $MsiPath"
    }
    
    # Build MSI arguments
    # /qn = silent, /norestart = don't auto-reboot, /L*v = verbose logging
    # ED_SILENT=1 is an Egnyte-specific flag for silent install
    $msiArgs = @(
        '/i'
        "`"$MsiPath`""
        '/qn'
        '/norestart'
        'REBOOT=ReallySuppress'
        'ED_SILENT=1'
        'ALLUSERS=1'
        '/L*v'
        "`"$LogPath`""
    )
    
    Write-Log "MSI Arguments: $($msiArgs -join ' ')"
    
    # Run MSI installer
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
    
    $exitCode = $process.ExitCode
    Write-Log "MSI Exit Code: $exitCode"
    
    # Interpret MSI exit codes
    switch ($exitCode) {
        0     { Write-Log "Installation completed successfully"; return 0 }
        1641  { Write-Log "Installation successful, reboot initiated"; return 3010 }
        3010  { Write-Log "Installation successful, reboot required"; return 3010 }
        1602  { throw "User cancelled installation (Exit: 1602)" }
        1603  { throw "Fatal error during installation (Exit: 1603). Check MSI log." }
        1618  { throw "Another installation is in progress (Exit: 1618)" }
        1619  { throw "MSI package could not be opened (Exit: 1619)" }
        1620  { throw "MSI package is invalid (Exit: 1620)" }
        1622  { throw "Error opening installation log file (Exit: 1622)" }
        1625  { throw "Installation prohibited by policy (Exit: 1625)" }
        1638  { throw "Another version is installed (Exit: 1638)" }
        default { 
            if ($exitCode -ne 0) {
                throw "MSI installation failed with exit code: $exitCode"
            }
            return $exitCode
        }
    }
}

function Test-EgnyteInstallation {
    Write-Log "Verifying Egnyte installation..."
    
    $checks = @{
        'Registry Entry' = $false
        'Program Files' = $false
        'Main Executable' = $false
        'Service' = $false
    }
    
    # Check registry
    $installed = Get-InstalledEgnyteVersion
    if ($installed) {
        Write-Log "Registry: Found $($installed.Name) v$($installed.Version)"
        $checks['Registry Entry'] = $true
    }
    
    # Check program files
    $installPaths = @(
        "${env:ProgramFiles(x86)}\Egnyte Connect",
        "$env:ProgramFiles\Egnyte Connect",
        "${env:ProgramFiles(x86)}\Egnyte",
        "$env:ProgramFiles\Egnyte"
    )
    
    foreach ($path in $installPaths) {
        if (Test-Path $path) {
            Write-Log "Program Files: Found at $path"
            $checks['Program Files'] = $true
            
            # Check for main executable
            $exePath = Join-Path $path 'EgnyteClient.exe'
            if (Test-Path $exePath) {
                Write-Log "Main Executable: Found EgnyteClient.exe"
                $checks['Main Executable'] = $true
            }
            break
        }
    }
    
    # Check service (may not be running until user logs in)
    $service = Get-Service -Name 'egnytefs' -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Service: Found egnytefs (Status: $($service.Status))"
        $checks['Service'] = $true
    } else {
        Write-Log "Service: egnytefs not found (may start after user login)" -Level 'WARNING'
    }
    
    # Determine overall success
    $passed = ($checks.Values | Where-Object { $_ }).Count
    $total = $checks.Count
    
    Write-Log "Verification: $passed/$total checks passed"
    
    # Consider it successful if at least registry and executable exist
    return ($checks['Registry Entry'] -and $checks['Main Executable'])
}

function Remove-TempFiles {
    Write-Log "Cleaning up temporary files..."
    
    # Keep logs for troubleshooting, remove MSI
    if (Test-Path $msiPath) {
        Remove-Item -Path $msiPath -Force -ErrorAction SilentlyContinue
    }
    
    # Optionally remove the temp directory if empty
    if (Test-Path $tempDir) {
        $items = Get-ChildItem -Path $tempDir -ErrorAction SilentlyContinue
        if ($items.Count -eq 0) {
            Remove-Item -Path $tempDir -Force -ErrorAction SilentlyContinue
        }
    }
}
#endregion

#region Main Execution
Write-Log "=========================================="
Write-Log "EGNYTE INSTALL/UPDATE SCRIPT - NinjaOne RMM"
Write-Log "=========================================="
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "User Context: $env:USERNAME"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log "Download URL: $DownloadUrl"
Write-Log "Skip If Installed: $SkipIfInstalled"
Write-Log "Minimum Version: $(if($MinimumVersion){"$MinimumVersion"}else{'Not specified'})"
Write-Log "=========================================="

$exitCode = 0

try {
    # Check for admin rights
    if (-not (Test-Administrator)) {
        Write-Log "This script requires administrator privileges!" -Level 'ERROR'
        $exitCode = 2
        throw "Administrator privileges required"
    }
    
    # Check current installation
    Write-Log "`n--- Checking Current Installation ---"
    $currentInstall = Get-InstalledEgnyteVersion
    
    if ($currentInstall) {
        Write-Log "Current Installation: $($currentInstall.Name) v$($currentInstall.Version)"
        
        if ($SkipIfInstalled) {
            Write-Log "SkipIfInstalled is enabled. Skipping installation."
            $exitCode = 100
            throw "SKIP"
        }
        
        if ($MinimumVersion -and -not (Test-VersionNeedsUpdate -CurrentVersion $currentInstall.Version -MinVersion $MinimumVersion)) {
            Write-Log "Current version ($($currentInstall.Version)) meets minimum requirement ($MinimumVersion). Skipping."
            $exitCode = 100
            throw "SKIP"
        }
        
        Write-Log "Proceeding with update..."
    } else {
        Write-Log "No existing Egnyte installation found. Proceeding with fresh install."
    }
    
    # Test network connectivity
    Write-Log "`n--- Testing Network Connectivity ---"
    if (-not (Test-NetworkConnectivity)) {
        $exitCode = 2
        throw "Network connectivity test failed. Cannot reach Egnyte CDN."
    }
    
    # Create temp directory
    Write-Log "`n--- Preparing Installation ---"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        Write-Log "Created temp directory: $tempDir"
    }
    
    # Download MSI
    Write-Log "`n--- Downloading Egnyte Installer ---"
    if (-not (Get-FileWithRetry -Url $DownloadUrl -OutFile $msiPath -MaxRetries $maxRetries -RetryDelaySeconds $retryDelaySeconds)) {
        $exitCode = 3
        throw "Failed to download Egnyte installer after $maxRetries attempts"
    }
    
    # Stop existing Egnyte processes (for clean upgrade)
    Write-Log "`n--- Stopping Existing Egnyte Processes ---"
    $egnyteProcesses = @('EgnyteClient', 'EgnyteDrive', 'EgnyteSyncService', 'EgnyteUpdate')
    foreach ($procName in $egnyteProcesses) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "Stopping process: $($_.Name)"
            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 3
    
    # Install MSI
    Write-Log "`n--- Installing Egnyte ---"
    $installResult = Install-EgnyteMSI -MsiPath $msiPath -LogPath $logPath
    
    if ($installResult -eq 3010) {
        $exitCode = 3010
        Write-Log "Installation requires reboot"
    }
    
    # Verify installation
    Write-Log "`n--- Verifying Installation ---"
    Start-Sleep -Seconds 5  # Give Windows time to update registry
    
    if (-not (Test-EgnyteInstallation)) {
        $exitCode = 5
        throw "Post-installation verification failed"
    }
    
    # Get final version info
    $finalInstall = Get-InstalledEgnyteVersion
    if ($finalInstall) {
        Write-Log "`nFinal Installation: $($finalInstall.Name) v$($finalInstall.Version)"
    }
    
    Write-Log "`n=========================================="
    if ($exitCode -eq 3010) {
        Write-Log "Installation completed successfully. REBOOT REQUIRED."
        Write-Log "Exit Code: 3010"
    } else {
        Write-Log "Installation completed successfully!"
        Write-Log "Exit Code: 0"
        $exitCode = 0
    }
    
} catch {
    if ($_.Exception.Message -ne "SKIP") {
        Write-Log "Error: $_" -Level 'ERROR'
        if ($_.ScriptStackTrace) {
            Write-Log $_.ScriptStackTrace -Level 'ERROR'
        }
        
        # Set appropriate exit code if not already set
        if ($exitCode -eq 0) {
            $exitCode = 1
        }
    }
} finally {
    # Cleanup
    Remove-TempFiles
    
    Write-Log "=========================================="
    Write-Log "MSI Log saved to: $logPath"
    Write-Log "Transcript saved to: $transcriptPath"
    
    try { Stop-Transcript } catch { }
}

exit $exitCode
#endregion
