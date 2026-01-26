# v1.0 - 2025-05-29
# This script only works for .msi files.
# It will download the file, install it, and then clean up the installer file.
# It will not check for running applications.

param(
    [string]$DownloadUrl = "https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/EgnyteConnectWin.msi",
    [string]$LocalDirectory = "C:\Archive",
    [string]$FileName = "EgnyteSetup.msi"
)

# --- Configuration ---

## Current config uses egnyte as an example
$downloadUrl = $DownloadUrl
$localDirectory = $LocalDirectory
$fileName = $FileName
$localPath = Join-Path -Path $localDirectory -ChildPath $fileName # Safely combines path and filename

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
Write-Host "Installing the Egnyte update..."
$msiArgs = @(
    "/i"
    "`"$localPath`"" # The path now correctly points to the .msi file
    "/quiet"
    "/norestart"
)

try {
    $process = Start-Process msiexec -ArgumentList $msiArgs -Wait -NoNewWindow -PassThru
    $exitCode = $process.ExitCode
    if ($exitCode -ne 0 -and $exitCode -ne 3010) {
        Write-Host "Egnyte update failed with exit code $exitCode."
        exit 1
    }
    if ($exitCode -eq 3010) {
        Write-Host "Egnyte update completed successfully. Reboot required."
        exit 3010
    }
    Write-Host "Egnyte update installation complete."
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
