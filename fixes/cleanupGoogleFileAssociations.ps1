# Cleanup Google Drive & Egnyte Associations
# Run as Administrator

Write-Host "Starting Cleanup Process..." -ForegroundColor Cyan

# 1. Kill Google Drive processes to unlock files/registry
Write-Host "Stopping Google Drive processes..." -ForegroundColor Yellow
Get-Process -Name "GoogleDriveFS" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# 2. Define Registry Paths
$hkcuPaths = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gsheet",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gslides"
)

$hkcrPaths = @(
    "HKCR:\.gdoc",
    "HKCR:\.gsheet",
    "HKCR:\.gslides"
)

# 3. Clean Current User (HKCU) - This removes any "UserChoice" overrides
foreach ($path in $hkcuPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed User Association: $path" -ForegroundColor Green
    }
}

# 4. Clean System Root (HKCR) - Ensures a clean slate for Egnyte Reinstall
if (!(Test-Path "HKCR:")) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null }

foreach ($path in $hkcrPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Removed System Association: $path" -ForegroundColor Green
    }
}

Write-Host "`nCleanup Complete." -ForegroundColor Cyan
Write-Host "Please REBOOT before installing Egnyte." -ForegroundColor Yellow
