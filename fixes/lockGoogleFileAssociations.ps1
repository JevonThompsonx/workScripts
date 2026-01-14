# Lock Google File Associations to System Default (Egnyte) v2
# Run as Administrator
# Purpose: Prevent Google Drive from hijacking file associations

#Requires -RunAsAdministrator

param(
    [switch]$Unlock  # Use -Unlock to reverse the lock
)

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$extensions = @(".gdoc", ".gsheet", ".gslides")
$basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"

Write-Host "`n=== Google File Association Lock/Unlock ===" -ForegroundColor Cyan
Write-Host "Running as: $currentUser" -ForegroundColor DarkGray
Write-Host "Mode: $(if ($Unlock) { 'UNLOCK' } else { 'LOCK' })" -ForegroundColor $(if ($Unlock) { 'Yellow' } else { 'Green' })

# Create HKCR drive if needed
if (!(Test-Path "HKCR:")) { 
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null 
}

# === UNLOCK MODE ===
if ($Unlock) {
    Write-Host "`n[Unlocking] Removing Deny ACLs..." -ForegroundColor Yellow
    
    foreach ($ext in $extensions) {
        $fullPath = "$basePath\$ext"
        
        if (!(Test-Path $fullPath)) {
            Write-Host "  $ext - Not found (nothing to unlock)" -ForegroundColor DarkGray
            continue
        }
        
        try {
            $acl = Get-Acl $fullPath
            
            # Find and remove Deny rules for current user
            $denyRules = $acl.Access | Where-Object { 
                $_.AccessControlType -eq 'Deny' -and 
                $_.IdentityReference.Value -eq $currentUser 
            }
            
            if ($denyRules) {
                foreach ($rule in $denyRules) {
                    $acl.RemoveAccessRule($rule) | Out-Null
                }
                
                # Re-enable inheritance
                $acl.SetAccessRuleProtection($false, $false)
                Set-Acl -Path $fullPath -AclObject $acl
                Write-Host "  $ext - UNLOCKED" -ForegroundColor Green
            } else {
                Write-Host "  $ext - No lock found" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  $ext - Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Unlock Complete ===" -ForegroundColor Cyan
    Write-Host "Users can now change file associations via 'Open With'." -ForegroundColor White
    exit 0
}

# === LOCK MODE ===

# 1. Verify Egnyte is actually registered in the System (HKCR)
Write-Host "`n[1/3] Verifying Egnyte installation..." -ForegroundColor Yellow

$missingProgIDs = @()
$egnyteMappings = @{
    ".gdoc"    = "Egnyte.gdoc"
    ".gsheet"  = "Egnyte.gsheet"
    ".gslides" = "Egnyte.gslides"
}

foreach ($ext in $extensions) {
    $progId = $egnyteMappings[$ext]
    if (Test-Path "HKCR:\$progId") {
        Write-Host "      Found: $progId" -ForegroundColor Green
    } else {
        $missingProgIDs += $progId
        Write-Host "      MISSING: $progId" -ForegroundColor Red
    }
}

if ($missingProgIDs.Count -gt 0) {
    Write-Host "`nERROR: Egnyte does not appear to be fully installed." -ForegroundColor Red
    Write-Host "Missing ProgIDs: $($missingProgIDs -join ', ')" -ForegroundColor Red
    Write-Host "`nPlease install Egnyte Desktop App BEFORE running this script." -ForegroundColor Yellow
    exit 1
}

# 2. Clean up any existing UserChoice and prepare keys
Write-Host "`n[2/3] Preparing registry keys..." -ForegroundColor Yellow

foreach ($ext in $extensions) {
    $fullPath = "$basePath\$ext"

    # Ensure the parent key exists
    if (!(Test-Path $fullPath)) {
        New-Item -Path $basePath -Name $ext -Force | Out-Null
        Write-Host "      Created: $fullPath" -ForegroundColor DarkGray
    }

    # Remove any existing UserChoice to force system fallback
    $userChoicePath = "$fullPath\UserChoice"
    if (Test-Path $userChoicePath) {
        try {
            # Take ownership first (UserChoice has special protection)
            $key = Get-Item $userChoicePath
            $acl = $key.GetAccessControl()
            $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)
            $key.SetAccessControl($acl)
            
            Remove-Item -Path $userChoicePath -Force -ErrorAction Stop
            Write-Host "      Removed UserChoice for $ext" -ForegroundColor Yellow
        } catch {
            Write-Host "      Warning: Could not remove UserChoice for $ext (may already be locked)" -ForegroundColor DarkYellow
        }
    }
}

# 3. Apply the Lock (Deny Write Permissions)
Write-Host "`n[3/3] Applying Deny ACLs..." -ForegroundColor Yellow

$successCount = 0
foreach ($ext in $extensions) {
    $fullPath = "$basePath\$ext"
    
    try {
        $acl = Get-Acl $fullPath
        
        # Disable inheritance to ensure our Deny rule sticks
        # Parameters: isProtected, preserveInheritance
        $acl.SetAccessRuleProtection($true, $true)

        # Deny the CURRENT USER from creating subkeys (preventing UserChoice creation)
        # These permissions block Google Drive's self-healing mechanism
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $currentUser,
            "CreateSubKey,SetValue,Delete,ChangePermissions,TakeOwnership",
            "ContainerInherit",  # Applies to subkeys
            "None",              # No propagation delay
            "Deny"               # DENY access type
        )
        
        $acl.AddAccessRule($rule)
        Set-Acl -Path $fullPath -AclObject $acl
        
        Write-Host "      LOCKED: $ext" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "      FAILED: $ext - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Summary
Write-Host "`n=== Lock Complete ===" -ForegroundColor Cyan
if ($successCount -eq $extensions.Count) {
    Write-Host @"

SUCCESS: All $successCount extensions locked.
Google Drive will now be unable to hijack these file types.

To verify, you can:
  1. Reinstall Google Drive
  2. Open a .gdoc file - it should open with Egnyte

To reverse this lock later, run:
  .\lockGoogleFileAssociations.ps1 -Unlock

"@ -ForegroundColor White
} else {
    Write-Host "`nWARNING: Only $successCount of $($extensions.Count) extensions locked." -ForegroundColor Yellow
    Write-Host "Review errors above and retry if needed." -ForegroundColor Yellow
}
