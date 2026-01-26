param(
    [switch]$NoPause,
    [switch]$NonInteractive
)

if ($NonInteractive) {
    $NoPause = $true
}


# --- Configuration for Testing ---
$INSTALL_DIR = "C:\Archive" # Base directory for logs
$LOG_SUBFOLDER_NAME = "InstallLogs"
$LOG_FOLDER_PATH = Join-Path -Path $INSTALL_DIR -ChildPath $LOG_SUBFOLDER_NAME
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# --- Pre-run Checks for Log Folder (necessary for logging) ---
if (-Not (Test-Path -Path $INSTALL_DIR -PathType Container)) {
    Write-Warning "Installation directory '$INSTALL_DIR' not found. Creating it for log purposes."
    try {
        New-Item -Path $INSTALL_DIR -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Could not create base directory '$INSTALL_DIR'. Error: $($_.Exception.Message). Logging will be affected."
        # Continue without exiting, as this is just for testing the Winget install
    }
}

if (-Not (Test-Path -Path $LOG_FOLDER_PATH -PathType Container)) {
    try {
        New-Item -Path $LOG_FOLDER_PATH -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Successfully created log folder: '$LOG_FOLDER_PATH'"
    }
    catch {
        Write-Error "Critical Error: Could not create log folder at '$LOG_FOLDER_PATH'. Please check permissions. Error: $($_.Exception.Message). Script will exit."
        if (-not $NoPause) {
            Pause
        }
        Exit 1 # Exit if cannot create log folder for test
    }
}
else {
    Write-Output "Log folder already exists: '$LOG_FOLDER_PATH'"
}

Write-Output ""
Write-Output "--- Installing Winget (Windows Package Manager) ---"
$wingetLogFileName = "winget_install_test_$($timestamp).log" # Unique name for test log
$fullWingetLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $wingetLogFileName

# Check if winget is already installed
try {
    & winget --version | Out-Null
    Write-Output "Winget is already installed. Skipping installation for testing."
}
catch {
    Write-Output "Winget not found. Proceeding with installation."

    try {
        # Get the latest release information from GitHub API
        $githubApiUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        Write-Output "Fetching latest Winget release information from '$githubApiUrl'..."
        $releaseInfo = Invoke-RestMethod -Uri $githubApiUrl -ErrorAction Stop

        # Find the .msixbundle asset
        $msixbundleAsset = $releaseInfo.assets | Where-Object { $_.name -like "*.msixbundle" }

        if ($msixbundleAsset) {
            $downloadUrl = $msixbundleAsset.browser_download_url
            $wingetFileName = $msixbundleAsset.name
            $tempWingetPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $wingetFileName

            Write-Output "Found Winget release: $($releaseInfo.tag_name)"
            Write-Output "Downloading Winget from: '$downloadUrl'"

            # Download the .msixbundle file
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempWingetPath -ErrorAction Stop

            Write-Output "Successfully downloaded Winget to: '$tempWingetPath'"

            # Install the .msixbundle
            Write-Output "Installing Winget..."
            Start-Transcript -Path $fullWingetLogPath -Append
            Add-AppxPackage -Path $tempWingetPath -ErrorAction Stop
            Stop-Transcript

            Write-Output "Winget installation completed. Check log for details: '$fullWingetLogPath'"

            # Clean up the downloaded file
            Remove-Item -Path $tempWingetPath -Force -ErrorAction SilentlyContinue | Out-Null
            Write-Output "Cleaned up temporary Winget file: '$tempWingetPath'"
        }
        else {
            Write-Error "Could not find a .msixbundle asset in the latest Winget release. Winget installation skipped."
        }
    }
    catch {
        Stop-Transcript -ErrorAction SilentlyContinue # Ensure transcript is stopped on error
        Write-Error "Failed to install Winget. Error: $($_.Exception.Message). Check internet connection or permissions."
        Write-Warning "Winget installation failed during testing."
    }
}
Write-Output "" # Blank line for readability
Write-Output "Winget installation test completed. Press any key to continue..."
if (-not $NoPause) {
    Pause
}
