<#
.SYNOPSIS
    Performs a full clean reinstallation of the Egnyte Desktop App using programmatic uninstall.
    1. Checks for conflicting running processes.
    2. Programmatically finds and runs the uninstaller for all "Egnyte" products.
    3. Verifies removal of old cache folders for all users.
    4. Downloads and installs the latest Egnyte Desktop App.
    5. Cleans up installers.
.DESCRIPTION
    Designed for deployment via RMM. Must be run with Administrator/SYSTEM privileges.
    This version has a function that mimics the Windows "Apps & Features" uninstall process.
.VERSION
    2.1 - 2025-06-04
#>


# --- Configuration ---
$newEgnyteVersion = "3.25.1"
$downloadUrl_Msi = "https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/3.25.1/EgnyteDesktopApp_3.25.1_161.msi"
$localDirectory = "C:\EgnyteTemp"
$msiFileName = "EgnyteSetup.msi"
$localMsiPath = Join-Path -Path $localDirectory -ChildPath $msiFileName

# --- 1. Pre-Flight Check for Running Applications ---
Write-Host "STEP 1: Performing pre-flight check for open applications..."
$criticalProcesses = @(
    "WINWORD", "EXCEL", "POWERPNT", "OUTLOOK", "acad", "Vectorworks", "Vectorworks2024", 
    "Vectorworks2025", "Vectorworks2020", "Vectorworks2021", "Vectorworks2022", 
    "Vectorworks2023", "PDFXchange", "PDFXEdit")
$runningProcesses = Get-Process -Name $criticalProcesses -ErrorAction SilentlyContinue
if ($null -ne $runningProcesses) {
    $runningAppNames = $runningProcesses.ProcessName -join ', '
    Write-Warning "ABORTING: The following critical application(s) are running: $runningAppNames. Please close them and re-run."
    exit 99
}
Write-Host "Pre-flight check passed."

# --- 2. Stop Egnyte Service ---
Write-Host "STEP 2: Stopping Egnyte services..."
if (Get-Service -Name "egnytefs" -ErrorAction SilentlyContinue) {
    Stop-Service -Name "egnytefs" -Force -ErrorAction SilentlyContinue
    Write-Host "Egnyte service stopped."
}
else {
    Write-Host "Egnyte service not found, continuing with uninstall."
}

# --- 3. Programmatic Uninstall ---
Write-Host "STEP 3: Finding and running uninstallers for all 'Egnyte' products..."
# This function searches the registry for uninstall strings, just like "Apps & Features"
function Invoke-SilentUninstall {
    param(
        [string]$AppName
    )
    # Search both 32-bit and 64-bit registry hives for uninstallers
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty $registryPaths -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq "Egnyte Desktop App" } | ForEach-Object {
        if ($_.UninstallString) {
            Write-Host "Found program: $($_.DisplayName). Attempting silent uninstall..."
            $uninstallString = $_.UninstallString
            
            # Modify the uninstall string for silent execution
            if ($uninstallString -match 'msiexec') {
                # For MSI installers, use /x for uninstall and /quiet for silent
                $uninstallCommand = $uninstallString -replace '/I', '/X' -replace '/i', '/x'
                $silentArgs = "$uninstallCommand /quiet /norestart"
            }
            else {
                # For other uninstallers, try common silent flags
                $silentArgs = "$uninstallString /S /silent /quiet /norestart"
            }
            
            # Execute the uninstall command
            $process, $args = $silentArgs.Split(' ', 2)
            try {
                Start-Process -FilePath $process -ArgumentList $args -Wait -NoNewWindow
                Write-Host "$($_.DisplayName) uninstaller finished."
            }
            catch {
                Write-Warning "Could not run uninstaller for $($_.DisplayName). Manual check may be required."
            }
        }
    }
}

Invoke-SilentUninstall -AppName "Egnyte"
Write-Host "Uninstall process complete. Waiting for processes to terminate..."
Start-Sleep -Seconds 60 # Allow time for uninstall processes to fully close

# --- 4. Verify and Clean Legacy Folders ---
Write-Host "STEP 4: Verifying removal of legacy cache folders for all user profiles..."
$userFolders = Get-ChildItem -Path "C:\Users" -Directory -Exclude "Public", "Default", "All Users"
foreach ($userFolder in $userFolders) {
    $legacyConnectPath = Join-Path -Path $userFolder.FullName -ChildPath "AppData\Local\Egnyte Connect"
    $newClientCachePath = Join-Path -Path $userFolder.FullName -ChildPath "AppData\Local\Egnyte Drive"
    
    if (Test-Path -Path $legacyConnectPath) {
        Write-Host "Found legacy 'Egnyte Connect' folder for user $($userFolder.Name). Forcibly removing..."
        Remove-Item -Path $legacyConnectPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $newClientCachePath) {
        Write-Host "Found 'Egnyte Drive' cache folder for user $($userFolder.Name). Forcibly removing..."
        Remove-Item -Path $newClientCachePath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "Verification and manual cleanup of user profiles complete."

# --- 5. Download and Install New Version ---
Write-Host "STEP 5: Downloading and installing Egnyte Desktop App v$newEgnyteVersion..."
if (-not (Test-Path -Path $localDirectory)) {
    New-Item -ItemType Directory -Path $localDirectory | Out-Null
}
try {
    Invoke-WebRequest -Uri $downloadUrl_Msi -OutFile $localMsiPath -ErrorAction Stop
    Write-Host "Download complete. Starting installation..."
    $msiArgs = @("/i", "`"$localMsiPath`"", "/quiet", "/norestart")
    Start-Process msiexec -ArgumentList $msiArgs -Wait -NoNewWindow
    Write-Host "Installation of new version complete."
}
catch {
    Write-Error "CRITICAL ERROR during download or installation: $_"
    exit 1
}

# --- 6. Final Cleanup ---
Write-Host "STEP 6: Cleaning up temporary installation files..."
Remove-Item -Path $localDirectory -Recurse -Force
Write-Host "Cleanup complete."

Write-Host "SUCCESS: Egnyte has been cleanly reinstalled."

exit 0