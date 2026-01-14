# Lock Google File Associations to System Default (Egnyte)
# Run as Administrator

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "Locking associations for user: $currentUser" -ForegroundColor Cyan

# 1. Verify Egnyte is actually registered in the System (HKCR)
# If Egnyte isn't installed, locking HKCU will leave the user with NO app to open files.
if (!(Test-Path "HKCR:")) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null }
if (!(Test-Path "HKCR:\Egnyte.gdoc")) {
    Write-Host "WARNING: Egnyte does not appear to be installed (ProgID 'Egnyte.gdoc' missing)." -ForegroundColor Red
    Write-Host "Please install Egnyte BEFORE running this script."
    exit
}

# 2. Define the Parent Keys in HKCU
# We lock the PARENT (.gdoc) to prevent Google Drive from creating a 'UserChoice' subkey.
$extensions = @(".gdoc", ".gsheet", ".gslides")
$basePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"

foreach ($ext in $extensions) {
    $fullPath = "$basePath\$ext"

    # Ensure the parent key exists (it might have been deleted by cleanup)
    if (!(Test-Path $fullPath)) {
        New-Item -Path $basePath -Name $ext -Force | Out-Null
        Write-Host "Created container: $fullPath" -ForegroundColor DarkGray
    }

    # If a UserChoice key already exists (e.g. user clicked something), DELETE it first.
    # We want to force the system fallback.
    if (Test-Path "$fullPath\UserChoice") {
        Remove-Item -Path "$fullPath\UserChoice" -Force -ErrorAction SilentlyContinue
        Write-Host "Removed existing UserChoice for $ext" -ForegroundColor Yellow
    }

    # 3. Apply the Lock (Deny Write Permissions)
    $acl = Get-Acl $fullPath
    
    # Disable inheritance to ensure our Deny rule sticks
    $acl.SetAccessRuleProtection($true, $true)

    # Deny the CURRENT USER from creating subkeys (preventing UserChoice creation)
    # We Deny: CreateSubKey, SetValue, Delete, ChangePermissions, TakeOwnership
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
        $currentUser,
        "CreateSubKey,SetValue,Delete,ChangePermissions,TakeOwnership",
        "ContainerInherit", 
        "None",
        "Deny"
    )
    
    $acl.AddAccessRule($rule)
    Set-Acl -Path $fullPath -AclObject $acl
    
    Write-Host "LOCKED: $fullPath" -ForegroundColor Green
}

Write-Host "`nAssociations Secured." -ForegroundColor Cyan
Write-Host "Google Drive will now be unable to hijack these file types." -ForegroundColor Yellow
