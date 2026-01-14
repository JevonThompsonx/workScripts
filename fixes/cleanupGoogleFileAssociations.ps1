# Run as Administrator
Write-Host "Killing Google Drive processes..." -ForegroundColor Cyan
Get-Process -Name "GoogleDriveFS" -ErrorAction SilentlyContinue | Stop-Process -Force

# Define keys to clean
$userExts = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gsheet",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gslides"
)

$classesRoot = @(
    "HKCR:\.gdoc",
    "HKCR:\.gsheet",
    "HKCR:\.gslides"
)

# Clean User Keys (The most important part)
foreach ($key in $userExts) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "Removed User Association: $key" -ForegroundColor Green
    }
}

# Clean System Keys
if (!(Test-Path "HKCR:")) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null }
foreach ($key in $classesRoot) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "Removed System Association: $key" -ForegroundColor Green
    }
}

Write-Host "`nCleanup Complete." -ForegroundColor Yellow
Write-Host "1. Reinstall Egnyte (or use 'Open With' -> Egnyte -> Always)."
Write-Host "2. Verify the file opens correctly."
Write-Host "3. Run the LOCK script immediately."
