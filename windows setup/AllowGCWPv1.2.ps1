<#
This script downloads Google Credential Provider for Windows,
installs it, and configures the allowed login domain.
Version 2.0: Correctly waits for installer and does not exit the parent process.
#>

$domainsAllowedToLogin = "ashleyvance.com"
$destinationFolder = "C:\Archive"
$destinationFile = Join-Path $destinationFolder "gcpwstandaloneenterprise64.msi"
$gcpwUrl = 'https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi'

# Ensure the destination directory exists
if (-not (Test-Path -Path $destinationFolder)) {
    Write-Host "Creating directory: $destinationFolder"
    New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
}

# Download the GCPW installer
Write-Host "Downloading GCPW from $gcpwUrl..."
Invoke-WebRequest -Uri $gcpwUrl -OutFile $destinationFile

# Run the GCPW installer silently and WAIT for it to finish.
# This replaces the unreliable 'msiexec' and 'Start-Sleep' commands.
Write-Host "Installing GCPW silently..."
Start-Process msiexec.exe -ArgumentList "/i `"$destinationFile`" /qn /norestart" -Wait

# Set the required registry key with the allowed domain
Write-Host "Configuring allowed domain in registry..."
$registryPath = 'HKLM:\Software\Google\GCPW'
$name = 'domains_allowed_to_login'

# Ensure the registry path exists before trying to set a value
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
Set-ItemProperty -Path $registryPath -Name $name -Value $domainsAllowedToLogin

Write-Host "Google Credential Provider installation and configuration complete."

# We do NOT use 'exit' here.
# The script will now end and correctly return control to the master script.
