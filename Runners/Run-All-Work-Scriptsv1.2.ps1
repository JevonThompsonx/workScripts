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
    Author: Jevon Thompson
    Date: 2025-07-22
    Version: 1.5
    Changes in 1.5:
        - Replaced all scriptblock-based remote execution ([scriptblock]::Create + irm) with
          Invoke-RemoteScript, which downloads to a temp file and runs as a child powershell.exe
          process. This prevents 'exit' calls in subscripts from terminating the main session
          (was causing Steps 3-6 to never execute when cloneDrives.ps1 hit a 404 and called exit).
        - No aliases: replaced irm with Invoke-WebRequest throughout.
    Changes in 1.4:
        - All catch blocks now emit $_.Exception.Message and $_.ScriptStackTrace for full error visibility.
        - Removed silent failure patterns across Steps 1-6.
#>

#====================================================================================================
# SCRIPT START
#====================================================================================================

param(
    [switch]$NonInteractive,
    [switch]$SkipArchiveInstall,
    [switch]$SkipDebloat,
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

if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "[ERROR] This script requires Administrator privileges!"
    Write-Warning "Please right-click PowerShell and select 'Run as Administrator', then try again."
    if (-not $NonInteractive) {
        Start-Sleep -Seconds 10
    }
    exit 1
}
else {
    Write-Host "[OK] Administrator privileges confirmed." -ForegroundColor Green
}

try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    Write-Host "[OK] Execution policy set to 'Bypass' for the current session." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] Failed to set execution policy: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Start-Sleep -Seconds 5
    exit
}


#----------------------------------------------------------------------------------------------------
# Helper: Download a remote .ps1 and run it as a child process
# Running as a child process isolates 'exit' calls in subscripts so they cannot
# terminate this session.  The temp file is always removed in the finally block.
#----------------------------------------------------------------------------------------------------
function Invoke-RemoteScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [string[]]$ScriptArgs = @()
    )
    $tempScript = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), '.ps1')
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tempScript -UseBasicParsing -ErrorAction Stop
        & powershell.exe -ExecutionPolicy Bypass -File $tempScript @ScriptArgs
    }
    finally {
        if (Test-Path -Path $tempScript) {
            Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
}


# Step 1: Running Windows Setup Scripts
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 1: Running Windows Setup Scripts..." -ForegroundColor Cyan

try {
    Write-Host "  -> Enabling Administrator Account..."
    $batUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/Accounts/enable_admin.bat"
    $tempBatFile = Join-Path $env:TEMP "enable_admin.bat"
    Invoke-WebRequest -Uri $batUrl -OutFile $tempBatFile -ErrorAction Stop
    & $tempBatFile
    Remove-Item $tempBatFile -Force

    Write-Host "  -> Configuring Windows Settings (Dark Mode, Power Plan, UAC)..."
    if ($NonInteractive) {
        Invoke-RemoteScript -Url "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/Configuration/setup_script_windows_settings1_3.ps1" -ScriptArgs @('-NoPause')
    }
    else {
        Invoke-RemoteScript -Url "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/Configuration/setup_script_windows_settings1_3.ps1"
    }

    Write-Host "  -> Applying Google Credentials Provider settings..."
    Invoke-RemoteScript -Url "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/Accounts/AllowGoogleCred.ps1"

    Write-Host "[OK] STEP 1 Complete: Windows Setup Scripts executed successfully." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] An error occurred during Windows Setup: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "Continuing to next step..." -ForegroundColor Yellow
    Write-Host ""
}


# Step 1.5: Laptop-Specific Power Settings
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 1.5: Configuring Laptop-Specific Power Settings..." -ForegroundColor Cyan

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
    Write-Warning "Could not detect device type: $($_.Exception.Message). Assuming desktop."
}

if ($isLaptop) {
    Write-Host "  -> Configuring lid close action for laptops..."
    try {
        $activePlan = (Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }).InstanceID
        $planGuid = ($activePlan -split '[{}]')[1]

        $lidSubGroup      = "4f971e89-eebd-4455-a8de-9e59040e7347"
        $lidCloseSetting  = "5ca83367-6e45-459f-a27b-476b1d01c936"

        powercfg -setacvalueindex $planGuid $lidSubGroup $lidCloseSetting 0
        Write-Host "  -> Lid close action set to 'Do Nothing' when on AC power." -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not configure lid close action: $($_.Exception.Message)"
    }
}

Write-Host "  -> Checking power plan configuration..."
try {
    $highPerfPlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.ElementName -like '*High performance*' }
    $activePlan   = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }

    if (-not $highPerfPlan) {
        Write-Host "  -> High Performance power plan not available. Adjusting screen and sleep settings..." -ForegroundColor Yellow

        $planGuid = ($activePlan.InstanceID -split '[{}]')[1]

        $displaySubGroup      = "7516b95f-f776-4464-8c53-06167f40cc99"
        $screenTimeoutSetting = "3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e"
        $sleepSubGroup        = "238c9fa8-0aad-41ed-83f4-97be242c8f20"
        $sleepTimeoutSetting  = "29f6c1db-86da-48c5-9fdb-f2b67b1f44da"

        powercfg -setacvalueindex $planGuid $displaySubGroup $screenTimeoutSetting 1800
        powercfg -setdcvalueindex $planGuid $displaySubGroup $screenTimeoutSetting 1800
        Write-Host "  -> Screen timeout set to 30 minutes." -ForegroundColor Green

        powercfg -setacvalueindex $planGuid $sleepSubGroup $sleepTimeoutSetting 0
        powercfg -setdcvalueindex $planGuid $sleepSubGroup $sleepTimeoutSetting 0
        Write-Host "  -> Sleep timeout set to 'Never'." -ForegroundColor Green

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
    Invoke-RemoteScript -Url "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/Networking/cloneDrives.ps1"
    Write-Host "[OK] STEP 2 Complete: Egnyte Drive Cloning script executed." -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Error "[ERROR] An error occurred while cloning Egnyte drives: $($_.Exception.Message)"
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "Verify that https://github.com/JevonThompsonx/workScripts exists, is public, and the path is correct." -ForegroundColor Yellow
    Write-Host "Continuing to next step..." -ForegroundColor Yellow
    Write-Host ""
}


# Step 3: Installing Egnyte Software (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 3: Checking Egnyte Software Status..." -ForegroundColor Cyan

$egnyteApp = Get-Package -Name "Egnyte*" -ErrorAction SilentlyContinue

if (-not $egnyteApp) {
    Write-Host "  -> Egnyte not found. Proceeding with installation..."
    try {
        if ($NonInteractive) {
            Invoke-RemoteScript -Url "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/Install/updatingSoftware/Update-Egnyte-v1.5.ps1" -ScriptArgs @('-NoPause')
        }
        else {
            Invoke-RemoteScript -Url "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/Install/updatingSoftware/Update-Egnyte-v1.5.ps1"
        }
        Write-Host "[OK] STEP 3 Complete: Egnyte installation script executed." -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Error "[ERROR] An error occurred while installing Egnyte: $($_.Exception.Message)"
        Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
        Write-Host "Continuing to next step..." -ForegroundColor Yellow
        Write-Host ""
    }
}
else {
    Write-Host "[OK] Egnyte is already installed. Skipping this step." -ForegroundColor Green
    Write-Host ""
}


# Step 4: Install Software from C:\Archive (Conditional)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 4: Installing Software from C:\Archive..." -ForegroundColor Cyan

$archivePath      = "C:\Archive"
$minFileCount     = $MinArchiveFileCount
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/Install/installAllArchiveSoftwarev2.6.ps1"

function Run-Archive-Install {
    try {
        Write-Host "  -> Running software installation script..." -ForegroundColor Green
        Invoke-RemoteScript -Url $installScriptUrl -ScriptArgs @('-SkipDebloatPrompt', '-NoPause')
        Write-Host "[OK] STEP 4 Complete: Software installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] An error occurred during the software installation: $($_.Exception.Message)"
        Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

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
        while ($true) {
            $choice = Read-Host "  -> Please add files to C:\Archive now. Press 'y' to continue with installation, or 'n' to exit the script"

            if ($choice -eq 'y') {
                if ((Test-Path -Path $archivePath) -and ((Get-ChildItem -Path $archivePath).Count -gt $minFileCount)) {
                    Write-Host "  -> Condition now met. Proceeding with installation." -ForegroundColor Green
                    Run-Archive-Install
                    break
                }
                else {
                    Write-Warning "  -> The archive folder is still not ready. Exiting script."
                    break
                }
            }
            elseif ($choice -eq 'n') {
                Write-Host "  -> Exiting script as requested. The software installation was skipped." -ForegroundColor Yellow
                break
            }
            else {
                Write-Warning "  -> Invalid input. Please press 'y' to continue or 'n' to exit."
            }
        }
    }
}


# Step 5: Windows Debloat (Raphire Win11Debloat)
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 5: Running Windows Debloat (Raphire)..." -ForegroundColor Cyan

if ($SkipDebloat) {
    Write-Host "  -> Skipping debloat step as requested." -ForegroundColor Yellow
}
else {
    Write-Host "  -> Running Raphire Win11Debloat with default settings..." -ForegroundColor Green
    try {
        Invoke-RemoteScript -Url "https://debloat.raphi.re/" -ScriptArgs @('-RunDefaults', '-Silent')
        Write-Host "[OK] STEP 5 Complete: Raphire Debloat completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] An error occurred while running Raphire Debloat: $($_.Exception.Message)"
        Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
        Write-Host "Continuing to next step..." -ForegroundColor Yellow
    }
}


# Step 6: Install RMM from C:\Archive\rmm
#----------------------------------------------------------------------------------------------------
Write-Host "STEP 6: RMM install from C:\Archive\rmm..." -ForegroundColor Cyan

$rmmPath          = $RmmTargetDirectory
$installScriptUrl = "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/Accounts/rmm.ps1"

function Run-RMM-Install {
    try {
        Write-Host "  -> Running RMM installation script..." -ForegroundColor Green
        if ($NonInteractive) {
            Invoke-RemoteScript -Url $installScriptUrl -ScriptArgs @('-NonInteractive', '-TargetDirectory', $rmmPath, '-Selection', $RmmSelection, '-NoPause')
        }
        else {
            Invoke-RemoteScript -Url $installScriptUrl
        }
        Write-Host "[OK] STEP 6 Complete: RMM installation script executed." -ForegroundColor Green
    }
    catch {
        Write-Error "[ERROR] An error occurred during the RMM installation: $($_.Exception.Message)"
        Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    }
}

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

if (-not $NonInteractive) {
    Read-Host "Press Enter to close this window..."
}
