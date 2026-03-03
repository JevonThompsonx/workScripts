#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Comprehensive initial baseline setup for Windows 10/11 workstations.
.DESCRIPTION
    Applies standard configuration to a fresh Windows installation. All operations
    are idempotent -- safe to re-run on the same machine multiple times.

    Steps performed:
      1.  Enable High Performance power plan
      2.  Disable hibernation
      3.  Disable USB Selective Suspend (active power plan, AC and DC)
      4.  Disable User Account Control (UAC) -- WARNING: reboot required
      5.  Enable Dark Mode for the current user
      6.  Create sentinel files: C:\Windows\dvnc.wov, C:\Windows\System32\dvnc.wov
      7.  Customize taskbar: unpin Edge/Mail/Store, hide Copilot button, pin Chrome
      8.  Remove bloatware: Microsoft Teams (AppX + machine-wide installer), OneDrive

    A Windows Explorer restart is performed at the end to apply UI changes (screen
    flashes briefly). Skip with -SkipExplorerRestart.

    WARNING: Disabling UAC (step 4) significantly reduces system security.
    A REBOOT is required for that change to take effect.

.PARAMETER SkipTaskbar
    Skip taskbar customization (step 7). Use when Chrome is not yet installed.

.PARAMETER SkipBloatware
    Skip bloatware removal (step 8). Use when Teams or OneDrive must be retained.

.PARAMETER SkipExplorerRestart
    Skip the Explorer restart at the end. UI changes will apply at next logon.

.EXAMPLE
    .\Initialize-WorkstationBaseline.ps1
    Full setup with all steps.

.EXAMPLE
    .\Initialize-WorkstationBaseline.ps1 -SkipTaskbar -SkipBloatware
    System-level configuration only -- no taskbar or software changes.

.NOTES
    Author:  Jevon Thompson
    Version: 2.0.0
    Date:    2026-03-03
    Exit Codes:
        0    = All executed steps succeeded (no reboot needed)
        1    = Partial success -- one or more non-critical steps failed (see log)
        2    = Fatal error -- script aborted before completion
        100  = Nothing to do -- all steps were already in the desired state
        3010 = Success, reboot required (UAC change applied)
    Changelog:
        2.0.0 - Combined setup_script_windows_settings1_2.ps1 and 1_3.ps1.
                Refactored to enterprise standard: Set-StrictMode, CmdletBinding,
                structured logging, results tracking, idempotency checks, no aliases.
                Added -SkipTaskbar, -SkipBloatware, -SkipExplorerRestart switches.
                Chrome search now checks standard paths (no slow recursive search).
                OneDrive uninstaller uses ProcessStartInfo with 2-minute timeout.
                UAC step is idempotent -- only sets $rebootRequired when changed.
        1.3.0 - Added taskbar customization, bloatware removal, USB Selective Suspend.
        1.2.0 - Initial release: power plan, hibernate, UAC, dark mode, sentinel files.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$SkipTaskbar,
    [switch]$SkipBloatware,
    [switch]$SkipExplorerRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Logging

$logDir = 'C:\ProgramData\Scripts\Logs'
if (-not (Test-Path -Path $logDir -PathType Container)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
$logPath = Join-Path -Path $logDir -ChildPath "Initialize-WorkstationBaseline_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-Log {
    <#
    .SYNOPSIS
        Writes a timestamped message to the console and log file.
    .PARAMETER Message
        The message to write.
    .PARAMETER Level
        Severity: INFO (default), WARN, or ERROR.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        'ERROR' { Write-Host $line -ForegroundColor Red }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        default { Write-Host $line -ForegroundColor Gray }
    }
    Add-Content -Path $logPath -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

#endregion

#region Results Tracking

$stepResults = @{
    Success = [System.Collections.Generic.List[string]]::new()
    Skipped = [System.Collections.Generic.List[string]]::new()
    Failed  = [System.Collections.Generic.List[string]]::new()
}
$rebootRequired = $false

function Add-StepResult {
    <#
    .SYNOPSIS
        Records the outcome of a setup step for the final summary.
    .PARAMETER Status
        Outcome: Success, Skipped, or Failed.
    .PARAMETER Step
        Short description of the step.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Success', 'Skipped', 'Failed')]
        [string]$Status,

        [Parameter(Mandatory = $true)]
        [string]$Step
    )
    $stepResults[$Status].Add($Step)
}

#endregion

#region Helper Functions

function Set-RegistryDWord {
    <#
    .SYNOPSIS
        Creates a registry path if missing and sets a DWORD value -- idempotent.
    .PARAMETER Path
        Full registry path (e.g., HKLM:\SOFTWARE\...).
    .PARAMETER Name
        Value name.
    .PARAMETER Value
        Integer value to write as DWORD.
    .EXAMPLE
        Set-RegistryDWord -Path 'HKCU:\SOFTWARE\...' -Name 'MyKey' -Value 0
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$Value
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
}

function Remove-TaskbarPin {
    <#
    .SYNOPSIS
        Unpins a named application from the Windows taskbar via Shell COM verbs.
    .DESCRIPTION
        Locates the application's .lnk shortcut in the Quick Launch TaskBar folder
        and invokes the 'Unpin from taskbar' Shell verb. This approach has known
        reliability limitations on Windows 11 -- the verb may not be present on all
        builds. If the item is not found or the verb is absent, the step is silently
        skipped.
    .PARAMETER AppName
        Partial display name of the application to unpin (e.g., 'Microsoft Edge').
    .EXAMPLE
        Remove-TaskbarPin -AppName 'Microsoft Edge'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppName
    )

    $taskBarDir = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    $pinnedItem = Get-ChildItem -Path $taskBarDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$AppName*" } |
        Select-Object -First 1

    if ($null -eq $pinnedItem) {
        Write-Log "'$AppName' shortcut not in taskbar folder -- already unpinned or not present."
        return
    }

    try {
        $shell  = New-Object -ComObject Shell.Application -ErrorAction Stop
        $folder = $shell.Namespace($pinnedItem.Directory.FullName)
        $item   = $folder.ParseName($pinnedItem.Name)
        $unpin  = $item.Verbs() | Where-Object { $_.Name -eq 'Unpin from taskbar' } | Select-Object -First 1

        if ($null -ne $unpin) {
            $unpin.DoIt()
            Write-Log "Unpinned '$AppName' from taskbar."
        }
        else {
            Write-Log "'Unpin from taskbar' verb not available for '$AppName' -- may already be unpinned or unsupported on this build." -Level 'WARN'
        }
    }
    catch {
        $currentError = $_
        Write-Log "Error unpinning '$AppName': $($currentError.Exception.Message)" -Level 'WARN'
    }
}

function Add-TaskbarPin {
    <#
    .SYNOPSIS
        Pins an executable to the Windows taskbar via Shell COM verbs.
    .DESCRIPTION
        Uses Shell.Application to invoke the 'Pin to taskbar' verb on the target
        executable. This approach has known reliability limitations on Windows 11
        and may not work on all builds. If the verb is absent, the step is silently
        skipped rather than erroring.
    .PARAMETER AppPath
        Full path to the .exe to pin.
    .EXAMPLE
        Add-TaskbarPin -AppPath 'C:\Program Files\Google\Chrome\Application\chrome.exe'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path -Path $_ -PathType Leaf)) {
                throw "Executable not found: $_"
            }
            $true
        })]
        [string]$AppPath
    )

    $fileName   = Split-Path -Path $AppPath -Leaf
    $folderPath = Split-Path -Path $AppPath -Parent

    try {
        $shell  = New-Object -ComObject Shell.Application -ErrorAction Stop
        $folder = $shell.Namespace($folderPath)
        $item   = $folder.ParseName($fileName)
        $pin    = $item.Verbs() | Where-Object { $_.Name -eq 'Pin to taskbar' } | Select-Object -First 1

        if ($null -ne $pin) {
            $pin.DoIt()
            Write-Log "Pinned '$fileName' to taskbar."
        }
        else {
            Write-Log "'Pin to taskbar' verb not available for '$fileName' -- may already be pinned or unsupported on this build." -Level 'WARN'
        }
    }
    catch {
        $currentError = $_
        Write-Log "Error pinning '$fileName': $($currentError.Exception.Message)" -Level 'WARN'
    }
}

#endregion

# ============================================================
# MAIN
# ============================================================

$fatalError = $false
try {
    Start-Transcript -Path $logPath -Append | Out-Null

    Write-Host ''
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Host '  Initialize-WorkstationBaseline  v2.0.0' -ForegroundColor Cyan
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Log "Started by $env:USERNAME on $env:COMPUTERNAME (OS: $([System.Environment]::OSVersion.VersionString))"

    # ---- 1. High Performance Power Plan ----
    Write-Host "`n[Step 1/8] Enable High Performance power plan..." -ForegroundColor Cyan
    try {
        $highPerfPlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace 'root\cimv2\power' -ErrorAction Stop |
            Where-Object { $_.ElementName -like '*High performance*' } |
            Select-Object -First 1

        if ($null -eq $highPerfPlan) {
            Write-Log 'High Performance plan not found -- may not exist on this hardware/SKU.' -Level 'WARN'
            Add-StepResult -Status 'Skipped' -Step 'High Performance Power Plan'
        }
        else {
            $planGuid = ($highPerfPlan.InstanceID -split '[{}]')[1]
            powercfg.exe /setactive $planGuid
            if ($LASTEXITCODE -ne 0) {
                throw "powercfg /setactive returned exit code $LASTEXITCODE"
            }
            Write-Log "High Performance plan activated (GUID: $planGuid)."
            Add-StepResult -Status 'Success' -Step 'High Performance Power Plan'
        }
    }
    catch {
        $currentError = $_
        Write-Log "Failed to set High Performance plan: $($currentError.Exception.Message)" -Level 'ERROR'
        Add-StepResult -Status 'Failed' -Step 'High Performance Power Plan'
    }

    # ---- 2. Disable Hibernation ----
    Write-Host "`n[Step 2/8] Disable hibernation..." -ForegroundColor Cyan
    try {
        powercfg.exe /hibernate off
        if ($LASTEXITCODE -ne 0) {
            throw "powercfg /hibernate off returned exit code $LASTEXITCODE"
        }
        Write-Log 'Hibernation disabled.'
        Add-StepResult -Status 'Success' -Step 'Disable Hibernation'
    }
    catch {
        $currentError = $_
        Write-Log "Failed to disable hibernation: $($currentError.Exception.Message)" -Level 'ERROR'
        Add-StepResult -Status 'Failed' -Step 'Disable Hibernation'
    }

    # ---- 3. Disable USB Selective Suspend ----
    Write-Host "`n[Step 3/8] Disable USB Selective Suspend..." -ForegroundColor Cyan
    try {
        $activePlan = Get-CimInstance -ClassName Win32_PowerPlan -Namespace 'root\cimv2\power' -ErrorAction Stop |
            Where-Object { $_.IsActive -eq $true } |
            Select-Object -First 1

        if ($null -eq $activePlan) {
            throw 'Could not identify the active power plan.'
        }

        $activePlanGuid  = ($activePlan.InstanceID -split '[{}]')[1]
        $usbSubgroupGuid = '2a737441-1930-4402-8d77-b2bebba308a3'
        $usbSettingGuid  = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'

        powercfg -setacvalueindex $activePlanGuid $usbSubgroupGuid $usbSettingGuid 0
        powercfg -setdcvalueindex $activePlanGuid $usbSubgroupGuid $usbSettingGuid 0
        Write-Log 'USB Selective Suspend disabled (AC and DC) on active power plan.'
        Add-StepResult -Status 'Success' -Step 'Disable USB Selective Suspend'
    }
    catch {
        $currentError = $_
        Write-Log "Failed to disable USB Selective Suspend: $($currentError.Exception.Message)" -Level 'ERROR'
        Add-StepResult -Status 'Failed' -Step 'Disable USB Selective Suspend'
    }

    # ---- 4. Disable UAC ----
    Write-Host "`n[Step 4/8] Disable UAC..." -ForegroundColor Cyan
    Write-Log 'SECURITY WARNING: Disabling UAC reduces system security. A reboot is required.' -Level 'WARN'
    try {
        $uacRegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        $uacCurrent = Get-ItemProperty -Path $uacRegPath -Name 'EnableLUA' -ErrorAction SilentlyContinue

        if ($null -ne $uacCurrent -and $uacCurrent.EnableLUA -eq 0) {
            Write-Log 'UAC already disabled -- skipping.'
            Add-StepResult -Status 'Skipped' -Step 'Disable UAC'
        }
        else {
            Set-RegistryDWord -Path $uacRegPath -Name 'EnableLUA' -Value 0
            $script:rebootRequired = $true
            Write-Log 'UAC disabled in registry (reboot required to take effect).'
            Add-StepResult -Status 'Success' -Step 'Disable UAC'
        }
    }
    catch {
        $currentError = $_
        Write-Log "Failed to disable UAC: $($currentError.Exception.Message)" -Level 'ERROR'
        Add-StepResult -Status 'Failed' -Step 'Disable UAC'
    }

    # ---- 5. Enable Dark Mode ----
    Write-Host "`n[Step 5/8] Enable Dark Mode for $env:USERNAME..." -ForegroundColor Cyan
    try {
        $themePath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-RegistryDWord -Path $themePath -Name 'AppsUseLightTheme'    -Value 0
        Set-RegistryDWord -Path $themePath -Name 'SystemUsesLightTheme' -Value 0
        Write-Log 'Dark Mode enabled (Apps + System) for current user.'
        Add-StepResult -Status 'Success' -Step 'Enable Dark Mode'
    }
    catch {
        $currentError = $_
        Write-Log "Failed to enable Dark Mode: $($currentError.Exception.Message)" -Level 'ERROR'
        Add-StepResult -Status 'Failed' -Step 'Enable Dark Mode'
    }

    # ---- 6. Create Sentinel Files ----
    Write-Host "`n[Step 6/8] Create sentinel files..." -ForegroundColor Cyan
    $sentinelFiles = @(
        'C:\Windows\dvnc.wov',
        'C:\Windows\System32\dvnc.wov'
    )
    foreach ($sentinelFile in $sentinelFiles) {
        try {
            if (Test-Path -Path $sentinelFile) {
                Write-Log "Sentinel already exists: $sentinelFile"
                Add-StepResult -Status 'Skipped' -Step "Sentinel: $sentinelFile"
            }
            else {
                New-Item -Path $sentinelFile -ItemType File -Force -ErrorAction Stop | Out-Null
                Write-Log "Created sentinel file: $sentinelFile"
                Add-StepResult -Status 'Success' -Step "Sentinel: $sentinelFile"
            }
        }
        catch {
            $currentError = $_
            Write-Log "Failed to create '$sentinelFile': $($currentError.Exception.Message)" -Level 'ERROR'
            Add-StepResult -Status 'Failed' -Step "Sentinel: $sentinelFile"
        }
    }

    # ---- 7. Taskbar Customization ----
    Write-Host "`n[Step 7/8] Taskbar customization..." -ForegroundColor Cyan
    if ($SkipTaskbar) {
        Write-Log 'Taskbar customization skipped (-SkipTaskbar).'
        Add-StepResult -Status 'Skipped' -Step 'Taskbar Customization'
    }
    else {
        try {
            # Unpin default apps
            foreach ($appToUnpin in @('Microsoft Edge', 'Mail', 'Microsoft Store')) {
                Remove-TaskbarPin -AppName $appToUnpin
            }

            # Hide Copilot button (takes effect after Explorer restart)
            Set-RegistryDWord -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
                              -Name 'ShowCopilotButton' -Value 0
            Write-Log 'Copilot button hidden via registry.'

            # Pin Chrome -- check standard install locations only; no recursive search
            $chromeCandidates = @(
                "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
            )
            $chromePath = $null
            foreach ($candidate in $chromeCandidates) {
                if (Test-Path -Path $candidate -PathType Leaf) {
                    $chromePath = $candidate
                    break
                }
            }

            if ($null -ne $chromePath) {
                Add-TaskbarPin -AppPath $chromePath
                Add-StepResult -Status 'Success' -Step 'Taskbar Customization'
            }
            else {
                Write-Log 'Chrome not found at standard paths -- unpin and Copilot changes applied but Chrome not pinned.' -Level 'WARN'
                Add-StepResult -Status 'Skipped' -Step 'Pin Chrome (not installed)'
                Add-StepResult -Status 'Success' -Step 'Taskbar Customization (partial)'
            }
        }
        catch {
            $currentError = $_
            Write-Log "Error during taskbar customization: $($currentError.Exception.Message)" -Level 'ERROR'
            Add-StepResult -Status 'Failed' -Step 'Taskbar Customization'
        }
    }

    # ---- 8. Remove Bloatware ----
    Write-Host "`n[Step 8/8] Remove bloatware..." -ForegroundColor Cyan
    if ($SkipBloatware) {
        Write-Log 'Bloatware removal skipped (-SkipBloatware).'
        Add-StepResult -Status 'Skipped' -Step 'Remove Teams'
        Add-StepResult -Status 'Skipped' -Step 'Remove OneDrive'
    }
    else {
        # --- Teams AppX packages ---
        try {
            $teamsPackages = @(Get-AppxPackage -Name '*MicrosoftTeams*' -AllUsers -ErrorAction SilentlyContinue)
            if ($teamsPackages.Count -gt 0) {
                foreach ($pkg in $teamsPackages) {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
                    }
                    catch {
                        $currentError = $_
                        Write-Log "Could not remove Teams package '$($pkg.PackageFullName)': $($currentError.Exception.Message)" -Level 'WARN'
                    }
                }
                Write-Log "Attempted removal of $($teamsPackages.Count) Teams AppX package(s)."
                Add-StepResult -Status 'Success' -Step 'Remove Teams (AppX)'
            }
            else {
                Write-Log 'Teams AppX not found -- already removed or not installed.'
                Add-StepResult -Status 'Skipped' -Step 'Remove Teams (AppX)'
            }
        }
        catch {
            $currentError = $_
            Write-Log "Error enumerating Teams AppX packages: $($currentError.Exception.Message)" -Level 'WARN'
            Add-StepResult -Status 'Failed' -Step 'Remove Teams (AppX)'
        }

        # --- Teams Machine-Wide Installer ---
        try {
            $teamsMWI = Get-Package -Name 'Teams Machine-Wide Installer' -ErrorAction SilentlyContinue
            if ($null -ne $teamsMWI) {
                $teamsMWI | Uninstall-Package -Force -ErrorAction Stop
                Write-Log 'Teams Machine-Wide Installer removed.'
                Add-StepResult -Status 'Success' -Step 'Remove Teams (Machine-Wide Installer)'
            }
            else {
                Write-Log 'Teams Machine-Wide Installer not found -- already removed or not installed.'
                Add-StepResult -Status 'Skipped' -Step 'Remove Teams (Machine-Wide Installer)'
            }
        }
        catch {
            $currentError = $_
            Write-Log "Error removing Teams Machine-Wide Installer: $($currentError.Exception.Message)" -Level 'WARN'
            Add-StepResult -Status 'Failed' -Step 'Remove Teams (Machine-Wide Installer)'
        }

        # --- OneDrive ---
        try {
            $oneDriveCandidates = [System.Collections.Generic.List[string]]::new()
            $oneDriveCandidates.Add("$env:SystemRoot\SysWOW64\OneDriveSetup.exe")
            $oneDriveCandidates.Add("$env:SystemRoot\System32\OneDriveSetup.exe")

            $userODDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\OneDrive'
            if (Test-Path -Path $userODDir -PathType Container) {
                $latestBuildDir = Get-ChildItem -Path $userODDir -Directory -ErrorAction SilentlyContinue |
                    Sort-Object -Property LastWriteTime -Descending |
                    Select-Object -First 1
                if ($null -ne $latestBuildDir) {
                    $oneDriveCandidates.Add((Join-Path -Path $latestBuildDir.FullName -ChildPath 'OneDriveSetup.exe'))
                }
            }

            $oneDriveSetup = $null
            foreach ($candidate in $oneDriveCandidates) {
                if (Test-Path -Path $candidate -PathType Leaf) {
                    $oneDriveSetup = $candidate
                    break
                }
            }

            if ($null -ne $oneDriveSetup) {
                Write-Log "Running OneDrive uninstaller: $oneDriveSetup"
                $psi                  = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName         = $oneDriveSetup
                $psi.Arguments        = '/uninstall'
                $psi.UseShellExecute  = $false
                $psi.WindowStyle      = [System.Diagnostics.ProcessWindowStyle]::Minimized
                $proc                 = [System.Diagnostics.Process]::Start($psi)
                $completed            = $proc.WaitForExit(120000)   # 2-minute timeout

                if (-not $completed) {
                    try { $proc.Kill() } catch { }
                    throw 'OneDrive uninstaller timed out after 120 seconds.'
                }

                Write-Log "OneDrive uninstaller exited with code: $($proc.ExitCode)"
                Set-RegistryDWord -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' `
                                  -Name 'DisableFileSyncNGSC' -Value 1
                Write-Log 'OneDrive removed. GPO set to block reinstall.'
                Add-StepResult -Status 'Success' -Step 'Remove OneDrive'
            }
            else {
                Write-Log 'OneDrive setup executable not found -- may already be removed.'
                Add-StepResult -Status 'Skipped' -Step 'Remove OneDrive'
            }
        }
        catch {
            $currentError = $_
            Write-Log "Error removing OneDrive: $($currentError.Exception.Message)" -Level 'ERROR'
            Add-StepResult -Status 'Failed' -Step 'Remove OneDrive'
        }
    }

    # ---- Explorer Restart ----
    if (-not $SkipExplorerRestart) {
        Write-Host "`nRestarting Windows Explorer to apply UI changes (screen will flash briefly)..." -ForegroundColor Yellow
        Write-Log 'Restarting explorer.exe...'
        Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Write-Log 'Explorer restarted.'
    }
    else {
        Write-Log 'Explorer restart skipped (-SkipExplorerRestart). UI changes take effect at next logon.'
    }
}
catch {
    $currentError = $_
    Write-Log "FATAL: Script aborted -- $($currentError.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack trace: $($currentError.ScriptStackTrace)" -Level 'ERROR'
    $fatalError = $true
}
finally {
    Stop-Transcript -ErrorAction SilentlyContinue
}

# ---- Results Summary ----
Write-Host ''
Write-Host '================================================' -ForegroundColor Cyan
Write-Host '  SETUP SUMMARY' -ForegroundColor Cyan
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ("  Success : {0}" -f $stepResults.Success.Count) -ForegroundColor Green
Write-Host ("  Skipped : {0}" -f $stepResults.Skipped.Count) -ForegroundColor Yellow
Write-Host ("  Failed  : {0}" -f $stepResults.Failed.Count)  -ForegroundColor Red

if ($stepResults.Failed.Count -gt 0) {
    Write-Host ''
    Write-Host '  Failed steps:' -ForegroundColor Red
    foreach ($failedStep in $stepResults.Failed) {
        Write-Host "    - $failedStep" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host ("  Log: {0}" -f $logPath) -ForegroundColor Gray
Write-Host ''
if ($rebootRequired) {
    Write-Warning 'REBOOT REQUIRED: UAC change will not take effect until the machine is restarted.'
}
Write-Host '================================================' -ForegroundColor Cyan
Write-Host ''

# ---- Exit Code ----
if ($fatalError) {
    exit 2
}
elseif ($stepResults.Failed.Count -gt 0 -and $stepResults.Success.Count -gt 0) {
    exit 1   # Partial success
}
elseif ($stepResults.Failed.Count -gt 0) {
    exit 2   # All failed
}
elseif ($stepResults.Success.Count -eq 0) {
    exit 100 # Nothing to do -- all skipped
}
elseif ($rebootRequired) {
    exit 3010 # Success, reboot required
}
else {
    exit 0
}
