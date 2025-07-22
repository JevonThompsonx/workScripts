<#
.SYNOPSIS
    A comprehensive Windows 11 setup, debloat, and privacy script.

.DESCRIPTION
    This script performs a wide range of system configurations to optimize performance,
    enhance privacy, and create a cleaner user experience. It requires Administrator
    privileges to execute correctly.

    IMPORTANT:
    - Run this script as an Administrator.
    - It is highly recommended to create a System Restore Point before executing.
    - Review the script and comment out (#) any changes you do not want.

    KEY ACTIONS PERFORMED:
    - System Performance: Sets High Performance power plan, disables hibernation and USB selective suspend.
    - Security & Privacy: Disables UAC (reboot required) and various telemetry/tracking features.
    - Bloatware Removal: Uninstalls a wide range of pre-installed apps, including Teams and OneDrive.
    - UI & UX Customization:
        - Enables Dark Mode and the classic Windows 10 context menu.
        - Shows file extensions and the 'This PC' desktop icon.
        - Customizes the taskbar: Removes default pins (Edge, Chat, Widgets), disables Copilot, and pins Chrome.
    - File System: Creates a C:\Archive directory and specific system files.
    - Finalization: Restarts the Windows Explorer shell to apply UI changes, causing the screen to flash.

.NOTES
    Author: Gemini (Google AI), Jevon Thompson
    Date: July 22, 2025
    Requires: Windows PowerShell, Administrator privileges.
#>

#Requires -RunAsAdministrator

#===================================================================================================
# SCRIPT INITIALIZATION
#===================================================================================================

# Step 1: Check for Administrator Privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Administrator rights required. Please re-run this script as an Administrator."
    Read-Host "Press Enter to exit..."
    exit
}

Write-Host "Administrator privileges confirmed. Starting comprehensive setup script..." -ForegroundColor Green
Start-Sleep -Seconds 2

# Step 2: Helper Functions for Taskbar Customization
function Remove-TaskbarPin {
    param([string]$AppName)
    try {
        $verb = "Unpin from taskbar"
        # Access the pinned items via the Shell.Application object for broader compatibility
        $shell = New-Object -ComObject Shell.Application
        $taskbar = $shell.Namespace("shell:::{0D44E104-A02A-45D6-8554-1488AD504363}")
        $pinnedItem = $taskbar.Items() | Where-Object { $_.Name -eq $AppName }
        
        if ($pinnedItem) {
            $pinnedItem.Verbs() | Where-Object { $_.Name -eq $verb } | ForEach-Object { $_.DoIt() }
            Write-Host "Successfully unpinned '$AppName' from the taskbar." -ForegroundColor Green
        } else {
            Write-Host "'$AppName' is not currently pinned or could not be found by that name."
        }
    } catch { Write-Warning "An error occurred while trying to unpin '$AppName': $($_.Exception.Message)" }
}

function Add-TaskbarPin {
    param([string]$AppPath)
    if (-not (Test-Path $AppPath)) {
        Write-Warning "Cannot pin application. Path not found: $AppPath"
        return
    }
    try {
        $verb = "Pin to taskbar"
        $shell = New-Object -ComObject Shell.Application
        $folderPath = Split-Path $AppPath -Parent
        $fileName = Split-Path $AppPath -Leaf
        $folder = $shell.Namespace($folderPath)
        $item = $folder.ParseName($fileName)
        if ($item.Verbs() | Where-Object { $_.Name.Replace('&','') -eq $verb }) {
            $item.Verbs() | Where-Object { $_.Name.Replace('&','') -eq $verb } | ForEach-Object { $_.DoIt() }
            Write-Host "Successfully pinned '$fileName' to the taskbar." -ForegroundColor Green
        }
    } catch { Write-Warning "An error occurred while trying to pin '$fileName': $($_.Exception.Message)" }
}


#===================================================================================================
# SECTION 1: SYSTEM PERFORMANCE & POWER CONFIGURATION
#---------------------------------------------------------------------------------------------------
Write-Host "`n[SECTION 1] Applying Performance & Power Tweaks..." -ForegroundColor Cyan

# Set High Performance Power Plan
Write-Host " - Setting High Performance Power Plan..."
try {
    $highPerformancePlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.ElementName -like '*High performance*' } | Select-Object -First 1
    if ($highPerformancePlan) {
        $planGuidOnly = ($highPerformancePlan.InstanceID -split '[{}]')[1]
        powercfg.exe /setactive $planGuidOnly
        Write-Host "   -> Activated High Performance power plan." -ForegroundColor Green
    } else { Write-Warning "   -> High Performance power plan not found."}
} catch { Write-Warning "   -> Error setting High Performance power plan: $($_.Exception.Message)" }

# Disable Hibernation
Write-Host " - Disabling Hibernation..."
try {
    powercfg.exe /hibernate off
    Write-Host "   -> Hibernation successfully disabled." -ForegroundColor Green
} catch { Write-Warning "   -> Error disabling hibernation: $($_.Exception.Message)" }

# Disable USB Selective Suspend
Write-Host " - Disabling USB Selective Suspend..."
try {
    $activePlan = (Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }).InstanceID
    $planGuid = ($activePlan -split '[{}]')[1]
    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSuspendSetting = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    powercfg -setacvalueindex $planGuid $usbSubGroup $usbSuspendSetting 0
    powercfg -setdcvalueindex $planGuid $usbSubGroup $usbSuspendSetting 0
    Write-Host "   -> USB Selective Suspend disabled for active power plan." -ForegroundColor Green
} catch { Write-Warning "   -> Error disabling USB Selective Suspend: $($_.Exception.Message)"}


#===================================================================================================
# SECTION 2: PRIVACY & SECURITY CONFIGURATION
#---------------------------------------------------------------------------------------------------
Write-Host "`n[SECTION 2] Applying Privacy & Security Tweaks..." -ForegroundColor Cyan

# Disable User Account Control (UAC)
Write-Host " - Disabling User Account Control (UAC)..."
Write-Warning "   *** SECURITY WARNING: Disabling UAC significantly reduces system security. ***"
Write-Warning "   *** A system REBOOT is REQUIRED for this change to take effect! ***"
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 0 -Type DWORD -Force
    Write-Host "   -> UAC successfully disabled in registry." -ForegroundColor Green
} catch { Write-Warning "   -> Error disabling UAC: $($_.Exception.Message)" }

# Apply Telemetry and Privacy Tweaks
Write-Host " - Applying various privacy and telemetry tweaks..."
try {
    # Disable Telemetry
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Force -ErrorAction Stop
    # Disable Advertising ID for current user
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -Force -ErrorAction Stop
    # Disable Tailored experiences with diagnostic data
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" -Name "TailoredExperiencesWithDiagnosticDataEnabled" -Value 0 -Force -ErrorAction Stop
    # Disable feedback notifications
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "DoNotShowFeedbackNotifications" -Value 1 -Force -ErrorAction Stop
    Write-Host "   -> Privacy tweaks applied successfully." -ForegroundColor Green
} catch { Write-Warning "   -> An error occurred while applying privacy tweaks. Some settings may not apply." }


#===================================================================================================
# SECTION 3: BLOATWARE & APP REMOVAL
#---------------------------------------------------------------------------------------------------
Write-Host "`n[SECTION 3] Removing Bloatware and Unwanted Apps..." -ForegroundColor Cyan

# Part A: Remove built-in AppX packages
$BloatwareApps = @(
    "Microsoft.549981C3F5F10", "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp",
    "Microsoft.Getstarted", "Microsoft.HEIFImageExtension", "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal", "Microsoft.Office.OneNote", "Microsoft.People",
    "Microsoft.PowerAutomateDesktop", "Microsoft.ScreenSketch", "Microsoft.SkypeApp", "Microsoft.StorePurchaseApp",
    "Microsoft.Todos", "Microsoft.WebMediaExtensions", "Microsoft.WebpImageExtension", "Microsoft.Windows.Photos",
    "Microsoft.WindowsAlarms", "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps", "Microsoft.YourPhone",
    "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "MicrosoftCorporationII.MicrosoftFamily",
    "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay"
)
Write-Host " - Removing modern (AppX) packages. This may take a moment..."
foreach ($App in $BloatwareApps) {
    Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$App*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}
Write-Host "   -> AppX package removal process completed." -ForegroundColor Green

# Part B: Uninstall specific programs (Teams, OneDrive)
Write-Host " - Running specific uninstallers for Teams and OneDrive..."
# Uninstall Microsoft Teams
try {
    Get-AppxPackage *MicrosoftTeams* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-Package "Teams Machine-Wide Installer" -ErrorAction SilentlyContinue | Uninstall-Package -Force -ErrorAction SilentlyContinue
    Write-Host "   -> Microsoft Teams uninstall routines executed." -ForegroundColor Green
} catch { Write-Warning "   -> A non-critical error occurred during Teams removal."}

# Uninstall OneDrive
$oneDriveUninstaller = Get-ChildItem -Path "$env:SystemRoot\SysWOW64", "$env:SystemRoot\System32" -Filter "OneDriveSetup.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($oneDriveUninstaller) {
    try {
        Start-Process $oneDriveUninstaller.FullName -ArgumentList "/uninstall" -Wait
        $gpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (-not (Test-Path $gpoPath)) { New-Item -Path $gpoPath -Force | Out-Null }
        Set-ItemProperty -Path $gpoPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWORD -Force
        Write-Host "   -> OneDrive uninstaller executed and GPO set to prevent reinstall." -ForegroundColor Green
    } catch { Write-Warning "   -> Error during OneDrive uninstall: $($_.Exception.Message)"}
} else { Write-Warning "   -> OneDrive setup file not found. Skipping uninstall." }


#===================================================================================================
# SECTION 4: UI, EXPLORER, & DESKTOP CUSTOMIZATION
#---------------------------------------------------------------------------------------------------
Write-Host "`n[SECTION 4] Applying UI & Desktop Experience Tweaks..." -ForegroundColor Cyan

# Apply general UI tweaks via registry
Write-Host " - Applying registry-based UI tweaks..."
try {
    # Enable Dark Mode
    $themePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $themePath)) { New-Item -Path $themePath -Force | Out-Null }
    Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -Type DWORD -Force
    Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -Type DWORD -Force
    Write-Host "   -> Dark Mode enabled."

    # Show File Extensions in File Explorer
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -Force -ErrorAction Stop
    Write-Host "   -> File extensions will now be shown."

    # Show 'This PC' icon on the Desktop
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" -Value 0 -Force -ErrorAction Stop
    Write-Host "   -> 'This PC' icon will be shown on the desktop."
    
    # Use Windows 10 Classic Context Menu
    New-Item -Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -Force | Set-ItemProperty -Name "(Default)" -Value "" -Force
    Write-Host "   -> Windows 10 classic context menu enabled."

    Write-Host "   -> General UI tweaks applied successfully." -ForegroundColor Green
} catch {
    Write-Warning "   -> An error occurred while applying general UI tweaks."
}

# Customize Taskbar
Write-Host " - Customizing Taskbar icons and pins..."
try {
    # Remove default icons via registry
    $advExplorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advExplorer -Name "TaskbarMn" -Value 0 -Force # Chat Icon
    Set-ItemProperty -Path $advExplorer -Name "TaskbarDa" -Value 0 -Force # Widgets Icon
    Set-ItemProperty -Path $advExplorer -Name "ShowCopilotButton" -Value 0 -Force # Copilot Icon
    Write-Host "   -> Chat, Widgets, and Copilot icons disabled."

    # Unpin default apps
    Remove-TaskbarPin -AppName "Microsoft Edge"
    Remove-TaskbarPin -AppName "Mail"
    Remove-TaskbarPin -AppName "Microsoft Store"
    
    # Pin Google Chrome
    $chromePath = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Recurse -Filter "chrome.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
    if ($chromePath) { Add-TaskbarPin -AppPath $chromePath } else { Write-Warning "   -> Google Chrome not found. Skipping pinning." }

} catch { Write-Warning "   -> An error occurred during taskbar customization." }


#===================================================================================================
# SECTION 5: FILE SYSTEM & MISCELLANEOUS SETUP
#---------------------------------------------------------------------------------------------------
Write-Host "`n[SECTION 5] Performing File System Setup..." -ForegroundColor Cyan

# Create C:\Archive Directory
Write-Host " - Creating 'Archive' directory..."
$archivePath = "C:\Archive"
try {
    if (-not (Test-Path $archivePath)) {
        New-Item -Path $archivePath -ItemType Directory -Force | Out-Null
        Write-Host "   -> Successfully created directory: $archivePath" -ForegroundColor Green
    } else { Write-Host "   -> Directory '$archivePath' already exists." }
} catch { Write-Warning "   -> Error creating directory at $archivePath: $($_.Exception.Message)" }

# Create Beam Files
Write-Host " - Creating beam files..."
try {
    New-Item -Path "C:\Windows\dvnc.wov" -ItemType File -Force -ErrorAction Stop | Out-Null
    Write-Host "   -> Successfully created empty file: C:\Windows\dvnc.wov" -ForegroundColor Green
    New-Item -Path "C:\Windows\system32\dvnc.wov" -ItemType File -Force -ErrorAction Stop | Out-Null
    Write-Host "   -> Successfully created empty file: C:\Windows\system32\dvnc.wov" -ForegroundColor Green
    New-Item -Path "C:\Windows\ProgramFiles\dvnc.wov" -ItemType File -Force -ErrorAction Stop | Out-Null
    New-Item -Path "C:\Windows\ProgramFiles (x86)\dvnc.wov" -ItemType File -Force -ErrorAction Stop | Out-Null
} catch { Write-Warning "   -> Error creating beam files: $($_.Exception.Message)" }


#===================================================================================================
# FINALIZATION
#===================================================================================================

Write-Host "`nAll tasks completed. Restarting Windows Explorer to apply UI changes..." -ForegroundColor Yellow
Write-Warning "The screen and taskbar will flash briefly. This is expected."
Stop-Process -Name explorer -Force

Write-Host "`n--------------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Script execution finished." -ForegroundColor Cyan
Write-Warning "A full system RESTART is recommended to apply all changes (especially UAC)."
Write-Host "--------------------------------------------------------------------" -ForegroundColor Cyan
Read-Host "Press Enter to exit..."
