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

# Step 0: Initial Setup and Administrator Check
#----------------------------------------------------------------------------------------------------
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "         STARTING MASTER WORK SCRIPT AUTOMATION"
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""

# Verify the script is running in an elevated (Administrator) session.
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script requires Administrator privileges. Please re-launch in an elevated PowerShell session."
    # Pause for 5 seconds before exiting to allow user to read the message.
    Start-Sleep -Seconds 5
    exit
}
else {
    Write-Host "✔️ Administrator privileges confirmed." -ForegroundColor Green
}

# Bypass execution policy for the current process to ensure remote scripts can run.
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "✔️ Execution policy set to 'Bypass' for the current session." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "❌ Failed to set execution policy. Halting script."
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
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/setup_script_windows_settings1_3.ps1")))

    Write-Host "  -> Applying Google Credentials Provider settings..."
    & ([scriptblock]::Create((irm "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/AllowGCWPv1.2.ps1")))

    Write-Host "✔️ STEP 1 Complete: Windows Setup Scripts executed successfully." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "❌ An error occurred during Windows Setup. Please check the output above."
}


# Step 2: Cloning Egnyte Drives
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 2: Running Egnyte Drive Cloning Script..." -ForegroundColor Cyan

try {
    & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/drives/cloneDrives.ps1")))
    Write-Host "✔️ STEP 2 Complete: Egnyte Drive Cloning script executed." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "❌ An error occurred while cloning Egnyte drives."
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
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/Update-Egnyte-v1.5.ps1")))
        Write-Host "✔️ STEP 3 Complete: Egnyte installation script executed." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Error "❌ An error occurred while installing Egnyte."
    }
}
# If the package IS found, skip the installation.
else {
    Write-Host "✔️ Egnyte is already installed. Skipping this step." -ForegroundColor Green
    Write-Host ""
}


# Step 4: Install Software from C:\Archive (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 4: Installing Software from C:\Archive..." -ForegroundColor Cyan

$archivePath = "C:\Archive"
$minFileCount = 10
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1"

function Run-Archive-Install {
    try {
        Write-Host "  -> Running software installation script..." -ForegroundColor Green
        & ([scriptblock]::Create((irm $installScriptUrl)))
        Write-Host "✔️ STEP 4 Complete: Software installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "❌ An error occurred during the software installation."
    }
}

# Check if the archive folder exists and has more than the minimum number of files
if ((Test-Path -Path $archivePath) -and ((Get-ChildItem -Path $archivePath).Count -gt $minFileCount)) {
    Write-Host "  -> Archive folder found with more than $minFileCount files. Proceeding with installation."
    Run-Archive-Install
}
else {
    Write-Host "  -> The C:\Archive folder does not exist or has 10 or fewer files." -ForegroundColor Yellow
    
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
# Step 4: Install Software from C:\Archive (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 5: Rmm install from C:\Archive\rmm..." -ForegroundColor Cyan

$archivePath = "C:\Archive"
$minFileCount = 10
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/rmm.ps1"

function Run-Archive-Install {
    try {
        Write-Host "  -> Running software installation script..." -ForegroundColor Green
        & ([scriptblock]::Create((irm $installScriptUrl)))
        Write-Host "✔️ STEP 4 Complete: Software installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "❌ An error occurred during the software installation."
    }
}
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "               MASTER SCRIPT FINISHED"
Write-Host "===========================================================" -ForegroundColor Cyan
# Pause at the end to allow the user to review the output.
Read-Host "Press Enter to close this window..."
