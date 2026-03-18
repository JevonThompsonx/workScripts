#Requires -RunAsAdministrator

param(
    [switch]$RunDebloat,
    [switch]$SkipDebloatPrompt,
    [switch]$NoPause,
    [switch]$NonInteractive
)

if ($NonInteractive) {
    $NoPause = $true
    if (-not $RunDebloat) {
        $SkipDebloatPrompt = $true
    }
}

# Set the directory containing the installation files
$INSTALL_DIR = "C:\Archive" # Base directory for installation files

# Verify Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    if (-not $NoPause) {
        Pause
    }
    Exit 1
}

# --- Log File Configuration ---
# Define the name of the log subfolder
$LOG_SUBFOLDER_NAME = "InstallLogs"
# Create the full path for the log folder
$LOG_FOLDER_PATH = Join-Path -Path $INSTALL_DIR -ChildPath $LOG_SUBFOLDER_NAME
# Generate a single timestamp for all logs created during this script run
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss" # e.g., 20250509_083600

# --- Pre-run Checks ---
# Check if the main installation directory exists
if (-Not (Test-Path -Path $INSTALL_DIR -PathType Container)) {
    Write-Error "Critical Error: Installation directory '$INSTALL_DIR' not found or is not a directory. Script will exit."
    if (-not $NoPause) {
        Pause
    }
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
        if (-not $NoPause) {
            Pause
        }
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
            # Start the .exe file and wait for it to complete
            # -ErrorAction Stop ensures that if Start-Process itself fails (e.g., cannot find file), it's caught by the catch block.
            Start-Process -FilePath $exeFile -Wait -ErrorAction Stop
            Write-Output "Finished executing: '$exeName'."
            # Check the exit code of the executed process
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Execution of '$exeName' completed with a non-zero exit code: $LASTEXITCODE. This may indicate a problem with this specific installer. The script will continue with other files."
            }
        }
        catch {
            # This catch block handles errors from Start-Process itself (e.g., file not found, access denied to start)
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
# Process Windows Installer Packages (.msi)
$msiFiles = Get-ChildItem -Path $INSTALL_DIR -Filter *.msi -File
if ($msiFiles) {
    foreach ($msiItem in $msiFiles) {
        $msiFile = $msiItem.FullName
        $msiName = $msiItem.Name
        $msiBaseName = $msiItem.BaseName # Name without extension

        # Construct the log file name with timestamp
        $msiLogFileName = "msi_install_$($msiBaseName)_$($timestamp).log"
        $fullMsiLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $msiLogFileName

        Write-Output "Attempting to install: '$msiName'"
        Write-Output "MSI Log File will be: '$fullMsiLogPath'"

        # Arguments for msiexec
        $msiexecArguments = @(
            "/i", "`"$msiFile`"", # Install action and path to MSI (quoted)
            "/qn", # Quiet, no UI
            "/Liwe", # Logging options: Log Information, Warnings, Errors
            "`"$fullMsiLogPath`"" # Path to log file (quoted)
        )

        try {
            # Use msiexec to install the .msi file silently
            # -ErrorAction Stop ensures that if Start-Process fails to launch msiexec.exe, it's caught.
            Start-Process -FilePath "msiexec.exe" -ArgumentList $msiexecArguments -Wait -ErrorAction Stop
            Write-Output "Finished installing: '$msiName'."
            # Check the exit code from msiexec
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
            # This catch block handles errors from Start-Process itself (e.g., msiexec.exe not found)
            Write-Error "Failed to start MSI installation for '$msiName'. Error: $($_.Exception.Message). The script will attempt to process the next file."
        }
        Write-Output "" # Blank line for readability
    }
}
else {
    Write-Output "No .msi files found in '$INSTALL_DIR'."
}

Write-Output ""
Write-Output "--- Optional: Online Debloat Script ---"
Write-Output "NOTICE: This step will download and execute an external script from 'https://debloat.raphi.re/'" -ForegroundColor Yellow
Write-Output "This is an OPTIONAL step. External scripts can pose security risks." -ForegroundColor Yellow
Write-Output ""

$shouldRunDebloat = $RunDebloat

if (-not $SkipDebloatPrompt -and -not $RunDebloat) {
    $runDebloat = Read-Host "Do you want to run the external debloat script? (y/N)"
    if ($runDebloat -eq "y" -or $runDebloat -eq "Y") {
        $shouldRunDebloat = $true
    }
}

if ($shouldRunDebloat) {
    $debloatLogFileName = "debloat_script_$($timestamp).log"
    $fullDebloatLogPath = Join-Path -Path $LOG_FOLDER_PATH -ChildPath $debloatLogFileName

    Write-Output "Attempting to run online debloat script from 'https://debloat.raphi.re/'."
    Write-Output "Debloat script output will be logged to: '$fullDebloatLogPath'"

    try {
        # Test if the URL is accessible before executing
        Write-Output "Testing connection to debloat script..."
        $testConnection = Invoke-WebRequest -Uri "https://debloat.raphi.re/" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

        if ($testConnection.StatusCode -eq 200) {
            # Download and execute the script, redirecting output to a log file
            Start-Transcript -Path $fullDebloatLogPath -Append
            & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
            Stop-Transcript

            Write-Output "Online debloat script execution completed. Please check log for details: '$fullDebloatLogPath'"
        }
        else {
            Write-Warning "Could not connect to debloat script. Skipping this step."
        }
    }
    catch {
        if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) {
            Stop-Transcript -ErrorAction SilentlyContinue # Ensure transcript is stopped even on error
        }
        Write-Error "Failed to download or execute the online debloat script. Error: $($_.Exception.Message)"
        Write-Warning "This could be due to network issues or the script being unavailable. Continuing with installation..."
    }
}
else {
    Write-Output "Skipping external debloat script as requested."
}
Write-Output "" # Blank line for readability


Write-Output ""
Write-Output "Installation process completed. Review output for any warnings or errors."
if (-not $NoPause) {
    Pause
}
