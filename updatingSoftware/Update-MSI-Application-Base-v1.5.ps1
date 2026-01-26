## v1.5 - 2025-05-29
# Added pre-flight check for running applications
# This script only works for .msi files.
# It will download the file, install it, and then clean up the installer file.
# It will check for running applications.
# This script is a base script that can be used to update any software.
# It is not specific to any one application.
# It is a template that can be used to create a script for any application.
param(
    [string]$DownloadUrl = "linkHere",
    [string]$LocalDirectory = "C:\Archive",
    [string]$FileName = "desiredNameHere.msi",
    [string[]]$CriticalProcesses = @(),
    [switch]$NoPause
)

# --- Configuration ---
$downloadUrl = $DownloadUrl
$localDirectory = $LocalDirectory
$fileName = $FileName
$localPath = Join-Path -Path $localDirectory -ChildPath $fileName # Safely combines path and filename

# --- [NEW] Pre-Flight Check for Running Applications ---
Write-Host "Performing pre-flight check for open applications..."

# Add the process names (without .exe) via -CriticalProcesses when needed
$criticalProcesses = $CriticalProcesses

# Check if any of the critical processes are running
if ($criticalProcesses.Count -gt 0) {
    $runningProcesses = Get-Process -Name $criticalProcesses -ErrorAction SilentlyContinue

    if ($null -ne $runningProcesses) {
        # If any processes are found, list them, warn the user, and exit the script.
        $runningAppNames = $runningProcesses.ProcessName -join ', '
        Write-Warning "Update aborted. The following critical application(s) are running: $runningAppNames"
        Write-Warning "Please close these applications and re-run the script."
        exit 99 # Use a custom exit code to identify this specific failure reason
    }
    else {
        # If no processes are found, continue with the script.
        Write-Host "Pre-flight check passed. No conflicting applications are running."
    }
}
else {
    Write-Host "Pre-flight check skipped: No critical processes were specified."
}
# --- [END NEW SECTION] ---


# --- Script Logic ---

# Create the destination directory if it doesn't exist
if (-not (Test-Path -Path $localDirectory)) {
    New-Item -ItemType Directory -Path $localDirectory | Out-Null
}

# Ensure TLS 1.2+ is enabled for downloads
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
}
catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Download the Egnyte MSI file
Write-Host "Downloading the Egnyte installer to $localPath..."
try {
    Invoke-WebRequest -Uri $downloadUrl -OutFile $localPath -ErrorAction Stop
    Write-Host "Download complete."
}
catch {
    Write-Host "Error downloading the file: $_"
    exit 1
}

# Install the Egnyte update silently
Write-Host "Installing the update..."
$msiArgs = @(
    "/i"
    "`"$localPath`"" 
    "/quiet"
    "/norestart"
)

try {
    $process = Start-Process msiexec -ArgumentList $msiArgs -Wait -NoNewWindow -PassThru
    $exitCode = $process.ExitCode
    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        Write-Host "MSI installation failed with exit code $exitCode."
        exit 1
    }
    if ($exitCode -eq 3010) {
        Write-Host "MSI installation completed successfully. Reboot required."
        exit 3010
    }
    Write-Host "MSI installation complete."
}
catch {
    Write-Host "Error during installation: $_"
    exit 1
}

# Optional: Clean up the downloaded installer
Write-Host "Cleaning up the installer file..."
Remove-Item -Path $localPath -Force # This now correctly removes only the .msi file
Write-Host "Cleanup complete."

exit 0
