# Set the directory containing the installation files
$INSTALL_DIR = "C:\Archive" # Base directory for installation files

# --- Log File Configuration ---
# Define the name of the log subfolder
$LOG_SUBFOLDER_NAME = "InstallLogs"
# Create the full path for the log folder
$LOG_FOLDER_PATH = Join-Path -Path $INSTALL_DIR -ChildPath $LOG_SUBFOLDER_NAME
# Generate a single timestamp for all logs created during this script run
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss" # e.g., 20250618_153623

# --- Pre-run Checks ---
# Check if the main installation directory exists
if (-Not (Test-Path -Path $INSTALL_DIR -PathType Container)) {
    Write-Error "Critical Error: Installation directory '$INSTALL_DIR' not found or is not a directory. Script will exit."
    Pause
    Exit 1
}

# Create the log folder if it doesn't exist
if (-Not (Test-Path -Path $LOG_FOLDER_PATH -PathType Container)) {
    try {
        New-Item -Path $LOG_FOLDER_PATH -ItemType Directory -Force -ErrorAction Stop | Out-Null
        Write-Output "Successfully created log folder: '$LOG_FOLDER_PATH'"
    }
    catch {
        Write-Error "Critical Error: Could not create log folder at '$LOG_FOLDER_PATH'. Please check permissions. Error: $($_.Exception.Message). Script will exit."
        Pause
        Exit 1
    }
}
else {
    Write-Output "Log folder already exists: '$LOG_FOLDER_PATH'"
}

Write-Output "Starting installation process from '$INSTALL_DIR'..."
Write-Output "Logs will be saved to: '$LOG_FOLDER_PATH'"
Write-Output ""

# --- Process Executable Files (.exe) ---
Write-Output "--- Processing Executable Files (.exe) ---"
$exeFiles = Get-ChildItem -Path $INSTALL_DIR -Filter *.exe -File
if ($exeFiles) {
    foreach ($exeItem in $exeFiles) {
        $exeFile = $exeItem.FullName
        $exeName = $exeItem.Name
        Write-Output "Attempting to execute: '$exeName'"
        try {
            Start-Process -FilePath $exeFile -Wait -ErrorAction Stop
            Write-Output "Finished executing: '$exeName'."
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Execution of '$exeName' completed with a non-zero exit code: $LASTEXITCODE. This may indicate a problem with this specific installer. The script will continue with other files."
            }
        }
        catch {
            Write-Error "Failed to start or execute '$exeName'. Error: $($_.Exception.Message). The script will attempt to process the next file."
        }
        Write-Output "" # Blank line for readability
    }
}
else {
    Write-Output "No .exe files found in '$INSTALL_DIR'."
}


Write-Output ""
Write-Output "--- Processing Windows Installer Packages (.msi) ---"
$msiFiles = Get-ChildItem -Path $INSTALL_DIR -Filter *.msi -File
if ($msiFiles) {
    foreach ($msiItem in $msiFiles) {
        $msiFile = $msiItem.FullName
        $msiName = $msiItem.Name
        $msiBaseName = $msiItem.BaseName # Name without extension

        $msiLogFileName = "msi_install_$($msiBaseName)_$($timestamp).log"
        $fullMsiLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $msiLogFileName

        Write-Output "Attempting to install: '$msiName'"
        Write-Output "MSI Log File will be: '$fullMsiLogPath'"

        $msiexecArguments = @(
            "/i", "`"$msiFile`"", # Install action and path to MSI (quoted)
            "/qn", # Quiet, no UI
            "/Liwe", # Logging options: Log Information, Warnings, Errors
            "`"$fullMsiLogPath`"" # Path to log file (quoted)
        )

        try {
            Start-Process -FilePath "msiexec.exe" -ArgumentList $msiexecArguments -Wait -ErrorAction Stop
            Write-Output "Finished installing: '$msiName'."
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
                Write-Warning "MSI installation for '$msiName' completed with exit code: $LASTEXITCODE. This may indicate a problem. Please check log: '$fullMsiLogPath'. The script will continue."
            }
            elseif ($LASTEXITCODE -eq 3010) {
                Write-Output "MSI installation for '$msiName' completed successfully and requires a reboot. The script will continue."
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-Output "MSI installation for '$msiName' completed successfully."
            }
        }
        catch {
            Write-Error "Failed to start MSI installation for '$msiName'. Error: $($_.Exception.Message). The script will attempt to process the next file."
        }
        Write-Output "" # Blank line for readability
    }
}
else {
    Write-Output "No .msi files found in '$INSTALL_DIR'."
}

Write-Output ""
Write-Output "--- Installing Winget (Windows Package Manager) ---"
$wingetLogFileName = "winget_install_$($timestamp).log"
$fullWingetLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $wingetLogFileName

# Check if winget is already installed
try {
    # Attempt to run a simple winget command
    & winget --version | Out-Null
    Write-Output "Winget is already installed. Skipping installation."
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
            # Using Start-Transcript to capture output of Add-AppxPackage if desired
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
        Write-Warning "The debloat script may not function as expected without Winget."
    }
}
Write-Output "" # Blank line for readability


Write-Output ""
Write-Output "--- Executing Online Debloat Script ---"
$debloatLogFileName = "debloat_script_$($timestamp).log"
$fullDebloatLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $debloatLogFileName

Write-Output "Attempting to run online debloat script from 'https://debloat.raphi.re/'."
Write-Output "Debloat script output will be logged to: '$fullDebloatLogPath'"

try {
    Start-Transcript -Path $fullDebloatLogPath -Append
    & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
    Stop-Transcript

    Write-Output "Online debloat script execution completed. Please check log for details: '$fullDebloatLogPath'"
}
catch {
    Stop-Transcript -ErrorAction SilentlyContinue # Ensure transcript is stopped even on error
    Write-Error "Failed to download or execute the online debloat script. Error: $($_.Exception.Message). Please check your internet connection or the script source."
}
Write-Output "" # Blank line for readability


Write-Output ""
Write-Output "Installation process completed. Review output for any warnings or errors."
Pause