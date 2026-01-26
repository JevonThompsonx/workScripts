#Requires -Version 5.1
<#
.SYNOPSIS
    DRY RUN - Egnyte Nuke Script Test
    This script SIMULATES the nuke process without making any changes.
    
.DESCRIPTION
    Tests all detection and logic without:
    - Stopping processes
    - Stopping services
    - Uninstalling software
    - Deleting files
    - Modifying registry
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "EGNYTE NUKE SCRIPT - DRY RUN MODE" -ForegroundColor Cyan
Write-Host "NO CHANGES WILL BE MADE" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "User Context: $env:USERNAME"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "==========================================" -ForegroundColor Cyan

# Track what would be done
$script:EgnyteWasInstalled = $false
$wouldDo = @()

#region Administrator Check
Write-Host "`n[CHECK] Administrator Privileges" -ForegroundColor Cyan
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "  PASS: Running as Administrator" -ForegroundColor Green
} else {
    Write-Host "  FAIL: NOT running as Administrator - Script would exit with code 2" -ForegroundColor Red
}
#endregion

#region Process Detection
Write-Host "`n[PHASE 1] Process Detection" -ForegroundColor Cyan

$egnyteProcesses = @(
    'EgnyteClient',
    'EgnyteDrive', 
    'EgnyteSyncService',
    'EgnyteUpdate',
    'EgnyteDriveCollaborationProvider',
    'EgnyteHelpViewer',
    'CefSharp.BrowserSubprocess'
)

$foundProcesses = @()
foreach ($procName in $egnyteProcesses) {
    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if ($procs) {
        $script:EgnyteWasInstalled = $true
        foreach ($proc in $procs) {
            $foundProcesses += $proc
            Write-Host "  WOULD STOP: $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Yellow
            $wouldDo += "Stop process: $($proc.Name) (PID: $($proc.Id))"
        }
    }
}

# Wildcard check
Get-Process | Where-Object { $_.Name -like '*egnyte*' -and $_.Name -notin $egnyteProcesses } | ForEach-Object {
    Write-Host "  WOULD STOP (wildcard): $($_.Name) (PID: $($_.Id))" -ForegroundColor Yellow
    $wouldDo += "Stop process: $($_.Name) (PID: $($_.Id))"
}

if ($foundProcesses.Count -eq 0) {
    Write-Host "  No Egnyte processes found" -ForegroundColor Gray
}
#endregion

#region Service Detection
Write-Host "`n[PHASE 1] Service Detection" -ForegroundColor Cyan

$egnyteServices = @(
    'EgnyteDriveService',
    'EgnyteSyncService', 
    'egnytefs',
    'EgnyteWebDAVService',
    'EgnyteConnectDesktopUpdate'
)

$foundServices = @()
foreach ($svcName in $egnyteServices) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        $script:EgnyteWasInstalled = $true
        $foundServices += $svc
        Write-Host "  WOULD STOP & DISABLE: $($svc.Name) ($($svc.DisplayName)) - Status: $($svc.Status)" -ForegroundColor Yellow
        $wouldDo += "Stop and disable service: $($svc.Name)"
    }
}

# Wildcard check
Get-Service | Where-Object { ($_.Name -like '*egnyte*' -or $_.DisplayName -like '*Egnyte*') -and $_.Name -notin $egnyteServices } | ForEach-Object {
    Write-Host "  WOULD STOP & DISABLE (wildcard): $($_.Name) ($($_.DisplayName))" -ForegroundColor Yellow
    $wouldDo += "Stop and disable service: $($_.Name)"
}

if ($foundServices.Count -eq 0) {
    Write-Host "  No Egnyte services found" -ForegroundColor Gray
}
#endregion

#region MSI Uninstall Detection
Write-Host "`n[PHASE 2] MSI Product Detection" -ForegroundColor Cyan

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
        Write-Host "  FOUND: $($product.DisplayName) v$($product.DisplayVersion)" -ForegroundColor White
        
        if ($product.PSChildName -match '^\{[A-F0-9-]+\}$') {
            $productCode = $product.PSChildName
            Write-Host "  WOULD RUN: msiexec.exe /x `"$productCode`" /qn /norestart" -ForegroundColor Yellow
            $wouldDo += "MSI Uninstall: $($product.DisplayName) ($productCode)"
        } elseif ($product.UninstallString) {
            Write-Host "  WOULD RUN: $($product.UninstallString)" -ForegroundColor Yellow
            $wouldDo += "Uninstall via string: $($product.DisplayName)"
        }
    }
} else {
    Write-Host "  No Egnyte products found in registry" -ForegroundColor Gray
}
#endregion

#region File System Detection
Write-Host "`n[PHASE 3] File System Detection" -ForegroundColor Cyan

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
        try {
            $size = (Get-ChildItem $folder -Recurse -ErrorAction SilentlyContinue | 
                Where-Object { -not $_.PSIsContainer } | 
                Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            $sizeMB = [math]::Round($size/1MB, 2)
        } catch {
            $sizeMB = "unknown"
        }
        Write-Host "  WOULD DELETE: $folder ($sizeMB MB)" -ForegroundColor Yellow
        $wouldDo += "Delete folder: $folder"
    }
}

# User profile folders
$userProfiles = Get-ChildItem 'C:\Users' -Directory -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -notin @('Public', 'Default', 'Default User', 'All Users') }

$userFoldersFound = 0
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
            $userFoldersFound++
            Write-Host "  WOULD DELETE: $folder" -ForegroundColor Yellow
            $wouldDo += "Delete user folder: $folder"
        }
    }
}

if ($userFoldersFound -eq 0) {
    Write-Host "  No user profile Egnyte folders found" -ForegroundColor Gray
}

# SYSTEM profile folders
$systemProfilePaths = @(
    'C:\Windows\System32\config\systemprofile\AppData\Roaming\EgnyteDrive',
    'C:\Windows\System32\config\systemprofile\AppData\Local\Egnyte',
    'C:\Windows\SysWOW64\config\systemprofile\AppData\Roaming\EgnyteDrive',
    'C:\Windows\SysWOW64\config\systemprofile\AppData\Local\Egnyte'
)

foreach ($folder in $systemProfilePaths) {
    if (Test-Path $folder) {
        Write-Host "  WOULD DELETE: $folder" -ForegroundColor Yellow
        $wouldDo += "Delete SYSTEM profile folder: $folder"
    }
}
#endregion

#region Registry Detection
Write-Host "`n[PHASE 3] Registry Detection" -ForegroundColor Cyan

$registryPaths = @(
    'HKLM:\Software\Egnyte',
    'HKLM:\Software\Wow6432Node\Egnyte',
    'HKCU:\Software\Egnyte'
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        $script:EgnyteWasInstalled = $true
        Write-Host "  WOULD DELETE: $path" -ForegroundColor Yellow
        $wouldDo += "Delete registry key: $path"
    }
}

# Note about user hives
Write-Host "  NOTE: Would also clean Egnyte keys from all user registry hives" -ForegroundColor Gray
#endregion

#region Scheduled Tasks Detection
Write-Host "`n[PHASE 3] Scheduled Tasks Detection" -ForegroundColor Cyan

$tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | 
    Where-Object { $_.TaskName -like '*Egnyte*' -or $_.TaskPath -like '*Egnyte*' }

if ($tasks) {
    foreach ($task in $tasks) {
        Write-Host "  WOULD DELETE: $($task.TaskName) (State: $($task.State))" -ForegroundColor Yellow
        $wouldDo += "Delete scheduled task: $($task.TaskName)"
    }
} else {
    Write-Host "  No Egnyte scheduled tasks found" -ForegroundColor Gray
}
#endregion

#region Startup Entries Detection
Write-Host "`n[PHASE 3] Startup Entries Detection" -ForegroundColor Cyan

$runKeys = @(
    'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
)

$startupFound = $false
foreach ($key in $runKeys) {
    if (Test-Path $key) {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        $egnyteProps = $props.PSObject.Properties | Where-Object { $_.Value -like '*Egnyte*' }
        foreach ($prop in $egnyteProps) {
            $startupFound = $true
            Write-Host "  WOULD DELETE: $($prop.Name) from $key" -ForegroundColor Yellow
            $wouldDo += "Delete startup entry: $($prop.Name)"
        }
    }
}

if (-not $startupFound) {
    Write-Host "  No Egnyte startup entries found" -ForegroundColor Gray
}
#endregion

#region Shell Extensions Detection
Write-Host "`n[PHASE 3] Shell Extensions Detection" -ForegroundColor Cyan

$shellExtensionDlls = @(
    "${env:ProgramFiles(x86)}\Egnyte Connect\libEgnyteDriveWinShOverlay.dll",
    "${env:ProgramFiles(x86)}\Egnyte Connect\libEgnyteDriveWinShOverlay32.dll",
    "$env:ProgramFiles\Egnyte Connect\libEgnyteDriveWinShOverlay.dll"
)

$shellFound = $false
foreach ($dll in $shellExtensionDlls) {
    if (Test-Path $dll) {
        $shellFound = $true
        Write-Host "  WOULD UNREGISTER: $dll" -ForegroundColor Yellow
        $wouldDo += "Unregister shell extension: $dll"
    }
}

if (-not $shellFound) {
    Write-Host "  No Egnyte shell extensions to unregister" -ForegroundColor Gray
}
#endregion

#region Summary
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "DRY RUN SUMMARY" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

if (-not $script:EgnyteWasInstalled) {
    Write-Host "`nResult: Egnyte was NOT detected on this system" -ForegroundColor Gray
    Write-Host "Exit Code Would Be: 100 (Nothing to remove)" -ForegroundColor Gray
} else {
    Write-Host "`nResult: Egnyte IS installed on this system" -ForegroundColor White
    Write-Host "`nActions that WOULD be performed:" -ForegroundColor Yellow
    
    $wouldDo | ForEach-Object { 
        Write-Host "  - $_" -ForegroundColor Yellow 
    }
    
    Write-Host "`nTotal actions: $($wouldDo.Count)" -ForegroundColor White
    Write-Host "Exit Code Would Be: 0 (Success) or 1 (Partial if any errors)" -ForegroundColor Green
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "DRY RUN COMPLETE - NO CHANGES WERE MADE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
#endregion
