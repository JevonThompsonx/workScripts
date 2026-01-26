# Cleanup Google Drive & Egnyte File Associations v6
# Run as Administrator
# Purpose: Complete cleanup before fresh Egnyte install

param(
    [switch]$NoPause
)

#Requires -RunAsAdministrator

$LogPath = "$env:TEMP\GoogleEgnyteCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n=== Google/Egnyte File Association Cleanup v6 ===" -ForegroundColor Cyan
Write-Host "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor DarkGray
Write-Host "Log: $LogPath" -ForegroundColor DarkGray

$extensions = @(".gdoc", ".gsheet", ".gslides")
$googleProgIds = @("GoogleDriveFS.gdoc", "GoogleDriveFS.gsheet", "GoogleDriveFS.gslides")
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

# Helper: Remove Deny ACLs from a registry path
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

# 1. Kill processes
Write-Host "`n[1/8] Stopping processes..." -ForegroundColor Yellow
@("GoogleDriveFS", "EgnyteDrive", "EgnyteClient") | ForEach-Object {
    $procs = @(Get-Process -Name $_ -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "      Stopped: $_" -ForegroundColor Green
        Start-Sleep -Milliseconds 500
    }
}

# 2. Remove our HKCU\SOFTWARE\Classes overrides (unlock first if locked)
Write-Host "`n[2/8] Removing HKCU\SOFTWARE\Classes overrides..." -ForegroundColor Yellow
foreach ($ext in $extensions) {
    $path = "HKCU:\SOFTWARE\Classes\$ext"
    Remove-DenyAcl -RegPath "SOFTWARE\Classes\$ext" | Out-Null
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "      Removed: $path" -ForegroundColor Green
    } else {
        Write-Host "      Not found (OK): $path" -ForegroundColor DarkGray
    }
}

# 3. Clean HKCU FileExts completely (unlock, then remove everything)
Write-Host "`n[3/8] Cleaning HKCU FileExts (full reset)..." -ForegroundColor Yellow
foreach ($ext in $extensions) {
    $basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    
    # Unlock if locked
    Remove-DenyAcl -RegPath $regPath | Out-Null
    
    if (Test-Path $basePath) {
        # Remove UserChoice (standard)
        $userChoice = "$basePath\UserChoice"
        if (Test-Path $userChoice) {
            Remove-DenyAcl -RegPath "$regPath\UserChoice" | Out-Null
            Remove-Item -Path $userChoice -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "      Removed UserChoice for $ext" -ForegroundColor Green
        }
        
        # Remove UserChoiceLatest (Windows 10/11 feature)
        $userChoiceLatest = "$basePath\UserChoiceLatest"
        if (Test-Path $userChoiceLatest) {
            Remove-DenyAcl -RegPath "$regPath\UserChoiceLatest" | Out-Null
            Remove-Item -Path $userChoiceLatest -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "      Removed UserChoiceLatest for $ext" -ForegroundColor Green
        }
        
        # Clear OpenWithProgids completely
        $progids = "$basePath\OpenWithProgids"
        if (Test-Path $progids) {
            $item = Get-Item $progids -ErrorAction SilentlyContinue
            if ($item) {
                $values = $item.GetValueNames()
                foreach ($val in $values) {
                    Remove-ItemProperty -Path $progids -Name $val -ErrorAction SilentlyContinue
                }
                Write-Host "      Cleared OpenWithProgids for $ext ($($values.Count) entries)" -ForegroundColor Green
            }
        }
        
        # Clear OpenWithList completely
        $list = "$basePath\OpenWithList"
        if (Test-Path $list) {
            Remove-Item -Path $list -Force -Recurse -ErrorAction SilentlyContinue
            Write-Host "      Removed OpenWithList for $ext" -ForegroundColor Green
        }
    }
}

# 4. Clean ApplicationAssociationToasts (the "don't ask again" cache)
Write-Host "`n[4/8] Cleaning ApplicationAssociationToasts..." -ForegroundColor Yellow
$toastsPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ApplicationAssociationToasts"
if (Test-Path $toastsPath) {
    $toasts = Get-Item $toastsPath
    $toRemove = @()
    foreach ($ext in $extensions) {
        $extPattern = $ext.TrimStart('.')  # gdoc, gsheet, gslides
        $toasts.GetValueNames() | Where-Object { $_ -like "*$extPattern*" } | ForEach-Object {
            $toRemove += $_
        }
    }
    foreach ($val in $toRemove) {
        Remove-ItemProperty -Path $toastsPath -Name $val -ErrorAction SilentlyContinue
        Write-Host "      Removed toast: $val" -ForegroundColor Green
    }
    if ($toRemove.Count -eq 0) {
        Write-Host "      No cached toasts found (OK)" -ForegroundColor DarkGray
    }
}

# 5. Clean ApplicationAssociations (another cache location)
Write-Host "`n[5/8] Cleaning ApplicationAssociations cache..." -ForegroundColor Yellow
$appAssocPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"
foreach ($ext in $extensions) {
    $assocPath = "$appAssocPath\$ext\Application"
    if (Test-Path $assocPath) {
        Remove-Item -Path $assocPath -Force -Recurse -ErrorAction SilentlyContinue
        Write-Host "      Removed Application cache for $ext" -ForegroundColor Green
    }
}

# 6. Clean HKCR extensions (requires admin)
Write-Host "`n[6/8] Cleaning HKCR extensions..." -ForegroundColor Yellow
if (!(Test-Path "HKCR:")) { 
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Scope Script | Out-Null 
}

foreach ($ext in $extensions) {
    $path = "HKCR:\$ext"
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "      Removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "      Warning: Could not remove $path (may need reboot)" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      Not found (OK): $path" -ForegroundColor DarkGray
    }
}

# Also clean gdoc_auto_file and similar auto-generated ProgIDs
$autoProgIds = @("gdoc_auto_file", "gsheet_auto_file", "gslides_auto_file")
foreach ($progId in $autoProgIds) {
    $path = "HKCR:\$progId"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "      Removed auto ProgID: $progId" -ForegroundColor Green
    }
}

# 7. Clean HKCR Google ProgIDs
Write-Host "`n[7/8] Cleaning HKCR Google ProgIDs..." -ForegroundColor Yellow
foreach ($progId in $googleProgIds) {
    $path = "HKCR:\$progId"
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "      Removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "      Warning: Could not remove $path" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      Not found (OK): $path" -ForegroundColor DarkGray
    }
}

# Also clean Egnyte ProgIDs from HKCR (for fresh install)
$egnyteProgIds = @("EgnyteDrive.gdoc", "EgnyteDrive.gsheet", "EgnyteDrive.gslides", "Applications\EgnyteDrive.exe")
foreach ($progId in $egnyteProgIds) {
    $path = "HKCR:\$progId"
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "      Removed Egnyte ProgID: $progId" -ForegroundColor Green
    }
}

# 8. Verify
Write-Host "`n[8/8] Verification..." -ForegroundColor Yellow
$remaining = @()
foreach ($ext in $extensions) {
    if (Test-Path "HKCR:\$ext") { $remaining += "HKCR:$ext" }
    if (Test-Path "HKCU:\SOFTWARE\Classes\$ext") { $remaining += "HKCU Classes:$ext" }
    
    $fileExtPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    if (Test-Path "$fileExtPath\UserChoice") { $remaining += "UserChoice:$ext" }
    if (Test-Path "$fileExtPath\UserChoiceLatest") { $remaining += "UserChoiceLatest:$ext" }
}
foreach ($progId in $googleProgIds) {
    if (Test-Path "HKCR:\$progId") { $remaining += "HKCR:$progId" }
}

if ($remaining.Count -eq 0) {
    Write-Host "      All file associations cleared!" -ForegroundColor Green
} else {
    Write-Host "      Some items remain (will clear after reboot):" -ForegroundColor Yellow
    $remaining | ForEach-Object { Write-Host "        - $_" -ForegroundColor DarkYellow }
}

if (-not $NoPause) {
    Write-Host "`nPress Enter to exit..."
    Read-Host | Out-Null
}

Remove-PSDrive -Name HKCR -ErrorAction SilentlyContinue

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host @"

Next Steps:
  1. REBOOT the computer (required to clear shell cache!)
  2. Install Egnyte Desktop App
  3. Log into Egnyte and open a .gdoc file once to register handler
  4. Run the Lock script BEFORE installing Google Drive

Log saved to: $LogPath
"@ -ForegroundColor White

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
