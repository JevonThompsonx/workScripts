<# This script downloads Google Credential Provider for Windows from
https://tools.google.com/dlpage/gcpw/, then installs and configures it.#>

param(
    [string]$DomainsAllowedToLogin = "ashleyvance.com",
    [string]$DestinationFolder = "C:\Archive\gcpwstandaloneenterprise64.msi",
    [string]$GcpwUrl = "https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi",
    [int]$DownloadWaitSec = 0
)

$domainsAllowedToLogin = $DomainsAllowedToLogin

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

# Download the GCPW installer.
$destinationFolder = $DestinationFolder
$gcpwUrl = $GcpwUrl
Write-Host 'Downloading GCPW from' $gcpwUrl
Invoke-WebRequest -Uri $gcpwUrl -OutFile $destinationFolder
if ($DownloadWaitSec -gt 0) {
    Start-Sleep -Seconds $DownloadWaitSec
}

# Run the GCPW installer and wait for the installation to finish
Start-Process msiexec.exe -ArgumentList "/i `"$destinationFolder`" /qn /norestart" -Wait

# Set the required registry key with the allowed domain
$registryPath = 'HKEY_LOCAL_MACHINE\Software\Google\GCPW'
$name = 'domains_allowed_to_login'
[microsoft.win32.registry]::SetValue($registryPath, $name, $domainsAllowedToLogin)
$domains = Get-ItemPropertyValue HKLM:\Software\Google\GCPW -Name $name

# Exit code for RMM service
Write-Host 'Completed install'
exit 0
