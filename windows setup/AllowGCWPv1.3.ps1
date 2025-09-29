<#
This script first cleans up any previous GCPW installation and then performs a
fresh install and configuration. It is designed to be robust and idempotent.
#>

# --- Configuration ---
$domainsAllowedToLogin = "ashleyvance.com"

#======================================================================
# --- 1. Cleanup Phase: Remove any previous installation ---
#======================================================================

Write-Host "Starting cleanup of any previous GCPW installations..."

# Attempt to uninstall the package if it exists
try {
    $gcpwPackage = Get-Package -Name "Google Credential Provider for Windows" -ErrorAction SilentlyContinue
    if ($gcpwPackage) {
        Write-Host "Found existing GCPW installation. Uninstalling..."
        Uninstall-Package -Name $gcpwPackage.Name -Force -ErrorAction Stop
        Write-Host "GCPW uninstalled successfully."
        # Add a brief pause to allow system processes to settle after uninstall
        Start-Sleep -Seconds 15
    } else {
        Write-Host "No existing GCPW package found to uninstall."
    }
}
catch {
    Write-Host "Warning: Could not uninstall the existing GCPW package. It may require manual removal. Details: $_"
}

# Remove the GCPW registry key to ensure a clean configuration
$registryPath = 'HKEY_LOCAL_MACHINE\Software\Google\GCPW'
if (Test-Path $registryPath) {
    Write-Host "Removing old GCPW registry configuration..."
    Remove-Item -Path $registryPath -Recurse -Force -ErrorAction SilentlyContinue
}

# Remove the old installer file if it exists
$oldInstallerPath = 'C:\Archive\gcpwstandaloneenterprise64.msi'
if (Test-Path $oldInstallerPath) {
    Write-Host "Removing old installer from C:\Archive..."
    Remove-Item -Path $oldInstallerPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Cleanup phase complete."

#======================================================================
# --- 2. Installation Phase: Perform a clean installation ---
#======================================================================

# Use the system's temp directory for the download
$tempPath = $env:TEMP
$installerName = "gcpwstandaloneenterprise64.msi"
$destinationFile = Join-Path -Path $tempPath -ChildPath $installerName
$logFile = Join-Path -Path $tempPath -ChildPath "gcpw_install.log"
$gcpwUrl = 'https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi'

# Download the GCPW installer
Write-Host "Downloading GCPW to $destinationFile..."
try {
    Invoke-WebRequest -Uri $gcpwUrl -OutFile $destinationFile -ErrorAction Stop
    Write-Host "Download complete."
}
catch {
    Write-Host "Error: Failed to download GCPW. Details: $_"
    exit 1
}

# Run the GCPW installer and wait for it to finish. Added logging for troubleshooting.
Write-Host "Installing GCPW... Check log at $logFile"
$msiArgs = @(
    "/i"
    "`"$destinationFile`""
    "/qn" # Quiet installation with no UI
    "/L*v" # Log all verbose information
    "`"$logFile`""
)

try {
    # Use -Wait to pause the script until msiexec is done
    Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -ErrorAction Stop
    Write-Host "GCPW installation process finished."
}
catch {
    Write-Host "Error: GCPW installation failed. Check the log file: $logFile"
    exit 1
}

#======================================================================
# --- 3. Configuration Phase ---
#======================================================================

# Set the required registry key with the allowed domain
Write-Host "Setting allowed domain to '$domainsAllowedToLogin'..."
if (Test-Path $registryPath) {
    Set-ItemProperty -Path $registryPath -Name 'domains_allowed_to_login' -Value $domainsAllowedToLogin
    Write-Host "Configuration complete."
}
else {
    Write-Host "Error: Registry path '$registryPath' not found after installation. Install may have failed."
    exit 1
}

# Optional: Clean up the installer file from the temp directory
Remove-Item $destinationFile -ErrorAction SilentlyContinue

Write-Host "GCPW installation and configuration script completed successfully."
# A reboot is recommended after installation. Ensure your RMM is configured to reboot.
exit 0