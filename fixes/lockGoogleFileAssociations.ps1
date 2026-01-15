# Lock Google File Associations v5
# Run as Administrator  
# Purpose: Lock file associations to Egnyte, prevent Google Drive hijacking
# Run AFTER installing Egnyte, BEFORE installing Google Drive

#Requires -RunAsAdministrator

param(
    [switch]$Unlock  # Use -Unlock to reverse
)

$LogPath = "$env:TEMP\GoogleAssocLock_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -ErrorAction SilentlyContinue | Out-Null

$extensions = @(".gdoc", ".gsheet", ".gslides")
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

Write-Host "`n=== Google File Association Lock v5 ===" -ForegroundColor Cyan
Write-Host "Running as: $currentUser" -ForegroundColor DarkGray
Write-Host "Mode: $(if ($Unlock) { 'UNLOCK' } else { 'LOCK' })" -ForegroundColor $(if ($Unlock) { 'Yellow' } else { 'Green' })
Write-Host "Log: $LogPath" -ForegroundColor DarkGray

# Create HKCR drive
if (!(Test-Path "HKCR:")) { 
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script | Out-Null 
}

# Helper: Apply Deny ACL
function Set-DenyAcl {
    param([string]$RegPath, [string]$User, [Microsoft.Win32.RegistryKey]$Hive = [Microsoft.Win32.Registry]::CurrentUser)
    try {
        $key = $Hive.OpenSubKey($RegPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor
            [System.Security.AccessControl.RegistryRights]::ReadPermissions)
        if ($key) {
            $acl = $key.GetAccessControl()
            $acl.SetAccessRuleProtection($true, $true)
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                $User,
                [System.Security.AccessControl.RegistryRights]"CreateSubKey,SetValue,Delete,ChangePermissions,TakeOwnership",
                [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Deny)
            $acl.AddAccessRule($rule)
            $key.SetAccessControl($acl)
            $key.Close()
            return $true
        }
    } catch { Write-Host "      ACL Error: $($_.Exception.Message)" -ForegroundColor Red }
    return $false
}

# Helper: Remove Deny ACL
function Remove-DenyAcl {
    param([string]$RegPath, [Microsoft.Win32.RegistryKey]$Hive = [Microsoft.Win32.Registry]::CurrentUser)
    try {
        $key = $Hive.OpenSubKey($RegPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions)
        if ($key) {
            $acl = $key.GetAccessControl()
            $denyRules = @($acl.Access | Where-Object { $_.AccessControlType -eq 'Deny' })
            if ($denyRules.Count -gt 0) {
                foreach ($rule in $denyRules) { $acl.RemoveAccessRule($rule) | Out-Null }
                $acl.SetAccessRuleProtection($false, $false)
                $key.SetAccessControl($acl)
            }
            $key.Close()
            return $true
        }
    } catch { }
    return $false
}

# === UNLOCK MODE ===
if ($Unlock) {
    Write-Host "`n[1/3] Unlocking HKCU\SOFTWARE\Classes..." -ForegroundColor Yellow
    foreach ($ext in $extensions) {
        Remove-DenyAcl -RegPath "SOFTWARE\Classes\$ext" | Out-Null
        $path = "HKCU:\SOFTWARE\Classes\$ext"
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "      Removed override: $ext" -ForegroundColor Green
        } else {
            Write-Host "      No override found: $ext" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n[2/3] Unlocking HKCU FileExts..." -ForegroundColor Yellow
    foreach ($ext in $extensions) {
        $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
        if (Remove-DenyAcl -RegPath $regPath) {
            Write-Host "      Unlocked: $ext" -ForegroundColor Green
        } else {
            Write-Host "      No lock or not found: $ext" -ForegroundColor DarkGray
        }
    }
    
    Write-Host "`n[3/3] Restarting Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer
    
    Write-Host "`n=== Unlock Complete ===" -ForegroundColor Cyan
    Write-Host "Google Drive can now reclaim associations if reinstalled." -ForegroundColor White
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 0
}

# === LOCK MODE ===

# 1. Detect current handlers (should be Egnyte after fresh install)
Write-Host "`n[1/5] Detecting current file handlers..." -ForegroundColor Yellow

$handlers = @{}
foreach ($ext in $extensions) {
    $handler = $null
    $source = $null
    
    # Check HKCR for current handler
    $hkcrPath = "HKCR:\$ext\shell\open\command"
    if (Test-Path $hkcrPath) {
        $handler = (Get-ItemProperty -Path $hkcrPath -Name "(default)" -ErrorAction SilentlyContinue).'(default)'
        $source = "HKCR"
    }
    
    if ($handler -and $handler -notlike "*Google*") {
        $handlers[$ext] = $handler
        Write-Host "      $ext -> $handler" -ForegroundColor Green
    } elseif ($handler -like "*Google*") {
        Write-Host "      $ext -> Google Drive (WARNING: Run cleanup first!)" -ForegroundColor Red
        $handlers[$ext] = $null
    } else {
        Write-Host "      $ext -> No handler found (Egnyte may not be installed)" -ForegroundColor Yellow
        $handlers[$ext] = $null
    }
}

# Check if we have valid handlers
$validHandlers = ($handlers.Values | Where-Object { $_ -ne $null }).Count
if ($validHandlers -eq 0) {
    Write-Host "`nERROR: No valid handlers found. Please ensure:" -ForegroundColor Red
    Write-Host "  1. Egnyte is installed" -ForegroundColor Yellow
    Write-Host "  2. You've opened a .gdoc file with Egnyte at least once" -ForegroundColor Yellow
    Write-Host "  3. Google Drive is not currently registered" -ForegroundColor Yellow
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

# 2. Create HKCU\SOFTWARE\Classes overrides with Egnyte's handler
Write-Host "`n[2/5] Creating HKCU\SOFTWARE\Classes overrides..." -ForegroundColor Yellow

foreach ($ext in $extensions) {
    $path = "HKCU:\SOFTWARE\Classes\$ext"
    $handler = $handlers[$ext]
    
    if (-not $handler) {
        Write-Host "      Skipping $ext (no handler)" -ForegroundColor DarkYellow
        continue
    }
    
    try {
        # Remove existing if present (unlock first)
        Remove-DenyAcl -RegPath "SOFTWARE\Classes\$ext" | Out-Null
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Create fresh structure
        New-Item -Path $path -Force | Out-Null
        Set-ItemProperty -Path $path -Name "(default)" -Value ""  # Empty to not follow ProgID chain
        
        # Create shell\open\command with Egnyte's handler
        $cmdPath = "$path\shell\open\command"
        New-Item -Path $cmdPath -Force | Out-Null
        Set-ItemProperty -Path $cmdPath -Name "(default)" -Value $handler
        
        Write-Host "      Created override: $ext" -ForegroundColor Green
    } catch {
        Write-Host "      Failed to create $ext : $_" -ForegroundColor Red
    }
}

# 3. Clean OpenWithProgids and OpenWithList (remove any Google entries)
Write-Host "`n[3/5] Cleaning FileExts OpenWith entries..." -ForegroundColor Yellow

foreach ($ext in $extensions) {
    $basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    
    # Unlock if locked from previous run
    Remove-DenyAcl -RegPath $regPath | Out-Null
    
    # Ensure base key exists
    if (!(Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }
    
    # Remove UserChoice if exists
    $userChoice = "$basePath\UserChoice"
    if (Test-Path $userChoice) {
        Remove-DenyAcl -RegPath "$regPath\UserChoice" | Out-Null
        Remove-Item -Path $userChoice -Force -ErrorAction SilentlyContinue
        Write-Host "      Removed UserChoice: $ext" -ForegroundColor Yellow
    }
    
    # Clean OpenWithProgids
    $progids = "$basePath\OpenWithProgids"
    if (Test-Path $progids) {
        $item = Get-Item $progids -ErrorAction SilentlyContinue
        if ($item) {
            $googleEntries = $item.GetValueNames() | Where-Object { $_ -like "*Google*" }
            foreach ($entry in $googleEntries) {
                Remove-ItemProperty -Path $progids -Name $entry -ErrorAction SilentlyContinue
                Write-Host "      Removed from OpenWithProgids: $entry" -ForegroundColor Yellow
            }
        }
    }
    
    # Clean OpenWithList
    $list = "$basePath\OpenWithList"
    if (Test-Path $list) {
        $item = Get-Item $list -ErrorAction SilentlyContinue
        if ($item) {
            $toRemove = @()
            foreach ($prop in ($item.GetValueNames() | Where-Object { $_ -ne "MRUList" })) {
                $val = (Get-ItemProperty $list -ErrorAction SilentlyContinue).$prop
                if ($val -like "*Google*") {
                    $toRemove += $prop
                    Remove-ItemProperty -Path $list -Name $prop -ErrorAction SilentlyContinue
                    Write-Host "      Removed from OpenWithList: $prop ($val)" -ForegroundColor Yellow
                }
            }
            # Fix MRUList
            if ($toRemove.Count -gt 0) {
                $mru = (Get-ItemProperty $list -Name MRUList -ErrorAction SilentlyContinue).MRUList
                if ($mru) {
                    $newMru = -join ($mru.ToCharArray() | Where-Object { $toRemove -notcontains $_ })
                    if ($newMru) {
                        Set-ItemProperty -Path $list -Name MRUList -Value $newMru -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }
}

# 4. Lock HKCU\SOFTWARE\Classes overrides
Write-Host "`n[4/5] Locking HKCU\SOFTWARE\Classes..." -ForegroundColor Yellow
$classesLocked = 0

foreach ($ext in $extensions) {
    if ($handlers[$ext]) {  # Only lock if we created an override
        if (Set-DenyAcl -RegPath "SOFTWARE\Classes\$ext" -User $currentUser) {
            Write-Host "      LOCKED: HKCU\SOFTWARE\Classes\$ext" -ForegroundColor Green
            $classesLocked++
        } else {
            Write-Host "      FAILED: HKCU\SOFTWARE\Classes\$ext" -ForegroundColor Red
        }
    }
}

# 5. Lock HKCU FileExts
Write-Host "`n[5/5] Locking HKCU FileExts..." -ForegroundColor Yellow
$fileExtsLocked = 0

foreach ($ext in $extensions) {
    $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    if (Set-DenyAcl -RegPath $regPath -User $currentUser) {
        Write-Host "      LOCKED: FileExts\$ext" -ForegroundColor Green
        $fileExtsLocked++
    } else {
        Write-Host "      FAILED: FileExts\$ext" -ForegroundColor Red
    }
}

# Cleanup
Remove-PSDrive -Name HKCR -ErrorAction SilentlyContinue

# Summary
$totalLocked = $classesLocked + $fileExtsLocked
Write-Host "`n=== Lock Complete ===" -ForegroundColor Cyan

if ($totalLocked -ge 4) {  # At least some locks applied
    Write-Host @"

SUCCESS: $totalLocked locks applied

What was done:
  1. Created HKCU\SOFTWARE\Classes overrides with Egnyte's handler
  2. Cleaned Google entries from OpenWithProgids/OpenWithList  
  3. Locked HKCU\SOFTWARE\Classes (blocks Google from overriding)
  4. Locked HKCU FileExts (blocks UserChoice hijacking)

You can now install Google Drive - it will NOT be able to hijack
these file associations.

To verify after installing Google Drive:
  - Right-click a .gdoc file > Properties
  - Should show Egnyte (or your system default), NOT Google Drive

To unlock later: Run this script with -Unlock parameter

Log: $LogPath
"@ -ForegroundColor White
} else {
    Write-Host "`nWARNING: Only $totalLocked locks applied. Review errors above." -ForegroundColor Yellow
}

# Restart Explorer to apply changes
Write-Host "`nRestarting Explorer to apply changes..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Start-Process explorer

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
