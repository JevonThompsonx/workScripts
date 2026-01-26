#Requires -RunAsAdministrator
<#
.SYNOPSIS
    A master script to orchestrate the setup of a Windows environment by running a series of configuration,
    software update, and drive mapping scripts from the workScripts GitHub repository.

.DESCRIPTION
    This script performs the following actions in sequence:
    1.  Verifies it is running with Administrator privileges.
    2.  Executes Windows setup scripts (Enable Admin, System Settings, Google Credentials).
    3.  Runs the script to clone Egnyte drives.
    4.  Checks if the Egnyte client is installed. If not, it runs the installation script.
    5.  Conditionally runs the software installation script from C:\Archive. It checks if C:\Archive
        exists and contains more than 10 files. If not, it prompts the user to add the files
        and provides an option to re-check and continue or to exit.

.NOTES
    Author: Jevon Thompson (Created by Gemini)
    Date: 2025-07-22
    Version: 1.2
#>

#====================================================================================================
# SCRIPT START
#====================================================================================================

param(
    [switch]$NonInteractive,
    [switch]$SkipArchiveInstall,
    [switch]$SkipDebloat,
    [switch]$RunRaphireDebloat,
    [switch]$RunEngineeringDebloat,
    [switch]$ConfirmEngineeringDebloat,
    [switch]$SkipRmmInstall,
    [int]$MinArchiveFileCount = 10,
    [string]$RmmTargetDirectory = "C:\Archive\rmm",
    [int]$RmmSelection = 1
)

# Step 0: Initial Setup and Administrator Check
#----------------------------------------------------------------------------------------------------
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "         STARTING MASTER WORK SCRIPT AUTOMATION"
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANT: Make sure you're running PowerShell as Administrator!" -ForegroundColor Yellow
Write-Host ""

# Verify the script is running in an elevated (Administrator) session.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "[ERROR] This script requires Administrator privileges!"
    Write-Warning "Please right-click PowerShell and select 'Run as Administrator', then try again."
    # Pause for 10 seconds before exiting to allow user to read the message.
    if (-not $NonInteractive) {
        Start-Sleep -Seconds 10
    }
    exit 1
}
else {
    Write-Host "[OK] Administrator privileges confirmed." -ForegroundColor Green
}

# Bypass execution policy for the current process to ensure remote scripts can run.
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "[OK] Execution policy set to 'Bypass' for the current session." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] Failed to set execution policy. Halting script."
    Start-Sleep -Seconds 5
    exit
}


# Step 1: Running Windows Setup Scripts
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 1: Running Windows Setup Scripts..." -ForegroundColor Cyan

try {
    Write-Host "  -> Enabling Administrator Account..."
    # For .bat files, we must download them first, then execute them.
    $batUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/enable_admin.bat"
    $tempBatFile = Join-Path $env:TEMP "enable_admin.bat"
    Invoke-WebRequest -Uri $batUrl -OutFile $tempBatFile
    & $tempBatFile
    Remove-Item $tempBatFile -Force

    Write-Host "  -> Configuring Windows Settings (Dark Mode, Power Plan, UAC)..."
    if ($NonInteractive) {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/setup_script_windows_settings1_3.ps1"))) -NoPause
    }
    else {
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/setup_script_windows_settings1_3.ps1")))
    }

    Write-Host "  -> Applying Google Credentials Provider settings..."
    & ([scriptblock]::Create((irm "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/AllowGoogleCred.ps1")))

    Write-Host "[OK] STEP 1 Complete: Windows Setup Scripts executed successfully." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] An error occurred during Windows Setup. Please check the output above."
}


# Step 1.5: Laptop-Specific Power Settings
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 1.5: Configuring Laptop-Specific Power Settings..." -ForegroundColor Cyan

# Detect if the device is a laptop by checking for the presence of a battery
$isLaptop = $false
try {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $isLaptop = $true
        Write-Host "  -> Laptop detected (battery found)." -ForegroundColor Green
    }
    else {
        Write-Host "  -> Desktop/workstation detected (no battery found). Skipping laptop-specific settings." -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Could not detect device type. Assuming desktop."
}

if ($isLaptop) {
    # Configure lid close action to "Do Nothing" when on AC power
    Write-Host "  -> Configuring lid close action for laptops..."
    try {
        # Get the active power plan GUID
        $activePlan = (Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }).InstanceID
        $planGuid = ($activePlan -split '[{}]')[1]

        # Lid close action settings
        # Sub-group GUID for "Power buttons and lid"
        $lidSubGroup = "4f971e89-eebd-4455-a8de-9e59040e7347"
        # Setting GUID for "Lid close action"
        $lidCloseSetting = "5ca83367-6e45-459f-a27b-476b1d01c936"
        # Value 0 = Do Nothing, 1 = Sleep, 2 = Hibernate, 3 = Shut down

        # Set lid close action to "Do Nothing" (0) when plugged in (AC)
        powercfg -setacvalueindex $planGuid $lidSubGroup $lidCloseSetting 0
        Write-Host "  -> Lid close action set to 'Do Nothing' when on AC power." -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not configure lid close action: $($_.Exception.Message)"
    }
}

# Check if High Performance power plan exists and is active
Write-Host "  -> Checking power plan configuration..."
try {
    $highPerfPlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.ElementName -like '*High performance*' }
    $activePlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }

    if (-not $highPerfPlan) {
        Write-Host "  -> High Performance power plan not available. Adjusting screen and sleep settings..." -ForegroundColor Yellow

        # Get the active power plan GUID
        $planGuid = ($activePlan.InstanceID -split '[{}]')[1]

        # Display sub-group GUID
        $displaySubGroup = "7516b95f-f776-4464-8c53-06167f40cc99"
        # Screen timeout setting GUID
        $screenTimeoutSetting = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"

        # Sleep sub-group GUID
        $sleepSubGroup = "238c9fa8-0aad-41ed-83f4-97be242c8f20"
        # Sleep timeout setting GUID
        $sleepTimeoutSetting = "29f6c1db-86da-48c5-9fdb-f2b67b1f44da"

        # Set screen timeout to 30 minutes (1800 seconds) for both AC and DC
        powercfg -setacvalueindex $planGuid $displaySubGroup $screenTimeoutSetting 1800
        powercfg -setdcvalueindex $planGuid $displaySubGroup $screenTimeoutSetting 1800
        Write-Host "  -> Screen timeout set to 30 minutes." -ForegroundColor Green

        # Set sleep timeout to never (0) for both AC and DC
        powercfg -setacvalueindex $planGuid $sleepSubGroup $sleepTimeoutSetting 0
        powercfg -setdcvalueindex $planGuid $sleepSubGroup $sleepTimeoutSetting 0
        Write-Host "  -> Sleep timeout set to 'Never'." -ForegroundColor Green

        # Apply the changes
        powercfg -setactive $planGuid
    }
    else {
        Write-Host "  -> High Performance power plan detected. No additional timeout adjustments needed." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Could not configure power plan settings: $($_.Exception.Message)"
}

Write-Host "[OK] STEP 1.5 Complete: Laptop-specific power settings configured." -ForegroundColor Green
Write-Host ""


# Step 2: Cloning Egnyte Drives
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 2: Running Egnyte Drive Cloning Script..." -ForegroundColor Cyan

try {
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/drives/cloneDrives.ps1")))
    Write-Host "[OK] STEP 2 Complete: Egnyte Drive Cloning script executed." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] An error occurred while cloning Egnyte drives."
}


# Step 3: Installing Egnyte Software (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 3: Checking Egnyte Software Status..." -ForegroundColor Cyan

# Check if Egnyte is already installed by querying the package manager.
# -ErrorAction SilentlyContinue prevents red text if the app isn't found.
$egnyteApp = Get-Package -Name "Egnyte*" -ErrorAction SilentlyContinue

# If the package is NOT found ($egnyteApp is null), then run the installation script.
if (-not $egnyteApp) {
    Write-Host "  -> Egnyte not found. Proceeding with installation..."
    try {
        if ($NonInteractive) {
            & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/Update-Egnyte-v1.5.ps1"))) -NoPause
        }
        else {
            & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/Update-Egnyte-v1.5.ps1")))
        }
        Write-Host "[OK] STEP 3 Complete: Egnyte installation script executed." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Error "[ERROR] An error occurred while installing Egnyte."
    }
}
# If the package IS found, skip the installation.
else {
    Write-Host "[OK] Egnyte is already installed. Skipping this step." -ForegroundColor Green
    Write-Host ""
}


# Step 4: Install Software from C:\Archive (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 4: Installing Software from C:\Archive..." -ForegroundColor Cyan

$archivePath = "C:\Archive"
$minFileCount = $MinArchiveFileCount
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1"

function Run-Archive-Install {
    try {
        Write-Host "  -> Running software installation script..." -ForegroundColor Green
        & ([scriptblock]::Create((irm $installScriptUrl))) -SkipDebloatPrompt -NoPause
        Write-Host "[OK] STEP 4 Complete: Software installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] An error occurred during the software installation."
    }
}

# Check if the archive folder exists and has more than the minimum number of files
if ($SkipArchiveInstall) {
    Write-Host "  -> Skipping archive software installation as requested." -ForegroundColor Yellow
}
elseif ((Test-Path -Path $archivePath) -and ((Get-ChildItem -Path $archivePath).Count -gt $minFileCount)) {
    Write-Host "  -> Archive folder found with more than $minFileCount files. Proceeding with installation."
    Run-Archive-Install
}
else {
    Write-Host "  -> The C:\Archive folder does not exist or has 10 or fewer files." -ForegroundColor Yellow

    if ($NonInteractive) {
        Write-Host "  -> Non-interactive mode: skipping archive software installation." -ForegroundColor Yellow
    }
    else {
        # Loop to prompt the user for action
        while ($true) {
            $choice = Read-Host "  -> Please add files to C:\Archive now. Press 'y' to continue with installation, or 'n' to exit the script"

            if ($choice -eq 'y') {
                # Re-check the condition after user intervention
                if ((Test-Path -Path $archivePath) -and ((Get-ChildItem -Path $archivePath).Count -gt $minFileCount)) {
                    Write-Host "  -> Condition now met. Proceeding with installation." -ForegroundColor Green
                    Run-Archive-Install
                    break # Exit the while loop
                }
                else {
                    Write-Warning "  -> The archive folder is still not ready. Exiting script."
                    break # Exit the while loop
                }
            }
            elseif ($choice -eq 'n') {
                Write-Host "  -> Exiting script as requested. The software installation was skipped." -ForegroundColor Yellow
                break # Exit the while loop
            }
            else {
                Write-Warning "  -> Invalid input. Please press 'y' to continue or 'n' to exit."
            }
        }
    }
}

# Step 5: Windows Debloat (User Choice)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 5: Windows Debloat Options..." -ForegroundColor Cyan

Write-Host "You can choose to run one of the following debloat scripts:" -ForegroundColor Yellow
Write-Host "  1. Raphire Debloat (https://debloat.raphi.re/)" -ForegroundColor Gray
Write-Host "  2. Engineering Debloat (for engineering workflows)" -ForegroundColor Gray
Write-Host "  3. Skip (do not run any debloat)" -ForegroundColor Gray

if ($SkipDebloat) {
    Write-Host "  -> Skipping debloat step as requested." -ForegroundColor Yellow
}
elseif ($NonInteractive) {
    if ($RunEngineeringDebloat) {
        Write-Host "  -> Running Engineering Debloat..." -ForegroundColor Green
        try {
            if ($ConfirmEngineeringDebloat) {
                & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/engineeringDebloat.ps1"))) -NonInteractive -Mode All -ConfirmRemoval -NoPause
                Write-Host "[OK] Engineering Debloat completed successfully." -ForegroundColor Green
            }
            else {
                Write-Warning "Non-interactive mode: set -ConfirmEngineeringDebloat to proceed. Skipping."
            }
        }
        catch {
            Write-Error "[ERROR] An error occurred while running Engineering Debloat."
        }
    }
    elseif ($RunRaphireDebloat) {
        Write-Host "  -> Running Raphire Debloat..." -ForegroundColor Green
        try {
            & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
            Write-Host "[OK] Raphire Debloat completed successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "[ERROR] An error occurred while running Raphire Debloat."
        }
    }
    else {
        Write-Host "  -> Non-interactive mode: no debloat option specified. Skipping." -ForegroundColor Yellow
    }
}
else {
    while ($true) {
        $debloatChoice = Read-Host "Please enter 1 (Basic), 2 (Engineering), or 3 (Skip)"

        switch ($debloatChoice) {
            '1' {
                Write-Host "  -> Running Raphire Debloat..." -ForegroundColor Green
                try {
                    & ([scriptblock]::Create((irm "https://debloat.raphi.re/")))
                    Write-Host "[OK] Raphire Debloat completed successfully." -ForegroundColor Green
                }
                catch {
                    Write-Error "[ERROR] An error occurred while running Raphire Debloat."
                }
                break
            }
            '2' {
                Write-Host "  -> Running Engineering Debloat..." -ForegroundColor Green
                try {
                    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/engineeringDebloat.ps1")))
                    Write-Host "[OK] Engineering Debloat completed successfully." -ForegroundColor Green
                }
                catch {
                    Write-Error "[ERROR] An error occurred while running Engineering Debloat."
                }
                break
            }
            '3' {
                Write-Host "  -> Skipping debloat step as requested." -ForegroundColor Yellow
                break
            }
            default {
                Write-Warning "Invalid input. Please enter 1, 2, or 3."
            }
        }
    }
}

# Step 6: Install RMM from C:\Archive\rmm
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 6: RMM install from C:\Archive\rmm..." -ForegroundColor Cyan

$rmmPath = $RmmTargetDirectory
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/rmm.ps1"

function Run-RMM-Install {
    try {
        Write-Host "  -> Running RMM installation script..." -ForegroundColor Green
        if ($NonInteractive) {
            & ([scriptblock]::Create((irm $installScriptUrl))) -NonInteractive -TargetDirectory $rmmPath -Selection $RmmSelection -NoPause
        }
        else {
            & ([scriptblock]::Create((irm $installScriptUrl)))
        }
        Write-Host "[OK] STEP 6 Complete: RMM installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] An error occurred during the RMM installation."
    }
}

# Check if RMM folder exists before attempting install
if ($SkipRmmInstall) {
    Write-Host "  -> Skipping RMM installation as requested." -ForegroundColor Yellow
}
elseif (Test-Path -Path $rmmPath) {
    Write-Host "  -> RMM folder found. Proceeding with installation."
    Run-RMM-Install
}
else {
    Write-Host "  -> RMM folder not found at $rmmPath. Skipping RMM installation." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "               MASTER SCRIPT FINISHED"
Write-Host "===========================================================" -ForegroundColor Cyan
# Pause at the end to allow the user to review the output.
if (-not $NonInteractive) {
    Read-Host "Press Enter to close this window..."
}
