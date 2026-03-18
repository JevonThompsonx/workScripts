#Requires -Version 5.1
<#
.SYNOPSIS
    NinjaOne RMM Script: Complete Egnyte Removal (Stage 1 of 2)
    
.DESCRIPTION
    Aggressively removes all Egnyte components and prepares for a clean reinstall.
    Designed for mass deployment via NinjaOne RMM.
    
    This script:
    1. Stops all Egnyte processes and services
    2. Uninstalls via MSI product codes (most reliable)
    3. Uninstalls via registry uninstall strings (fallback)
    4. Cleans up file system remnants across all user profiles
    5. Removes registry keys
    6. Optionally triggers a reboot (configurable)
    
.PARAMETER ForceReboot
    If set to $true, forces an immediate reboot after cleanup.
    Default: $false (for NinjaOne, schedule reboot separately)
    
.PARAMETER RebootDelaySeconds
    Seconds to wait before reboot if ForceReboot is enabled.
    Default: 60
    
.NOTES
    Exit Codes (NinjaOne compatible):
    0   = Success - Egnyte fully removed
    1   = Partial success - Some components may remain
    2   = Critical failure - Script could not execute properly
    100 = Egnyte was not installed (nothing to remove)
    
    Author: Optimized for NinjaOne RMM deployment
    Version: 2.0
#>

[CmdletBinding()]
param(
    [Parameter()]
    [bool]$ForceReboot = $false,
    
    [Parameter()]
    [int]$RebootDelaySeconds = 60
)

#region Configuration
$ErrorActionPreference = 'Continue'
$VerbosePreference = 'Continue'

# Transcript for debugging (NinjaOne captures this)
$transcriptPath = Join-Path $env:TEMP "EgnyteNuke_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
try { Start-Transcript -Path $transcriptPath -Force } catch { }

# Track overall success
$script:HasErrors = $false
$script:EgnyteWasInstalled = $false
#endregion

#region Helper Functions
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] $Message"
    switch ($Level) {
        'ERROR'   { Write-Error $Message; $script:HasErrors = $true }
        'WARNING' { Write-Warning $Message }
        default   { Write-Host $logMessage }
    }
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-EgnyteProcesses {
    Write-Log "Stopping all Egnyte processes..."
    
    $egnyteProcesses = @(
        'EgnyteClient',
        'EgnyteDrive', 
        'EgnyteSyncService',
        'EgnyteUpdate',
        'EgnyteDriveCollaborationProvider',
        'EgnyteHelpViewer',
        'CefSharp.BrowserSubprocess'
    )
    
    foreach ($procName in $egnyteProcesses) {
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($procs) {
            $script:EgnyteWasInstalled = $true
            foreach ($proc in $procs) {
                try {
                    Write-Log "Stopping process: $($proc.Name) (PID: $($proc.Id))"
                    $proc | Stop-Process -Force -ErrorAction Stop
                } catch {
                    Write-Log "Could not stop process $($proc.Name): $_" -Level 'WARNING'
                }
            }
        }
    }
    
    # Also catch any egnyte-related processes by wildcard
    Get-Process | Where-Object { $_.Name -like '*egnyte*' -or $_.Path -like '*Egnyte*' } | ForEach-Object {
        try {
            Write-Log "Stopping additional process: $($_.Name) (PID: $($_.Id))"
            $_ | Stop-Process -Force -ErrorAction Stop
        } catch {
            Write-Log "Could not stop process $($_.Name): $_" -Level 'WARNING'
        }
    }
    
    Start-Sleep -Seconds 3
}

function Stop-EgnyteServices {
    Write-Log "Stopping Egnyte services..."
    
    $egnyteServices = @(
        'EgnyteDriveService',
        'EgnyteSyncService', 
        'egnytefs',
        'EgnyteWebDAVService'
    )
    
    foreach ($svcName in $egnyteServices) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if ($svc) {
            $script:EgnyteWasInstalled = $true
            try {
                Write-Log "Stopping service: $svcName (Status: $($svc.Status))"
                Stop-Service -Name $svcName -Force -ErrorAction Stop
                # Try to disable it too so it doesn't restart
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
            } catch {
                Write-Log "Could not stop service $svcName : $_" -Level 'WARNING'
            }
        }
    }
    
    # Also check for any service with Egnyte in the name
    Get-Service | Where-Object { $_.Name -like '*egnyte*' -or $_.DisplayName -like '*Egnyte*' } | ForEach-Object {
        $script:EgnyteWasInstalled = $true
        try {
            Write-Log "Stopping additional service: $($_.Name)"
            Stop-Service -Name $_.Name -Force -ErrorAction Stop
            Set-Service -Name $_.Name -StartupType Disabled -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Could not stop service $($_.Name): $_" -Level 'WARNING'
        }
    }
    
    Start-Sleep -Seconds 2
}

function Uninstall-EgnyteMSI {
    Write-Log "Uninstalling Egnyte via MSI (primary method)..."
    
    # Get all Egnyte products from registry
    $uninstallPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    
    $egnyteProducts = @()
    foreach ($path in $uninstallPaths) {
        $products = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | 
            Where-Object { $_.DisplayName -like '*Egnyte*' }
        if ($products) {
            $egnyteProducts += $products
        }
    }
    
    if ($egnyteProducts.Count -gt 0) {
        $script:EgnyteWasInstalled = $true
        foreach ($product in $egnyteProducts) {
            Write-Log "Found: $($product.DisplayName) v$($product.DisplayVersion)"
            
            # Try MSI uninstall first (most reliable)
            if ($product.PSChildName -match '^\{[A-F0-9-]+\}$') {
                $productCode = $product.PSChildName
                Write-Log "Uninstalling via MSI product code: $productCode"
                
                $msiArgs = "/x `"$productCode`" /qn /norestart REBOOT=ReallySuppress /L*v `"$env:TEMP\EgnyteUninstall_MSI.log`""
                $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -PassThru -NoNewWindow
                
                if ($process.ExitCode -eq 0 -or $process.ExitCode -eq 3010) {
                    Write-Log "MSI uninstall successful (Exit: $($process.ExitCode))"
                } else {
                    Write-Log "MSI uninstall returned: $($process.ExitCode)" -Level 'WARNING'
                }
            }
            # Fallback to UninstallString
            elseif ($product.UninstallString) {
                Write-Log "Using UninstallString: $($product.UninstallString)"
                try {
                    $uninstallCmd = $product.UninstallString
                    if ($uninstallCmd -match 'msiexec') {
                        # Add silent switches if not present
                        if ($uninstallCmd -notmatch '/q') {
                            $uninstallCmd = $uninstallCmd -replace 'msiexec.exe', 'msiexec.exe /qn /norestart'
                        }
                    }
                    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList "/c `"$uninstallCmd`"" -Wait -PassThru -NoNewWindow
                    Write-Log "UninstallString completed (Exit: $($process.ExitCode))"
                } catch {
                    Write-Log "UninstallString failed: $_" -Level 'WARNING'
                }
            }
        }
    } else {
        Write-Log "No Egnyte products found in registry"
    }
    
    # Additional: Try to uninstall known Egnyte product codes
    $knownProductCodes = @(
        '{EDA50A6D-0C04-4E5C-8C1A-B95A91E13D09}',  # Egnyte Connect (common)
        '{6C4D29F8-EEF1-4979-9F24-55D43DD46D03}'   # Egnyte Desktop App (common)
    )
    
    foreach ($code in $knownProductCodes) {
        $testPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$code"
        if (Test-Path $testPath) {
            Write-Log "Found known product code: $code"
            $msiArgs = "/x `"$code`" /qn /norestart REBOOT=ReallySuppress"
            Start-Process -FilePath 'msiexec.exe' -ArgumentList $msiArgs -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds 5
}

function Remove-EgnytePackages {
    Write-Log "Removing Egnyte via PackageManagement (backup method)..."
    
    $appNames = @(
        'Egnyte Desktop App',
        'Egnyte Connect', 
        'Egnyte',
        'Egnyte Drive'
    )
    
    foreach ($appName in $appNames) {
        try {
            $package = Get-Package -Name $appName -ErrorAction SilentlyContinue
            if ($package) {
                $script:EgnyteWasInstalled = $true
                Write-Log "Removing package: $($package.Name)"
                $package | Uninstall-Package -Force -ErrorAction SilentlyContinue
            }
        } catch {
            # This is expected to fail sometimes
        }
    }
}

function Remove-EgnyteFiles {
    Write-Log "Removing Egnyte files and folders..."
    
    # System-level folders
    $systemFolders = @(
        "$env:ProgramFiles\Egnyte",
        "$env:ProgramFiles\Egnyte Connect",
        "${env:ProgramFiles(x86)}\Egnyte",
        "${env:ProgramFiles(x86)}\Egnyte Connect",
        "$env:ProgramData\Egnyte",
        "$env:ProgramData\EgnyteDrive",
        "$env:ProgramData\Egnyte Connect"
    )
    
    foreach ($folder in $systemFolders) {
        if (Test-Path $folder) {
            $script:EgnyteWasInstalled = $true
            Write-Log "Removing folder: $folder"
            try {
                # First, take ownership and reset permissions
                $acl = Get-Acl $folder -ErrorAction SilentlyContinue
                if ($acl) {
                    $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
                    $acl.SetOwner($adminSid)
                    Set-Acl -Path $folder -AclObject $acl -ErrorAction SilentlyContinue
                }
                
                # Remove with retry logic
                for ($i = 1; $i -le 3; $i++) {
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                    if (-not (Test-Path $folder)) { break }
                    Start-Sleep -Seconds 2
                }
                
                if (Test-Path $folder) {
                    Write-Log "Could not fully remove: $folder" -Level 'WARNING'
                }
            } catch {
                Write-Log "Error removing $folder : $_" -Level 'WARNING'
            }
        }
    }
    
    # User profile folders - iterate all user profiles
    $userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
    
    foreach ($profile in $userProfiles) {
        $userFolders = @(
            (Join-Path $profile.FullName 'AppData\Local\Egnyte'),
            (Join-Path $profile.FullName 'AppData\Local\Egnyte Drive'),
            (Join-Path $profile.FullName 'AppData\Local\Egnyte Connect'),
            (Join-Path $profile.FullName 'AppData\LocalLow\Egnyte'),
            (Join-Path $profile.FullName 'AppData\Roaming\Egnyte'),
            (Join-Path $profile.FullName 'AppData\Roaming\EgnyteDrive')
        )
        
        foreach ($folder in $userFolders) {
            if (Test-Path $folder) {
                $script:EgnyteWasInstalled = $true
                Write-Log "Removing user folder: $folder"
                try {
                    Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Log "Could not remove user folder $folder : $_" -Level 'WARNING'
                }
            }
        }
    }
    
    # Remove SYSTEM profile Egnyte folders
    $systemProfilePaths = @(
        'C:\Windows\System32\config\systemprofile\AppData\Roaming\EgnyteDrive',
        'C:\Windows\System32\config\systemprofile\AppData\Local\Egnyte',
        'C:\Windows\SysWOW64\config\systemprofile\AppData\Roaming\EgnyteDrive',
        'C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Egnyte'
    )
    
    foreach ($folder in $systemProfilePaths) {
        if (Test-Path $folder) {
            Write-Log "Removing SYSTEM profile folder: $folder"
            Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-EgnyteRegistry {
    Write-Log "Cleaning Egnyte registry entries..."
    
    $registryPaths = @(
        'HKLM:\Software\Egnyte',
        'HKLM:\Software\Wow6432Node\Egnyte',
        'HKCU:\Software\Egnyte'
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            $script:EgnyteWasInstalled = $true
            Write-Log "Removing registry key: $path"
            try {
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Log "Could not remove registry key $path : $_" -Level 'WARNING'
            }
        }
    }
    
    # Clean up user registry hives for all profiles
    $userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }
    
    foreach ($profile in $userProfiles) {
        $ntUserPath = Join-Path $profile.FullName 'NTUSER.DAT'
        if (Test-Path $ntUserPath) {
            $tempHiveName = "TempHive_$($profile.Name)"
            try {
                # Load the user's registry hive
                $null = reg load "HKU\$tempHiveName" $ntUserPath 2>$null
                if ($?) {
                    $userEgnytePath = "Registry::HKEY_USERS\$tempHiveName\Software\Egnyte"
                    if (Test-Path $userEgnytePath) {
                        Write-Log "Removing Egnyte registry for user: $($profile.Name)"
                        Remove-Item -Path $userEgnytePath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    # Unload the hive
                    [gc]::Collect()
                    Start-Sleep -Seconds 1
                    $null = reg unload "HKU\$tempHiveName" 2>$null
                }
            } catch {
                Write-Log "Could not process registry for user $($profile.Name): $_" -Level 'WARNING'
                # Try to unload anyway
                $null = reg unload "HKU\$tempHiveName" 2>$null
            }
        }
    }
}

function Remove-EgnyteScheduledTasks {
    Write-Log "Removing Egnyte scheduled tasks..."
    
    Get-ScheduledTask | Where-Object { $_.TaskName -like '*Egnyte*' -or $_.TaskPath -like '*Egnyte*' } | ForEach-Object {
        $script:EgnyteWasInstalled = $true
        Write-Log "Removing scheduled task: $($_.TaskName)"
        try {
            Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction Stop
        } catch {
            Write-Log "Could not remove scheduled task $($_.TaskName): $_" -Level 'WARNING'
        }
    }
}

function Remove-EgnyteStartupEntries {
    Write-Log "Removing Egnyte startup entries..."
    
    # Registry Run keys
    $runKeys = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    )
    
    foreach ($key in $runKeys) {
        if (Test-Path $key) {
            $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Value -like '*Egnyte*' } | ForEach-Object {
                Write-Log "Removing startup entry: $($_.Name) from $key"
                try {
                    Remove-ItemProperty -Path $key -Name $_.Name -Force -ErrorAction Stop
                } catch {
                    Write-Log "Could not remove startup entry $($_.Name): $_" -Level 'WARNING'
                }
            }
        }
    }
    
    # Startup folders
    $startupFolders = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    )
    
    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            Get-ChildItem -Path $folder -Filter '*Egnyte*' -ErrorAction SilentlyContinue | ForEach-Object {
                Write-Log "Removing startup shortcut: $($_.FullName)"
                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Remove-EgnyteShellExtensions {
    Write-Log "Removing Egnyte shell extensions..."
    
    # Unregister shell extensions (overlay icons, context menu)
    $shellExtensionDlls = @(
        "${env:ProgramFiles(x86)}\Egnyte Connect\libEgnyteDriveWinShOverlay.dll",
        "${env:ProgramFiles(x86)}\Egnyte Connect\libEgnyteDriveWinShOverlay32.dll",
        "$env:ProgramFiles\Egnyte Connect\libEgnyteDriveWinShOverlay.dll"
    )
    
    foreach ($dll in $shellExtensionDlls) {
        if (Test-Path $dll) {
            Write-Log "Unregistering shell extension: $dll"
            Start-Process -FilePath 'regsvr32.exe' -ArgumentList "/u /s `"$dll`"" -Wait -NoNewWindow -ErrorAction SilentlyContinue
        }
    }
}
#endregion

#region Main Execution
Write-Log "=========================================="
Write-Log "EGNYTE NUKE SCRIPT - NinjaOne RMM"
Write-Log "=========================================="
Write-Log "Computer: $env:COMPUTERNAME"
Write-Log "User Context: $env:USERNAME"
Write-Log "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Log "=========================================="

# Check for admin rights
if (-not (Test-Administrator)) {
    Write-Log "This script requires administrator privileges!" -Level 'ERROR'
    Stop-Transcript -ErrorAction SilentlyContinue
    exit 2
}

try {
    # Phase 1: Stop everything
    Write-Log "`n--- PHASE 1: Stopping Egnyte Components ---"
    Stop-EgnyteProcesses
    Stop-EgnyteServices
    
    # Phase 2: Uninstall
    Write-Log "`n--- PHASE 2: Uninstalling Egnyte ---"
    Uninstall-EgnyteMSI
    Remove-EgnytePackages
    
    # Phase 3: Cleanup
    Write-Log "`n--- PHASE 3: Cleaning Up Remnants ---"
    Remove-EgnyteShellExtensions
    Remove-EgnyteScheduledTasks
    Remove-EgnyteStartupEntries
    Remove-EgnyteFiles
    Remove-EgnyteRegistry
    
    # Final process kill (in case anything restarted)
    Stop-EgnyteProcesses
    
    Write-Log "`n=========================================="
    
    # Determine exit code
    if (-not $script:EgnyteWasInstalled) {
        Write-Log "Egnyte was not installed on this system."
        Write-Log "Exit Code: 100 (Nothing to remove)"
        $exitCode = 100
    } elseif ($script:HasErrors) {
        Write-Log "Egnyte removal completed with warnings." -Level 'WARNING'
        Write-Log "Some components may need manual removal."
        Write-Log "Exit Code: 1 (Partial success)"
        $exitCode = 1
    } else {
        Write-Log "Egnyte removal completed successfully!"
        Write-Log "Exit Code: 0 (Success)"
        $exitCode = 0
    }
    
    # Handle reboot
    if ($ForceReboot -and $script:EgnyteWasInstalled) {
        Write-Log "`nReboot scheduled in $RebootDelaySeconds seconds..."
        Write-Log "Use 'shutdown /a' to abort if needed."
        shutdown.exe /r /t $RebootDelaySeconds /c "Egnyte removal complete - System will restart" /d p:4:1
    } else {
        Write-Log "`nNo automatic reboot. Schedule reboot via NinjaOne if needed."
    }
    
} catch {
    Write-Log "Critical error during execution: $_" -Level 'ERROR'
    Write-Log $_.ScriptStackTrace -Level 'ERROR'
    $exitCode = 2
}

Write-Log "=========================================="
Write-Log "Script completed. Log saved to: $transcriptPath"

try { Stop-Transcript } catch { }

exit $exitCode
#endregion
