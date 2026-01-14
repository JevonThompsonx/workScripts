# Cleanup Google Drive & Egnyte Associations v2
# Run as Administrator
# Purpose: Clear corrupted file associations before Egnyte reinstall

#Requires -RunAsAdministrator

Write-Host "`n=== Google/Egnyte File Association Cleanup ===" -ForegroundColor Cyan
Write-Host "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor DarkGray

# 1. Kill Google Drive processes to unlock files/registry
Write-Host "`n[1/4] Stopping Google Drive processes..." -ForegroundColor Yellow
$gdProcess = Get-Process -Name "GoogleDriveFS" -ErrorAction SilentlyContinue
if ($gdProcess) {
    $gdProcess | Stop-Process -Force
    Write-Host "      Stopped GoogleDriveFS (PID: $($gdProcess.Id -join ', '))" -ForegroundColor Green
    Start-Sleep -Seconds 2
} else {
    Write-Host "      GoogleDriveFS not running" -ForegroundColor DarkGray
}

# 2. Define Registry Paths
$extensions = @(".gdoc", ".gsheet", ".gslides")
$hkcuBase = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"

# 3. Clean Current User (HKCU) - This removes any "UserChoice" overrides
Write-Host "`n[2/4] Cleaning User Registry (HKCU)..." -ForegroundColor Yellow
foreach ($ext in $extensions) {
    $path = "$hkcuBase\$ext"
    if (Test-Path $path) {
        try {
            # UserChoice has special protection - try to take ownership first
            $key = Get-Item $path
            $acl = $key.GetAccessControl()
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $acl.SetOwner([System.Security.Principal.NTAccount]$currentUser)
            $key.SetAccessControl($acl)
            
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "      Removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "      Warning: Could not fully remove $path - $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      Not found (OK): $path" -ForegroundColor DarkGray
    }
}

# 4. Clean System Root (HKCR) - Ensures a clean slate for Egnyte Reinstall
Write-Host "`n[3/4] Cleaning System Registry (HKCR)..." -ForegroundColor Yellow
if (!(Test-Path "HKCR:")) { 
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null 
}

foreach ($ext in $extensions) {
    $path = "HKCR:\$ext"
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "      Removed: $path" -ForegroundColor Green
        } catch {
            Write-Host "      Warning: Could not remove $path - $($_.Exception.Message)" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "      Not found (OK): $path" -ForegroundColor DarkGray
    }
}

# 5. Verify cleanup
Write-Host "`n[4/4] Verifying cleanup..." -ForegroundColor Yellow
$issues = @()
foreach ($ext in $extensions) {
    if (Test-Path "$hkcuBase\$ext") { $issues += "HKCU:$ext still exists" }
    if (Test-Path "HKCR:\$ext") { $issues += "HKCR:$ext still exists" }
}

if ($issues.Count -eq 0) {
    Write-Host "      All associations cleared successfully" -ForegroundColor Green
} else {
    Write-Host "      Some items remain (may require reboot):" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "        - $_" -ForegroundColor DarkYellow }
}

Write-Host "`n=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host @"

Next Steps:
  1. REBOOT the computer
  2. Install Egnyte Desktop App
  3. Run the Lock script

"@ -ForegroundColor White
