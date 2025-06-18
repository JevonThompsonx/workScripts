<# This script downloads Google Credential Provider for Windows from
https://tools.google.com/dlpage/gcpw/, then installs and configures it.#>

$domainsAllowedToLogin = "ashleyvance.com"

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework

# Download the GCPW installer.
$destinationFolder = 'C:\Archive\gcpwstandaloneenterprise64.msi'
$gcpwUrl = 'https://dl.google.com/credentialprovider/gcpwstandaloneenterprise64.msi'
Write-Host 'Downloading GCPW from' $gcpwUrl
Invoke-WebRequest -Uri $gcpwUrl -OutFile $destinationFolder
Start-Sleep -Seconds 180

# Run the GCPW installer and wait for the installation to finish
msiexec.exe /i $destinationFolder /qn
Start-Sleep -Seconds 180

# Set the required registry key with the allowed domain
$registryPath = 'HKEY_LOCAL_MACHINE\Software\Google\GCPW'
$name = 'domains_allowed_to_login'
[microsoft.win32.registry]::SetValue($registryPath, $name, $domainsAllowedToLogin)
$domains = Get-ItemPropertyValue HKLM:\Software\Google\GCPW -Name $name

# Exit code for RMM service
Write-Host 'Completed install'
exit 0