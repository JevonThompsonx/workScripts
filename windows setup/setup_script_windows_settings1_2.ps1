<#
.SYNOPSIS
    Performs basic system setup: Enables High Performance power plan,
    disables hibernation, disables UAC, enables Dark Mode, and creates marker files.
.DESCRIPTION
    This script requires Administrator privileges to run correctly.
    - Sets the active power plan to High Performance.
    - Disables the system's hibernation feature (powercfg -h off).
    *WARNING*: Disables User Account Control (UAC) by modifying the registry.
      This significantly reduces system security and is generally NOT recommended.
      A system REBOOT is REQUIRED for the UAC change to take effect.
    - Enables system-wide Dark Mode for Apps and System elements for the
      CURRENT USER running the script by modifying the registry.
    - Creates an empty beam file named 'dvnc.wov' in C:\Windows and C:\Windows\system32.
.NOTES
    Author: AI Assistant
    Requires: Windows PowerShell or PowerShell Core, Administrator privileges.
    UAC changes require a reboot.
    Dark Mode settings are applied per-user (to the account running the script).
#>

#Requires -RunAsAdministrator

Write-Host "Starting system setup script..." -ForegroundColor Cyan
Write-Host "Running as Administrator: $((([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))"

# --- 1. Enable High Performance Power Plan ---
Write-Host "`n[1] Setting High Performance Power Plan..." -ForegroundColor Yellow
try {
    # Find the High Performance plan GUID
    $highPerformancePlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace root\cimv2\power | Where-Object { $_.ElementName -like '*High performance*' } | Select-Object -First 1

    if ($highPerformancePlan) {
        # Extract just the GUID part
        $planGuidOnly = ($highPerformancePlan.InstanceID -split '[{}]')[1] # Splits by { or } and takes the middle part
        Write-Host "Found High Performance plan. Full ID: $($highPerformancePlan.InstanceID)"
        Write-Host "Extracted GUID for powercfg: $planGuidOnly"
        try {
            powercfg.exe /setactive $planGuidOnly # <--- Use the extracted GUID
            Write-Host "Attempted to activate High Performance power plan via powercfg."

            # Optional: Verify if it's now active
            $currentPlan = powercfg /getactivescheme
            if ($currentPlan -match $planGuidOnly) {
                Write-Host "Successfully activated High Performance power plan (Verified)." -ForegroundColor Green
            }
            else {
                Write-Warning "Powercfg command executed, but verification failed. Current active scheme: $currentPlan"
            }
        }
        catch {
            # Catch block might still not trigger for external exe errors, but good practice
            Write-Warning "Script error occurred while trying to set High Performance power plan: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "High Performance power plan not found on this system."
    }
}
catch {
    Write-Warning "Error setting High Performance power plan: $($_.Exception.Message)"
}

# --- 2. Disable Hibernation ---
Write-Host "`n[2] Disabling Hibernation..." -ForegroundColor Yellow
try {
    powercfg.exe /hibernate off
    Write-Host "Hibernation successfully disabled (powercfg /h off)." -ForegroundColor Green
}
catch {
    Write-Warning "Error disabling hibernation: $($_.Exception.Message)"
}

# --- 3. Disable User Account Control (UAC) ---
# **********************************************************************
# * WARNING: DISABLING UAC IS A SECURITY RISK AND NOT RECOMMENDED!     *
# * A REBOOT IS REQUIRED FOR THIS CHANGE TO TAKE EFFECT.               *
# **********************************************************************
Write-Host "`n[3] Disabling User Account Control (UAC)..." -ForegroundColor Yellow
Write-Warning "*** SECURITY WARNING: Disabling UAC significantly reduces system security. Proceed with caution! ***"
Write-Warning "*** A system REBOOT is REQUIRED for this change to take effect! ***"

$uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$uacName = "EnableLUA"
$uacValue = 0 # 0 = Disabled, 1 = Enabled

try {
    # Ensure the path exists (it should, but check anyway)
    if (-not (Test-Path $uacPath)) {
        Write-Warning "Registry path for UAC not found: $uacPath"
    }
    else {
        Set-ItemProperty -Path $uacPath -Name $uacName -Value $uacValue -Type DWORD -Force
        Write-Host "Set registry key '$uacName' to '$uacValue' (Disabled) in '$uacPath'." -ForegroundColor Green
        Write-Host "UAC change requires a REBOOT to apply." -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Error disabling UAC (setting registry key HKLM\...EnableLUA): $($_.Exception.Message)"
}

# --- 4. Enable Dark Mode (for Current User) ---
Write-Host "`n[4] Enabling Dark Mode for the current user ($($env:USERNAME))..." -ForegroundColor Yellow
Write-Host "Note: This applies only to the user account running this script."

$themePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$appsLightName = "AppsUseLightTheme" # DWORD: 0 = Dark, 1 = Light
$systemLightName = "SystemUsesLightTheme" # DWORD: 0 = Dark, 1 = Light
$themeValue = 0 # 0 for Dark Mode

try {
    # Ensure the registry path exists for the current user. Create if not.
    if (-not (Test-Path $themePath)) {
        New-Item -Path $themePath -Force | Out-Null
        Write-Host "Created registry key: $themePath"
    }

    # Set Apps theme
    Set-ItemProperty -Path $themePath -Name $appsLightName -Value $themeValue -Type DWORD -Force
    Write-Host "Set '$appsLightName' to '$themeValue' (Dark Mode for Apps)." -ForegroundColor Green

    # Set System theme
    Set-ItemProperty -Path $themePath -Name $systemLightName -Value $themeValue -Type DWORD -Force
    Write-Host "Set '$systemLightName' to '$themeValue' (Dark Mode for System)." -ForegroundColor Green

    # Sometimes explorer needs a nudge, but often changes apply dynamically or after app restarts.
    # You could try uncommenting the line below, but it can be disruptive.
    # Stop-Process -Name explorer -Force

}
catch {
    Write-Warning "Error enabling Dark Mode (setting registry keys HKCU\...Personalize): $($_.Exception.Message)"
}

# --- 5. Create Beam Files ---
Write-Host "`n[5] Creating beam files..." -ForegroundColor Yellow
$file1_path = "C:\Windows\dvnc.wov"
$file2_path = "C:\Windows\system32\dvnc.wov"

try {
    New-Item -Path $file1_path -ItemType File -Force | Out-Null
    Write-Host "Successfully created beam file: $file1_path" -ForegroundColor Green
}
catch {
    Write-Warning "Error creating file at ${file1_path}: $($_.Exception.Message)"
}

try {
    New-Item -Path $file2_path -ItemType File -Force | Out-Null
    Write-Host "Successfully created beam file: $file2_path" -ForegroundColor Green
}
catch {
    Write-Warning "Error creating file at ${file2_path}: $($_.Exception.Message)"
}


# --- Completion ---
Write-Host "`n-----------------------------------------------------" -ForegroundColor Cyan
Write-Host "Script execution finished." -ForegroundColor Cyan
Write-Warning "REMINDER: A system REBOOT is required for the UAC change to take effect."
Write-Host "Dark mode settings apply to the current user ($($env:USERNAME)) and may require applications to be restarted."
Write-Host "-----------------------------------------------------" -ForegroundColor Cyan
