<#
.SYNOPSIS
    Stage 1: Aggressively removes all Egnyte components and forces a reboot.
    Designed to be the first script in a two-part RMM/Intune deployment.
.DESCRIPTION
    1. Stops all Egnyte-related processes and services.
    2. Programmatically uninstalls specific Egnyte applications by exact name.
    3. Scrubs common file system locations (Program Files, AppData, ProgramData).
    4. FORCES A REBOOT to ensure a clean state for Stage 2.
#>

Write-Host "--- STAGE 1: EGNYTE NUKE SCRIPT INITIATED ---"

# --- 1. Force-Stop All Egnyte Processes & Services ---
Write-Host "Step 1: Terminating all Egnyte processes and services..."
Get-Service -Name "egnytefs" -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
Get-Process -Name "Egnyte*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 60 # Give processes time to die

# --- 2. Precise Uninstallation ---
Write-Host "Step 2: Uninstalling Egnyte applications by exact display name..."
$appsToUninstall = @(
    "Egnyte Desktop App", 
    "Egnyte Connect",
    "Egnyte" # Add any other specific names find
)

foreach ($appName in $appsToUninstall) {
    $package = Get-Package -Name $appName -ErrorAction SilentlyContinue
    if ($package) {
        Write-Host "Found and uninstalling: $($package.Name)"
        $package | Uninstall-Package -Force -ErrorAction SilentlyContinue
    }
    else {
        Write-Host "'$appName' not found."
    }
}
Write-Host "Waiting for uninstallers to finish..."
Start-Sleep -Seconds 120

# --- 3. File System Scrub ---
Write-Host "Step 3: Scrubbing leftover Egnyte folders..."
$foldersToNuke = @(
    "$env:ProgramFiles\Egnyte",
    "$env:ProgramFiles(x86)\Egnyte",
    "$env:ProgramData\Egnyte",
    "$env:LOCALAPPDATA\Egnyte Drive",
    "$env:LOCALAPPDATA\Egnyte Connect"
)

# This loop will also catch all user profiles for AppData paths
$userProfiles = Get-ChildItem "C:\Users" -Directory
foreach ($profile in $userProfiles) {
    $foldersToNuke += Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Egnyte Drive"
    $foldersToNuke += Join-Path -Path $profile.FullName -ChildPath "AppData\Local\Egnyte Connect"
}

foreach ($folder in ($foldersToNuke | Select-Object -Unique)) {
    if (Test-Path $folder) {
        Write-Host "Forcibly removing folder: $folder"
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Step 4: Nuke complete. Please reboot your computer to prepare for Stage 2."

exit 0