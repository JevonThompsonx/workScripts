# Run as Administrator

# Step 1: Clean up existing entries
$classesRoot = @(
    "HKCR:\.gdoc",
    "HKCR:\.gsheet", 
    "HKCR:\.gslides"
)

$userExts = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gsheet",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gslides"
)

# Mount HKCR if not available
if (!(Test-Path "HKCR:")) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}

foreach ($key in $classesRoot) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "Removed $key"
    }
}

foreach ($key in $userExts) {
    if (Test-Path $key) {
        Remove-Item -Path $key -Recurse -Force
        Write-Host "Removed $key"
    }
}

# Step 2: Reinstall Egnyte Desktop App now, then run part 2 of this script
Write-Host "`nNow reinstall Egnyte Desktop App, then run the lock script."
