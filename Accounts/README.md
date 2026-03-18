← [Back to root](../README.md)

# Accounts

Local Administrator account management and Google Credential Provider for Windows (GCPW/GCWP) installation scripts.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [AllowGoogleCred.ps1](AllowGoogleCred.ps1) | Installs/configures GCPW, uninstalls old versions, and fixes black-box login screen (v3.0) | Required | `-DomainsAllowedToLogin`, `-DestinationFolder`, `-GcpwUrl` |
| [AllowGCWPv1.3.ps1](AllowGCWPv1.3.ps1) | GCPW installer with domain configuration (v1.3) | Required | `-DomainsAllowedToLogin`, `-GcpwUrl` |
| [enable_admin.bat](enable_admin.bat) | Enables the built-in local Administrator account and prompts for a password | Required | (prompts interactively) |
| [rmm.ps1](rmm.ps1) | Installs an RMM agent MSI from `C:\Archive\rmm`; expects `*-AV_*.msi` naming | Required | `-NonInteractive`, `-TargetDirectory`, `-MsiPattern`, `-Selection`, `-NoPause` |

## Usage

### AllowGoogleCred.ps1 (recommended GCPW script)

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/AllowGoogleCred.ps1')"
```

### AllowGCWPv1.3.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/AllowGCWPv1.3.ps1')"
```

### enable_admin.bat

```powershell
powershell -ExecutionPolicy Bypass -Command "$t = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/enable_admin.bat' -OutFile $t; & $t"
```

### rmm.ps1

`rmm.ps1` is a local runner; place the RMM agent MSI in `C:\Archive\rmm` before running:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/rmm.ps1')"
```
