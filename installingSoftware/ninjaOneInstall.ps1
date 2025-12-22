<#
.SYNOPSIS
    NinjaOne Agent Silent Installer
.DESCRIPTION
    Downloads and installs the NinjaOne RMM agent with improved error handling,
    timeout management, and verification steps.
.NOTES
    Must be run with Administrator privileges
#>

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [int]$DownloadTimeoutSec = 300,  # 5 minutes for download
    [int]$InstallTimeoutSec = 600,   # 10 minutes for installation
    [switch]$KeepInstaller
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # Speeds up Invoke-WebRequest

# Configuration
$installerUrl = "addlinkhere"
$installerName = "NinjaOne-Agent-Auto.msi"
$downloadPath = Join-Path $env:TEMP $installerName
$logPath = Join-Path $env:TEMP "NinjaOne-Install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logPath -Value $logMessage
}

try {
    Write-Log "=== NinjaOne Agent Installation Started ===" "INFO"
    Write-Log "Log file: $logPath"
    
    # Verify administrative privileges
    Write-Log "Verifying administrative privileges..."
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "This script must be run as Administrator"
    }
    Write-Log "Administrative privileges confirmed"

    # Configure TLS
    Write-Log "Configuring security protocols..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        Write-Log "TLS 1.2 and 1.3 enabled"
    } catch {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Write-Log "TLS 1.2 enabled" "WARN"
    }

    # Check if NinjaOne is already installed
    Write-Log "Checking for existing NinjaOne installation..."
    $ninjaInstalled = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*NinjaOne*" }
    if ($ninjaInstalled) {
        Write-Log "NinjaOne is already installed: $($ninjaInstalled.Name) (Version: $($ninjaInstalled.Version))" "WARN"
        $continue = Read-Host "Continue with reinstallation? (Y/N)"
        if ($continue -ne 'Y') {
            Write-Log "Installation cancelled by user"
            exit 0
        }
    }

    # Clean up old installer if it exists and is corrupted
    if (Test-Path $downloadPath) {
        Write-Log "Previous installer found at $downloadPath"
        $fileInfo = Get-Item $downloadPath
        if ($fileInfo.Length -lt 1MB) {
            Write-Log "Previous installer appears incomplete, removing..." "WARN"
            Remove-Item $downloadPath -Force
        } else {
            Write-Log "Using existing installer (Size: $([math]::Round($fileInfo.Length/1MB, 2)) MB)"
            $skipDownload = $true
        }
    }

    # Download installer
    if (-not $skipDownload) {
        Write-Log "Downloading NinjaOne agent from: $installerUrl"
        Write-Log "Download timeout set to: $DownloadTimeoutSec seconds"
        
        try {
            # Use BITS for more reliable downloads with resume capability
            Write-Log "Attempting download via BITS (Background Intelligent Transfer Service)..."
            Import-Module BitsTransfer -ErrorAction Stop
            
            Start-BitsTransfer -Source $installerUrl `
                              -Destination $downloadPath `
                              -Priority High `
                              -TransferType Download `
                              -ErrorAction Stop
            
            Write-Log "Download completed via BITS"
        }
        catch {
            Write-Log "BITS download failed, falling back to WebRequest: $($_.Exception.Message)" "WARN"
            
            # Fallback to Invoke-WebRequest with timeout
            $headers = @{
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
                "Accept"     = "application/octet-stream,*/*"
            }
            
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", $headers["User-Agent"])
            
            # Register timeout
            $downloadTask = $webClient.DownloadFileTaskAsync($installerUrl, $downloadPath)
            
            if (-not $downloadTask.Wait($DownloadTimeoutSec * 1000)) {
                $webClient.CancelAsync()
                throw "Download timed out after $DownloadTimeoutSec seconds"
            }
            
            if ($downloadTask.IsFaulted) {
                throw $downloadTask.Exception
            }
            
            Write-Log "Download completed via WebClient"
        }
    }

    # Verify downloaded file
    Write-Log "Verifying downloaded installer..."
    if (-not (Test-Path $downloadPath)) {
        throw "Installer not found at $downloadPath"
    }
    
    $fileSize = (Get-Item $downloadPath).Length
    Write-Log "Installer size: $([math]::Round($fileSize/1MB, 2)) MB"
    
    if ($fileSize -lt 100KB) {
        throw "Downloaded file is too small ($fileSize bytes), likely corrupt or incomplete"
    }

    # Verify MSI file integrity
    Write-Log "Verifying MSI integrity..."
    try {
        $windowsInstaller = New-Object -ComObject WindowsInstaller.Installer
        $database = $windowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstaller, @($downloadPath, 0))
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($database) | Out-Null
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($windowsInstaller) | Out-Null
        Write-Log "MSI integrity verified"
    }
    catch {
        Write-Log "MSI integrity check failed: $($_.Exception.Message)" "WARN"
    }

    # Install NinjaOne agent
    Write-Log "Starting NinjaOne agent installation..."
    Write-Log "Installation timeout set to: $InstallTimeoutSec seconds"
    Write-Log "MSI Log will be created at: $env:TEMP\NinjaOne-MSI-Install.log"
    
    $msiLogPath = Join-Path $env:TEMP "NinjaOne-MSI-Install.log"
    $msiArgs = @(
        "/i"
        "`"$downloadPath`""
        "/qn"                    # Completely silent
        "/norestart"             # Don't restart automatically
        "/l*v"                   # Verbose logging
        "`"$msiLogPath`""        # Log file path
        "REBOOT=ReallySuppress"  # Suppress reboot prompts
    )
    
    Write-Log "MSI Arguments: msiexec.exe $($msiArgs -join ' ')"
    
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "msiexec.exe"
    $processInfo.Arguments = $msiArgs -join ' '
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    
    if (-not $process.Start()) {
        throw "Failed to start msiexec.exe process"
    }
    
    Write-Log "Installation process started (PID: $($process.Id))"
    
    # Wait with timeout
    if (-not $process.WaitForExit($InstallTimeoutSec * 1000)) {
        Write-Log "Installation timed out after $InstallTimeoutSec seconds" "ERROR"
        $process.Kill()
        throw "Installation process timed out"
    }
    
    $exitCode = $process.ExitCode
    Write-Log "Installation process completed with exit code: $exitCode"
    
    # Check exit code
    # https://docs.microsoft.com/en-us/windows/win32/msi/error-codes
    switch ($exitCode) {
        0 { Write-Log "Installation completed successfully" "SUCCESS" }
        1641 { Write-Log "Installation succeeded, restart initiated" "SUCCESS" }
        3010 { Write-Log "Installation succeeded, restart required" "SUCCESS" }
        1603 { throw "Fatal error during installation" }
        1618 { throw "Another installation is already in progress" }
        1619 { throw "Installation package could not be opened" }
        1620 { throw "Installation package could not be opened (corrupt or invalid)" }
        1633 { throw "This installation package is not supported on this platform" }
        default { throw "Installation failed with exit code $exitCode" }
    }

    # Verify installation
    Write-Log "Verifying NinjaOne installation..."
    Start-Sleep -Seconds 5
    
    $ninjaService = Get-Service -Name "NinjaRMMAgent" -ErrorAction SilentlyContinue
    if ($ninjaService) {
        Write-Log "NinjaRMMAgent service found (Status: $($ninjaService.Status))" "SUCCESS"
        
        if ($ninjaService.Status -ne 'Running') {
            Write-Log "Starting NinjaRMMAgent service..."
            Start-Service -Name "NinjaRMMAgent"
            Start-Sleep -Seconds 3
            $ninjaService.Refresh()
            Write-Log "Service status: $($ninjaService.Status)"
        }
    } else {
        Write-Log "NinjaRMMAgent service not found - installation may need time to complete" "WARN"
    }
    
    # Check installation path
    $commonPaths = @(
        "${env:ProgramFiles}\NinjaRMMAgent",
        "${env:ProgramFiles(x86)}\NinjaRMMAgent"
    )
    
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            Write-Log "NinjaOne installation found at: $path" "SUCCESS"
            break
        }
    }

    # Cleanup
    if (-not $KeepInstaller) {
        Write-Log "Cleaning up installer..."
        try {
            Remove-Item -Path $downloadPath -Force -ErrorAction Stop
            Write-Log "Installer removed from: $downloadPath"
        }
        catch {
            Write-Log "Could not remove installer: $($_.Exception.Message)" "WARN"
        }
    } else {
        Write-Log "Installer kept at: $downloadPath"
    }
    
    Write-Log "=== NinjaOne Agent Installation Completed Successfully ===" "SUCCESS"
    Write-Log "Installation log: $logPath"
    Write-Log "MSI log: $msiLogPath"
    
    exit 0
}
catch {
    Write-Log "=== Installation Failed ===" "ERROR"
    Write-Log "Error: $($_.Exception.Message)" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    Write-Log "Installation log: $logPath"
    
    if (Test-Path $msiLogPath) {
        Write-Log "MSI log available at: $msiLogPath"
        Write-Log "Last 20 lines of MSI log:" "ERROR"
        Get-Content $msiLogPath -Tail 20 | ForEach-Object { Write-Log $_ "ERROR" }
    }
    
    exit 1
}
