<#
.SYNOPSIS
    Stage 2: Installs the latest Egnyte Desktop App.
    Designed to be the second script in a two-part RMM/Intune deployment, run after a reboot.
.DESCRIPTION
    1. Creates a temporary directory.
    2. Downloads the specified Egnyte MSI installer.
    3. Installs the application with verbose logging for troubleshooting.
    4. Verifies the installation and cleans up.
#>

Write-Host "--- STAGE 2: EGNYTE PAVE SCRIPT INITIATED ---"

# --- Configuration ---
$downloadUrl_Msi = "https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/EgnyteConnectWin.msi" 
$localDirectory = "C:\EgnyteTempInstall"
$msiFileName = "EgnyteSetup.msi"
$localMsiPath = Join-Path -Path $localDirectory -ChildPath $msiFileName
$logPath = Join-Path -Path $localDirectory -ChildPath "Egnyte_Install.log"

# --- 1. Download ---
Write-Host "Step 1: Downloading new Egnyte installer..."
if (-not(Test-Path $localDirectory)) { New-Item -ItemType Directory -Path $localDirectory }
try {
    Invoke-WebRequest -Uri $downloadUrl_Msi -OutFile $localMsiPath -ErrorAction Stop
}
catch {
    Write-Error "CRITICAL: Failed to download the Egnyte installer. $_"
    exit 1
}

# --- 2. Install ---
Write-Host "Step 2: Installing Egnyte... See log at $logPath"
$msiArgs = @(
    "/i",
    "`"$localMsiPath`"",
    "/quiet",
    "/norestart",
    "/L*v", # IMPORTANT: Creates a verbose log for troubleshooting
    "`"$logPath`""
)

try {
    Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -ErrorAction Stop
    Write-Host "Installation process complete."
}
catch {
    Write-Error "CRITICAL: MSIExec failed to run. Check the log file if it was created. $_"
    exit 1
}

# --- 3. Verify ---
Write-Host "Step 3: Verifying Egnyte service..."
$service = Get-Service -Name "egnytefs" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    Write-Host "SUCCESS: Egnyte service is installed and running."
}
else {
    Write-Warning "VERIFY MANUALLY: Egnyte service not found or not running. Status: $($service.Status)"
}

# --- 4. Cleanup ---
Write-Host "Step 4: Cleaning up installer files..."
Remove-Item -Path $localDirectory -Recurse -Force -ErrorAction SilentlyContinue

exit 0