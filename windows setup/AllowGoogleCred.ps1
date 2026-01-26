<#
This script downloads Google Credential Provider for Windows,
installs it, and configures the allowed login domain.

Version 3.0:
- Automatically uninstalls a previous version of GCPW if detected.
- Adds a registry fix to prevent the "black box" login screen issue.
- Correctly waits for the installer and does not exit the parent process.
#>

param(
    [string]$DomainsAllowedToLogin = "ashleyvance.com",
    [string]$DestinationFolder = "C:\Archive",
    [string]$GcpwUrl = "https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi"
)

# --- Configuration ---
$domainsAllowedToLogin = $DomainsAllowedToLogin
$destinationFolder = $DestinationFolder
$gcpwUrl = $GcpwUrl
# --- End of Configuration ---

$destinationFile = Join-Path $destinationFolder "gcpwstandaloneenterprise64.msi"
$registryPath = 'HKLM:\Software\Google\GCPW'

## 1. Uninstall Previous Version (if found)
Write-Host "Checking for existing GCPW installations..."
try {
    # Find the package. -ErrorAction Stop will trigger the catch block if not found.
    $gcpwPackage = Get-Package -Name "Google Credential Provider for Windows" -ErrorAction Stop
    
    if ($gcpwPackage) {
        Write-Host "Found previous version of GCPW. Uninstalling..."
        $gcpwPackage | Uninstall-Package -Force
        Write-Host "Previous version uninstalled successfully."
    }
}
catch {
    # This block runs if Get-Package throws an error (e.g., package not found)
    Write-Host "No previous version of GCPW found. Proceeding with new installation."
}

## 2. Download the GCPW installer
# Ensure the destination directory exists
if (-not (Test-Path -Path $destinationFolder)) {
    Write-Host "Creating directory: $destinationFolder"
    New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
}

Write-Host "Downloading GCPW from $gcpwUrl..."
Invoke-WebRequest -Uri $gcpwUrl -OutFile $destinationFile

## 3. Run the GCPW installer
# Install silently and WAIT for it to finish.
Write-Host "Installing GCPW silently..."
Start-Process msiexec.exe -ArgumentList "/i `"$destinationFile`" /qn /norestart" -Wait

## 4. Configure Registry Settings
Write-Host "Configuring required registry settings..."

# Ensure the registry path exists before trying to set a value
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}

# Set the allowed domain
Write-Host "Setting allowed login domain to '$domainsAllowedToLogin'..."
$domainKeyName = 'domains_allowed_to_login'
Set-ItemProperty -Path $registryPath -Name $domainKeyName -Value $domainsAllowedToLogin

# Apply the fix for the black box/rendering issue by disabling hardware acceleration
Write-Host "Applying fix for login screen rendering issue..."
$hwAccelKeyName = 'enable_hw_acceleration'
Set-ItemProperty -Path $registryPath -Name $hwAccelKeyName -Value 0 -Type DWord

Write-Host "Google Credential Provider installation and configuration complete."

# We do NOT use 'exit' here.
# The script will now end and correctly return control to the master script.
