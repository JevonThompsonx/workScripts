# Run as Administrator

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "Locking associations for user: $currentUser" -ForegroundColor Cyan

$keysToLock = @(
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc\UserChoice",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gsheet\UserChoice",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gslides\UserChoice"
)

foreach ($keyPath in $keysToLock) {
    if (Test-Path $keyPath) {
        $acl = Get-Acl $keyPath
        
        # We must DISABLE inheritance so the Deny rule sticks effectively
        $acl.SetAccessRuleProtection($true, $true)

        # Deny the CURRENT USER (and Google Drive) from changing this value
        # We Deny: SetValue, CreateSubKey, Delete, ChangePermissions, TakeOwnership
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            $currentUser,
            "SetValue,CreateSubKey,Delete,ChangePermissions,TakeOwnership",
            "ContainerInherit,ObjectInherit",
            "None",
            "Deny"
        )
        
        $acl.AddAccessRule($rule)
        Set-Acl -Path $keyPath -AclObject $acl
        
        Write-Host "LOCKED: $keyPath" -ForegroundColor Green
    } else {
        Write-Host "SKIPPED: $keyPath (Key does not exist yet. Open a file with Egnyte first!)" -ForegroundColor Red
    }
}

Write-Host "`nAssociations Locked." -ForegroundColor Yellow
Write-Host "You can now restart Google Drive."
