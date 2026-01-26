# BOLO - I have been modified for a new deployment method.

param(
    [switch]$NonInteractive,
    [string]$TargetDirectory = "C:\Archive\rmm",
    [string]$MsiPattern = "*-AV_*.msi",
    [int]$Selection = 1,
    [switch]$NoPause
)

# Main function to encapsulate the script's logic.
function Start-AgentDeployment {
    # Define the target directory and installer log path.
    $targetDirectory = $TargetDirectory
    # Create a unique log file name in the user's temp directory.
    $logPath = Join-Path $env:TEMP "MSI-Install-Log-$((Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')).log"
    $regexPattern = '^([^-]+)-AV' # Regex to capture the text before "-AV".

    # --- Directory and File Validation ---
    while (-not (Test-Path -Path $targetDirectory -PathType Container)) {
        Write-Host "ERROR: The folder at '$targetDirectory' was not found." -ForegroundColor Red
        if ($NonInteractive) {
            Write-Host "Non-interactive mode: exiting (missing directory)." -ForegroundColor Yellow
            return
        }
        $choice = Read-Host "Please ensure the MSI files are present. Do you want to try again? (y/n)"
        if ($choice.ToLower() -ne 'y') {
            # If the user enters anything other than 'y', exit the script.
            Write-Host "Exiting script." -ForegroundColor Yellow
            return # Exit the function
        }
    }

    # Get all .msi files matching the pattern *-AV_*.
    $files = Get-ChildItem -Path $targetDirectory -Filter $MsiPattern -File | Select-Object FullName, BaseName

    if ($null -eq $files) {
        Write-Host "No agent MSI files (*-AV_*.msi) were found in '$targetDirectory'." -ForegroundColor Yellow
        if (-not $NoPause) {
            Read-Host "Press Enter to exit."
        }
        return
    }

    # --- Display Menu and Get User Input ---
    Write-Host "Please select an agent MSI to install:" -ForegroundColor Cyan
    
    $selectionList = @()
    $i = 1
    foreach ($file in $files) {
        if ($file.BaseName -match $regexPattern) {
            $locationName = $Matches[1].Replace("_", " ")
            Write-Host "  $i. $locationName"
            $selectionList += [pscustomobject]@{ ID = $i; Location = $locationName; FullPath = $file.FullName }
            $i++
        }
    }

    if ($selectionList.Count -eq 0) {
        Write-Host "No files matched the expected naming convention to build the selection list." -ForegroundColor Yellow
        if (-not $NoPause) {
            Read-Host "Press Enter to exit."
        }
        return
    }

    # --- Process User Selection ---
    $selection = 0
    if ($NonInteractive) {
        $selection = $Selection
        if ($selection -lt 1 -or $selection -gt $selectionList.Count) {
            Write-Host "Non-interactive mode: selection $selection is invalid. Exiting." -ForegroundColor Yellow
            return
        }
    }
    else {
        while ($selection -lt 1 -or $selection -gt $selectionList.Count) {
            try {
                $input = Read-Host "Enter the number of your choice"
                $selection = [int]$input
                if ($selection -lt 1 -or $selection -gt $selectionList.Count) {
                    Write-Host "Invalid number. Please enter a number between 1 and $($selectionList.Count)." -ForegroundColor Red
                }
            }
            catch {
                Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
                $selection = 0
            }
        }
    }

    $chosenFile = $selectionList[$selection - 1]

    # --- Execute the MSI Installer ---
    Clear-Host
    Write-Host "You have selected: $($chosenFile.Location)" -ForegroundColor Green
    Write-Host "Preparing to install from: $($chosenFile.FullPath)"
    Write-Host "A detailed log will be saved to: $logPath"
    Write-Host "The installation will run silently in the background. Please wait..."

    # Arguments for a silent MSI installation
    # /i - Specifies the installer file
    # /qn - Quiet mode with no user interface
    # REBOOT=ReallySuppress - Prevents the installer from forcing a reboot
    # /L*v - Creates a verbose log file at the specified path
    $msiArgs = @(
        "/i",
        "`"$($chosenFile.FullPath)`"",
        "/qn",
        "REBOOT=ReallySuppress",
        "/L*v",
        "`"$logPath`""
    )

    try {
        # Use Start-Process for robust execution. The -Wait flag makes the script
        # pause until the installation process is complete.
        Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -Verb RunAs -ErrorAction Stop

        Write-Host "--------------------------------------------------------" -ForegroundColor Gray
        Write-Host "Installation process for '$($chosenFile.Location)' has completed." -ForegroundColor Green
        Write-Host "Please check the log file for details and to confirm success."
        # Optional: Open the log file for the user automatically.
        # Invoke-Item $logPath
    }
    catch {
        Write-Host "--------------------------------------------------------" -ForegroundColor Gray
        Write-Host "An error occurred while trying to start the installation." -ForegroundColor Red
        Write-Host "Error details: $($_.Exception.Message)"
        Write-Host "Check that you are running PowerShell as an Administrator."
    }
}

# --- Script Entry Point ---
Clear-Host
# Check if the script is running with Administrator privileges
if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "This script requires Administrator privileges to install software."
    Write-Warning "Please re-run this PowerShell session as an Administrator."
    if (-not $NoPause) {
        Read-Host "Press Enter to exit."
    }
    exit
}

Start-AgentDeployment

Write-Host ""
if (-not $NoPause) {
    Read-Host "Script finished. Press Enter to exit."
}
