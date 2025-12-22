#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes Google Drive file type registry associations (.gdoc, .gsheet, .gslides)

.DESCRIPTION
    This script removes registry entries for Google Drive file types from:
    - HKEY_CLASSES_ROOT (requires admin)
    - HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts

.NOTES
    Must be run as Administrator
#>

# Registry paths to remove
$classesRootKeys = @(
    "HKCR:\.gdoc",
    "HKCR:\.gsheet",
    "HKCR:\.gslides"
)

$fileExtsKeys = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gsheet",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gslides"
)

# Create HKCR PSDrive if it doesn't exist
if (-not (Test-Path "HKCR:")) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}

Write-Host "Removing Google Drive file type associations..." -ForegroundColor Cyan
Write-Host ""

# Remove HKEY_CLASSES_ROOT entries
Write-Host "Processing HKEY_CLASSES_ROOT entries:" -ForegroundColor Yellow
foreach ($key in $classesRootKeys) {
    if (Test-Path $key) {
        try {
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            Write-Host "  [REMOVED] $key" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] $key - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [NOT FOUND] $key" -ForegroundColor DarkGray
    }
}

Write-Host ""

# Remove HKEY_CURRENT_USER\...\FileExts entries
Write-Host "Processing FileExts entries:" -ForegroundColor Yellow
foreach ($key in $fileExtsKeys) {
    if (Test-Path $key) {
        try {
            Remove-Item -Path $key -Recurse -Force -ErrorAction Stop
            Write-Host "  [REMOVED] $key" -ForegroundColor Green
        } catch {
            Write-Host "  [ERROR] $key - $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [NOT FOUND] $key" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. You may need to restart Explorer or log out/in for changes to take effect." -ForegroundColor Cyan
