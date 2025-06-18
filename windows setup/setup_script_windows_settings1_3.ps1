<#
.SYNOPSIS
    Performs a comprehensive system setup: Configures power plan, UAC, theme,
    uninstalls bloatware, and customizes the taskbar.
.DESCRIPTION
    This script requires Administrator privileges to run correctly.
    - Sets the active power plan to High Performance.
    - Disables the system's hibernation feature.
    - Disables USB Selective Suspend to prevent USB devices from powering down.
    *WARNING*: Disables User Account Control (UAC). A REBOOT is REQUIRED.
    - Enables system-wide Dark Mode for the CURRENT USER.
    - Creates an empty beam file named 'dvnc.wov' in C:\Windows and C:\Windows\system32.
    - Uninstalls OneDrive and Microsoft Teams.
    - Customizes the taskbar: Unpins default apps, disables Copilot, and pins Google Chrome.
    *WARNING*: This script will restart the Explorer shell to apply UI changes,
      causing the screen to briefly flash.
.NOTES
    Author: AI Assistant
    Requires: Windows PowerShell or PowerShell Core, Administrator privileges.
    UAC changes require a reboot.
    UI/Shell changes apply to the user running the script and restart explorer.exe.
#>

#Requires -RunAsAdministrator

# --- Helper Functions for Taskbar Customization ---
function Remove-TaskbarPin {
    param([string]$AppName)
    try {
        $verb = "Unpin from taskbar"
        $pinnedItem = Get-ChildItem "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" | Where-Object { $_.Name -like "*$AppName*" } | Select-Object -First 1
        if ($pinnedItem) {
            $shell = New-Object -ComObject Shell.Application
            $folder = $shell.Namespace($pinnedItem.Directory.FullName)
            $item = $folder.ParseName($pinnedItem.Name)
            if ($item.Verbs() | Where-Object { $_.Name -eq $verb }) {
                $item.Verbs() | Where-Object { $_.Name -eq $verb } | ForEach-Object { $_.DoIt() }
                Write-Host "Successfully unpinned '$AppName' from the taskbar." -ForegroundColor Green
            }
        } else { Write-Host "'$AppName' is not currently pinned." }
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
        if ($item.Verbs() | Where-Object { $_.Name -eq $verb }) {
            $item.Verbs() | Where-Object { $_.Name -eq $verb } | ForEach-Object { $_.DoIt() }
            Write-Host "Successfully pinned '$fileName' to the taskbar." -ForegroundColor Green
        }
    } catch { Write-Warning "An error occurred while trying to pin '$fileName': $($_.Exception.Message)" }
}

Write-Host "Starting comprehensive system setup script..." -ForegroundColor Cyan
Write-Host "Running as Administrator: $((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))"

# --- 1. Enable High Performance Power Plan ---
Write-Host "`n[1] Setting High Performance Power Plan..." -ForegroundColor Yellow
try {
    $highPerformancePlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.ElementName -like '*High performance*' } | Select-Object -First 1
    if ($highPerformancePlan) {
        $planGuidOnly = ($highPerformancePlan.InstanceID -split '[{}]')[1]
        powercfg.exe /setactive $planGuidOnly
        Write-Host "Successfully activated High Performance power plan." -ForegroundColor Green
    } else { Write-Warning "High Performance power plan not found."}
} catch { Write-Warning "Error setting High Performance power plan: $($_.Exception.Message)" }

# --- 2. Disable Hibernation ---
Write-Host "`n[2] Disabling Hibernation..." -ForegroundColor Yellow
try {
    powercfg.exe /hibernate off
    Write-Host "Hibernation successfully disabled." -ForegroundColor Green
} catch { Write-Warning "Error disabling hibernation: $($_.Exception.Message)" }

# --- 3. Disable User Account Control (UAC) ---
Write-Host "`n[3] Disabling User Account Control (UAC)..." -ForegroundColor Yellow
Write-Warning "*** SECURITY WARNING: Disabling UAC significantly reduces system security. ***"
Write-Warning "*** A system REBOOT is REQUIRED for this change to take effect! ***"
$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
try {
    Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 0 -Type DWORD -Force
    Write-Host "UAC successfully disabled in registry." -ForegroundColor Green
} catch { Write-Warning "Error disabling UAC: $($_.Exception.Message)" }

# --- 4. Enable Dark Mode (for Current User) ---
Write-Host "`n[4] Enabling Dark Mode for the current user ($($env:USERNAME))..." -ForegroundColor Yellow
$themePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
try {
    if (-not (Test-Path $themePath)) { New-Item -Path $themePath -Force | Out-Null }
    Set-ItemProperty -Path $themePath -Name "AppsUseLightTheme" -Value 0 -Type DWORD -Force
    Set-ItemProperty -Path $themePath -Name "SystemUsesLightTheme" -Value 0 -Type DWORD -Force
    Write-Host "Dark Mode successfully enabled for Apps and System." -ForegroundColor Green
} catch { Write-Warning "Error enabling Dark Mode: $($_.Exception.Message)" }

# --- 5. Create Beam Files ---
Write-Host "`n[5] Creating beam files..." -ForegroundColor Yellow
$file1_path = "C:\Windows\dvnc.wov"
$file2_path = "C:\Windows\system32\dvnc.wov"
try {
    New-Item -Path $file1_path -ItemType File -Force -ErrorAction Stop | Out-Null
    Write-Host "Successfully created empty beam file: $file1_path" -ForegroundColor Green
} catch { Write-Warning "Error creating file at ${file1_path}: $($_.Exception.Message)" }
try {
    New-Item -Path $file2_path -ItemType File -Force -ErrorAction Stop | Out-Null
    Write-Host "Successfully created empty beam file: $file2_path" -ForegroundColor Green
} catch { Write-Warning "Error creating file at ${file2_path}: $($_.Exception.Message)" }

# --- 6. Customize Taskbar ---
Write-Host "`n[6] Customizing Taskbar pins..." -ForegroundColor Yellow
Remove-TaskbarPin -AppName "Microsoft Edge"
Remove-TaskbarPin -AppName "Mail"
Remove-TaskbarPin -AppName "Microsoft Store"
$copilotPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
try {
    if (-not (Test-Path $copilotPath)) { New-Item -Path $copilotPath -Force | Out-Null }
    Set-ItemProperty -Path $copilotPath -Name "ShowCopilotButton" -Value 0 -Type DWORD -Force
    Write-Host "Copilot button disabled in registry." -ForegroundColor Green
} catch { Write-Warning "Could not disable Copilot button: $($_.Exception.Message)" }
$chromePath = Get-ChildItem -Path "C:\Program Files", "C:\Program Files (x86)" -Recurse -Filter "chrome.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if ($chromePath) { Add-TaskbarPin -AppPath $chromePath } else { Write-Warning "Google Chrome not found. Skipping pinning." }

# --- 7. Uninstall Bloatware ---
Write-Host "`n[7] Uninstalling Bloatware (Teams, OneDrive)..." -ForegroundColor Yellow
# Uninstall Microsoft Teams (modern AppX version)
try {
    Get-AppxPackage *MicrosoftTeams* | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Write-Host "Attempted to remove modern Microsoft Teams app." -ForegroundColor Green
} catch { Write-Warning "Could not remove modern Teams app: $($_.Exception.Message)"}
# Uninstall Teams Machine-Wide Installer
try {
    Get-Package "Teams Machine-Wide Installer" -ErrorAction SilentlyContinue | Uninstall-Package -Force -ErrorAction SilentlyContinue
    Write-Host "Attempted to remove Teams Machine-Wide Installer." -ForegroundColor Green
} catch { Write-Warning "Could not remove Teams Machine-Wide Installer: $($_.Exception.Message)"}
# Uninstall OneDrive
Write-Host "Attempting to uninstall OneDrive..."
$oneDrivePaths = @(
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe",
    "$env:SystemRoot\System32\OneDriveSetup.exe"
)
$userOneDrivePath = Join-Path $env:LOCALAPPDATA "Microsoft\OneDrive"
if (Test-Path $userOneDrivePath) {
    $latestUserOneDriveSetup = Get-ChildItem -Path $userOneDrivePath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestUserOneDriveSetup) { $oneDrivePaths += Join-Path $latestUserOneDriveSetup.FullName "OneDriveSetup.exe" }
}
$oneDriveUninstaller = $null
foreach ($path in $oneDrivePaths) { if (Test-Path $path) { $oneDriveUninstaller = Get-Item $path; break } }
if ($oneDriveUninstaller) {
    try {
        Start-Process $oneDriveUninstaller.FullName -ArgumentList "/uninstall" -Wait
        $gpoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
        if (-not (Test-Path $gpoPath)) { New-Item -Path $gpoPath -Force | Out-Null }
        Set-ItemProperty -Path $gpoPath -Name "DisableFileSyncNGSC" -Value 1 -Type DWORD -Force
        Write-Host "OneDrive uninstaller executed and GPO set to prevent reinstall." -ForegroundColor Green
    } catch { Write-Warning "Error during OneDrive uninstall: $($_.Exception.Message)"}
} else { Write-Warning "OneDrive setup file not found. Skipping uninstall." }

# --- 8. Disable USB Selective Suspend ---
Write-Host "`n[8] Disabling USB Selective Suspend..." -ForegroundColor Yellow
try {
    $activePlan = (Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.IsActive -eq $true }).InstanceID
    $planGuid = ($activePlan -split '[{}]')[1]
    $usbSubGroup = "2a737441-1930-4402-8d77-b2bebba308a3"
    $usbSuspendSetting = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
    powercfg -setacvalueindex $planGuid $usbSubGroup $usbSuspendSetting 0
    powercfg -setdcvalueindex $planGuid $usbSubGroup $usbSuspendSetting 0
    Write-Host "USB Selective Suspend has been disabled for the active power plan." -ForegroundColor Green
} catch { Write-Warning "Error disabling USB Selective Suspend: $($_.Exception.Message)"}

# --- Finalization ---
Write-Host "`nRestarting Windows Explorer to apply all UI changes..." -ForegroundColor Yellow
Write-Warning "The screen and taskbar will flash briefly. This is expected."
Stop-Process -Name explorer -Force

# --- Completion ---
Write-Host "`n-----------------------------------------------------" -ForegroundColor Cyan
Write-Host "Script execution finished." -ForegroundColor Cyan
Write-Warning "REMINDER: A system REBOOT is required for the UAC change to take effect."
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan