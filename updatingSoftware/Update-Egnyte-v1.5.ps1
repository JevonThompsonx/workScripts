## v1.5 - 2025-05-29
# Added pre-flight check for running applications
# This script only works for .msi files.
# It will download the file, install it, and then clean up the installer file.
# It will check for running applications.
# --- Configuration ---
$downloadUrl = "https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/3.25.1/EgnyteDesktopApp_3.25.1_161.msi"
$localDirectory = "C:\Archive"
$fileName = "EgnyteSetup.msi"
$localPath = Join-Path -Path $localDirectory -ChildPath $fileName # Safely combines path and filename

# --- [NEW] Pre-Flight Check for Running Applications ---
Write-Host "Performing pre-flight check for open applications..."

# Add the process names (without .exe) of critical apps that use Egnyte
$criticalProcesses = @(
    "WINWORD", # Microsoft Word
    "EXCEL", # Microsoft Excel
    "POWERPNT", # Microsoft PowerPoint
    "OUTLOOK", # Microsoft Outlook (can lock files via attachments)
    "acad", # For AutoCAD / Civil 3D
    "Vectorworks",
    "Vectorworks2024",
    "Vectorworks2025",
    "Vectorworks2020",
    "Vectorworks2021",
    "Vectorworks2022",
    "Vectorworks2023",
    "Vectorworks2024",
    "PDFXchange", # For PDF-XChange Editor
    "PDFXEdit",
    "ENERCALC",
    "ETABS",
    "Revu",
    "risa3dw"
    
    # Add any other relevant application process names here
)

# Check if any of the critical processes are running
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
# --- [END NEW SECTION] ---


# --- Script Logic ---

# Create the destination directory if it doesn't exist
if (-not (Test-Path -Path $localDirectory)) {
    New-Item -ItemType Directory -Path $localDirectory | Out-Null
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
    "`"$localPath`"" 
    "/quiet"
    "/norestart"
)

try {
    Start-Process msiexec -ArgumentList $msiArgs -Wait -NoNewWindow
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
