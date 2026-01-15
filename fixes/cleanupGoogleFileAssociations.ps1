# Cleanup Google Drive & Egnyte File Associations v5
# Run as Administrator
# Purpose: Complete cleanup before fresh Egnyte install

#Requires -RunAsAdministrator

$LogPath = "$env:TEMP\GoogleEgnyteCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $LogPath -ErrorAction SilentlyContinue | Out-Null

Write-Host "`n=== Google/Egnyte File Association Cleanup v5 ===" -ForegroundColor Cyan
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
Write-Host "`n[1/6] Stopping processes..." -ForegroundColor Yellow
@("GoogleDriveFS", "EgnyteDrive", "EgnyteClient") | ForEach-Object {
    $procs = @(Get-Process -Name $_ -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "      Stopped: $_" -ForegroundColor Green
        Start-Sleep -Milliseconds 500
    }
}

# 2. Remove our HKCU\SOFTWARE\Classes overrides (unlock first if locked)
Write-Host "`n[2/6] Removing HKCU\SOFTWARE\Classes overrides..." -ForegroundColor Yellow
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

# 3. Clean HKCU FileExts (unlock, then clean)
Write-Host "`n[3/6] Cleaning HKCU FileExts..." -ForegroundColor Yellow
foreach ($ext in $extensions) {
    $basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    $regPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext"
    
    # Unlock if locked
    Remove-DenyAcl -RegPath $regPath | Out-Null
    
    if (Test-Path $basePath) {
        # Remove UserChoice
        $userChoice = "$basePath\UserChoice"
        if (Test-Path $userChoice) {
            Remove-DenyAcl -RegPath "$regPath\UserChoice" | Out-Null
            Remove-Item -Path $userChoice -Force -ErrorAction SilentlyContinue
            Write-Host "      Removed UserChoice for $ext" -ForegroundColor Green
        }
        
        # Clean OpenWithProgids - remove Google entries
        $progids = "$basePath\OpenWithProgids"
        if (Test-Path $progids) {
            $item = Get-Item $progids
            $item.GetValueNames() | Where-Object { $_ -like "*Google*" } | ForEach-Object {
                Remove-ItemProperty -Path $progids -Name $_ -ErrorAction SilentlyContinue
                Write-Host "      Removed OpenWithProgids: $_" -ForegroundColor Green
            }
        }
        
        # Clean OpenWithList - remove Google entries
        $list = "$basePath\OpenWithList"
        if (Test-Path $list) {
            $item = Get-Item $list
            $toRemove = @()
            $item.GetValueNames() | Where-Object { $_ -ne "MRUList" } | ForEach-Object {
                $val = (Get-ItemProperty $list).$_
                if ($val -like "*Google*") {
                    $toRemove += $_
                    Remove-ItemProperty -Path $list -Name $_ -ErrorAction SilentlyContinue
                    Write-Host "      Removed OpenWithList: $_ ($val)" -ForegroundColor Green
                }
            }
            # Update MRUList to remove references to deleted entries
            if ($toRemove.Count -gt 0) {
                $mru = (Get-ItemProperty $list -Name MRUList -ErrorAction SilentlyContinue).MRUList
                if ($mru) {
                    $newMru = ($mru.ToCharArray() | Where-Object { $_ -notin $toRemove }) -join ''
                    if ($newMru) {
                        Set-ItemProperty -Path $list -Name MRUList -Value $newMru
                    }
                }
            }
        }
    }
}

# 4. Clean HKCR extensions (requires admin)
Write-Host "`n[4/6] Cleaning HKCR extensions..." -ForegroundColor Yellow
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

# 5. Clean HKCR Google ProgIDs
Write-Host "`n[5/6] Cleaning HKCR Google ProgIDs..." -ForegroundColor Yellow
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

# 6. Verify
Write-Host "`n[6/6] Verification..." -ForegroundColor Yellow
$remaining = @()
foreach ($ext in $extensions) {
    if (Test-Path "HKCR:\$ext") { $remaining += "HKCR:$ext" }
    if (Test-Path "HKCU:\SOFTWARE\Classes\$ext") { $remaining += "HKCU Classes:$ext" }
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

Remove-PSDrive -Name HKCR -ErrorAction SilentlyContinue

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host @"

Next Steps:
  1. REBOOT the computer (required!)
  2. Install Egnyte Desktop App
  3. Log into Egnyte and open a .gdoc file once to register handler
  4. Run the Lock script BEFORE installing Google Drive

Log saved to: $LogPath
"@ -ForegroundColor White

Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
