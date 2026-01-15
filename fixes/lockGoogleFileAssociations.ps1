# Lock Google File Associations to Prevent Hijacking v3
# Run as Administrator
# Purpose: Prevent Google Drive from hijacking file associations

#Requires -RunAsAdministrator

param(
    [switch]$Unlock  # Use -Unlock to reverse the lock
)

# Start logging for enterprise troubleshooting
$LogPath = "$env:TEMP\GoogleAssocLock_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -ErrorAction SilentlyContinue | Out-Null

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$extensions = @(".gdoc", ".gsheet", ".gslides")
$hkcuBase = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"

Write-Host "`n=== Google File Association Lock/Unlock v3 ===" -ForegroundColor Cyan
Write-Host "Running as: $currentUser" -ForegroundColor DarkGray
Write-Host "Log file: $LogPath" -ForegroundColor DarkGray
Write-Host "Mode: $(if ($Unlock) { 'UNLOCK' } else { 'LOCK' })" -ForegroundColor $(if ($Unlock) { 'Yellow' } else { 'Green' })

# Create HKCR drive if needed
$hkcrCreated = $false
if (!(Test-Path "HKCR:")) { 
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script | Out-Null
    $hkcrCreated = $true
}

# === UNLOCK MODE ===
if ($Unlock) {
    Write-Host "`n[Unlocking] Removing Deny ACLs..." -ForegroundColor Yellow
    
    foreach ($ext in $extensions) {
        $fullPath = "$hkcuBase\$ext"
        
        if (!(Test-Path $fullPath)) {
            Write-Host "  $ext - Not found (nothing to unlock)" -ForegroundColor DarkGray
            continue
        }
        
        try {
            # Use .NET for reliable ACL access
            $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
                $regPath,
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::ChangePermissions
            )
            
            if ($key) {
                $acl = $key.GetAccessControl()
                
                # Find and remove Deny rules
                $denyRules = @($acl.Access | Where-Object { 
                    $_.AccessControlType -eq 'Deny'
                })
                
                if ($denyRules.Count -gt 0) {
                    foreach ($rule in $denyRules) {
                        $acl.RemoveAccessRule($rule) | Out-Null
                    }
                    
                    # Re-enable inheritance
                    $acl.SetAccessRuleProtection($false, $false)
                    $key.SetAccessControl($acl)
                    Write-Host "  $ext - UNLOCKED" -ForegroundColor Green
                } else {
                    Write-Host "  $ext - No lock found" -ForegroundColor DarkGray
                }
                $key.Close()
            } else {
                Write-Host "  $ext - Could not open key" -ForegroundColor DarkYellow
            }
        } catch {
            Write-Host "  $ext - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if ($hkcrCreated) { Remove-PSDrive -Name HKCR -ErrorAction SilentlyContinue }
    Write-Host "`n=== Unlock Complete ===" -ForegroundColor Cyan
    Write-Host "Users can now change file associations via 'Open With'." -ForegroundColor White
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 0
}

# === LOCK MODE ===

# 1. Show current associations (informational only - we lock regardless)
Write-Host "`n[1/3] Current file associations (informational)..." -ForegroundColor Yellow

foreach ($ext in $extensions) {
    $handler = $null
    
    # Check HKCU UserChoice first
    $userChoicePath = "$hkcuBase\$ext\UserChoice"
    if (Test-Path $userChoicePath) {
        $handler = (Get-ItemProperty -Path $userChoicePath -Name ProgId -ErrorAction SilentlyContinue).ProgId
        if ($handler) {
            Write-Host "      $ext -> $handler (UserChoice)" -ForegroundColor White
            continue
        }
    }
    
    # Check HKCR default
    if (Test-Path "HKCR:\$ext") {
        $handler = (Get-ItemProperty -Path "HKCR:\$ext" -Name "(default)" -ErrorAction SilentlyContinue).'(default)'
        if ($handler) {
            Write-Host "      $ext -> $handler (System)" -ForegroundColor White
            continue
        }
    }
    
    Write-Host "      $ext -> (no handler - will use system default)" -ForegroundColor DarkGray
}

Write-Host "`n      Note: Locking will preserve current behavior and block Google Drive" -ForegroundColor DarkCyan

# 2. Clean up any existing UserChoice and prepare keys
Write-Host "`n[2/3] Preparing registry keys..." -ForegroundColor Yellow

foreach ($ext in $extensions) {
    $fullPath = "$hkcuBase\$ext"

    # Ensure the parent key exists
    if (!(Test-Path $fullPath)) {
        New-Item -Path $hkcuBase -Name $ext -Force | Out-Null
        Write-Host "      Created: $fullPath" -ForegroundColor DarkGray
    }

    # Remove any existing UserChoice that might be from Google Drive
    $userChoicePath = "$fullPath\UserChoice"
    if (Test-Path $userChoicePath) {
        try {
            # Use .NET for proper ACL access on protected UserChoice key
            $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\UserChoice"
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
                $regPath,
                [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                [System.Security.AccessControl.RegistryRights]::TakeOwnership
            )
            
            if ($key) {
                $acl = $key.GetAccessControl()
                $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
                $acl.SetOwner($currentSid)
                $key.SetAccessControl($acl)
                $key.Close()
                
                # Grant full control
                $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
                    $regPath,
                    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
                    [System.Security.AccessControl.RegistryRights]::ChangePermissions
                )
                
                if ($key) {
                    $acl = $key.GetAccessControl()
                    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                        $currentUser,
                        [System.Security.AccessControl.RegistryRights]::FullControl,
                        [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                        [System.Security.AccessControl.PropagationFlags]::None,
                        [System.Security.AccessControl.AccessControlType]::Allow
                    )
                    $acl.SetAccessRule($rule)
                    $key.SetAccessControl($acl)
                    $key.Close()
                }
            }
            
            Remove-Item -Path $userChoicePath -Force -ErrorAction Stop
            Write-Host "      Removed UserChoice for $ext" -ForegroundColor Yellow
        } catch {
            Write-Host "      Warning: Could not remove UserChoice for $ext - $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      No UserChoice for $ext (OK)" -ForegroundColor DarkGray
    }
}

# 3. Apply the Lock (Deny Write Permissions)
Write-Host "`n[3/3] Applying Deny ACLs to prevent Google Drive hijacking..." -ForegroundColor Yellow

$successCount = 0
foreach ($ext in $extensions) {
    $fullPath = "$hkcuBase\$ext"
    $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    
    try {
        # Use .NET for reliable ACL modification
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey(
            $regPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor 
            [System.Security.AccessControl.RegistryRights]::ReadPermissions
        )
        
        if ($key) {
            $acl = $key.GetAccessControl()
            
            # Disable inheritance to ensure our Deny rule sticks
            $acl.SetAccessRuleProtection($true, $true)

            # Deny the CURRENT USER from creating subkeys (preventing UserChoice creation)
            # These permissions block Google Drive's self-healing mechanism
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                $currentUser,
                [System.Security.AccessControl.RegistryRights]"CreateSubKey,SetValue,Delete,ChangePermissions,TakeOwnership",
                [System.Security.AccessControl.InheritanceFlags]::ContainerInherit,
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Deny
            )
            
            $acl.AddAccessRule($rule)
            $key.SetAccessControl($acl)
            $key.Close()
            
            Write-Host "      LOCKED: $ext" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "      FAILED: $ext - Could not open key" -ForegroundColor Red
        }
    } catch {
        Write-Host "      FAILED: $ext - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Cleanup
if ($hkcrCreated) { Remove-PSDrive -Name HKCR -ErrorAction SilentlyContinue }

# Summary
Write-Host "`n=== Lock Complete ===" -ForegroundColor Cyan
if ($successCount -eq $extensions.Count) {
    Write-Host @"

SUCCESS: All $successCount extensions locked.
Google Drive will now be unable to hijack these file types.

To verify:
  1. Install/reinstall Google Drive
  2. Open a .gdoc file - it should use current handler (not Google Drive)

To reverse this lock later, run:
  powershell -ExecutionPolicy Bypass -Command "IEX (irm 'URL') -Unlock"

Log saved to: $LogPath
"@ -ForegroundColor White
} else {
    Write-Host "`nWARNING: Only $successCount of $($extensions.Count) extensions locked." -ForegroundColor Yellow
    Write-Host "Review errors above and retry if needed." -ForegroundColor Yellow
    Write-Host "Log saved to: $LogPath" -ForegroundColor DarkGray
}

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
