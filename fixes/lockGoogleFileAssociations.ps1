# Run as Administrator - AFTER Egnyte reinstall and confirming it works

$keysToLock = @(
    "HKCR:\.gdoc",
    "HKCR:\.gsheet",
    "HKCR:\.gslides"
)

if (!(Test-Path "HKCR:")) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
}

foreach ($keyPath in $keysToLock) {
    if (Test-Path $keyPath) {
        $key = Get-Item $keyPath
        $acl = Get-Acl $keyPath
        
        # Deny write access to Users group (Google Drive runs as user)
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "BUILTIN\Users",
            "SetValue,CreateSubKey,Delete",
            "ContainerInherit,ObjectInherit",
            "None",
            "Deny"
        )
        $acl.AddAccessRule($rule)
        Set-Acl -Path $keyPath -AclObject $acl
        
        Write-Host "Locked $keyPath"
    }
}

Write-Host "`nRegistry keys locked. Google Drive shouldn't be able to overwrite them now."
