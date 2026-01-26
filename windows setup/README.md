# windows setup

Scripts for initial Windows configuration (power/UAC/theme), debloat, and a few deployment helpers.

Most scripts require an elevated PowerShell.

## Recommended order (fresh machine)

1. `enable_admin.bat` (enable the built-in local Administrator account)
2. `setup_script_windows_settings1_3.ps1` (system settings + UI tweaks)
3. `AllowGoogleCred.ps1` (install/configure Google Credential Provider for Windows)

## One-liners (online)

Enable local Administrator:

```powershell
powershell -ExecutionPolicy Bypass -Command "$tempBat = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/enable_admin.bat' -OutFile $tempBat; & $tempBat"
```

Windows settings (current):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1')" -NoPause
```

GCWP (recommended):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/AllowGoogleCred.ps1')"
```

## Scripts in this folder

- `setup_script_windows_settings1_3.ps1` current system settings script (power plan, hibernation, UAC disable + reboot required, Dark Mode, basic taskbar tweaks; may remove OneDrive/Teams and restart Explorer).
- `setup_script_windows_settings1_2.ps1`, `setup_script_windows_settings1.ps1` older variants.
- `setup_scriptv1.5.ps1` older, more comprehensive setup/debloat script.
- `win11Debloat.ps1` bulk Appx bloatware removal (many apps enabled; review before running).
- `winApp_uninstaller.ps1` menu-driven Appx remover (expects you to edit/uncomment package names).
- `wingetInstall.ps1` installs Winget from the latest GitHub release and logs to `C:\Archive\InstallLogs`.
- `AllowGoogleCred.ps1` installs and configures Google Credential Provider for Windows (includes uninstall of old versions + registry fix).
- `AllowGoogleCredentials.ps1` legacy GCWP installer/config script.
- `AllowGCWPv1.3.ps1`, `AllowGCWPv1.2.ps1` older GCWP variants.
- `rmm.ps1` installs an RMM agent MSI from `C:\Archive\rmm` (expects `*-AV_*.msi` naming).
- `engineeringDebloat.ps1` deep removal of engineering apps (destructive; use with care).

## RMM parameters

- `setup_script_windows_settings1_3.ps1`: `-NoPause` (non-interactive).
- `setup_scriptv1.5.ps1`: `-NoPause`.
- `win11Debloat.ps1`: `-NonInteractive`, `-Mode` (`All|Win11|Xbox|List|Search|Exit`), `-ConfirmRemoval`, `-SearchTerm`, `-NoPause`.
- `winApp_uninstaller.ps1`: `-NonInteractive`, `-Mode` (`Remove|List|Search|Exit`), `-ConfirmRemoval`, `-SearchTerm`.
- `engineeringDebloat.ps1`: `-NonInteractive`, `-Mode` (`All|Autodesk|Vectorworks|Bluebeam|SolidWorks|Bentley|List|Cleanup|Exit`), `-ConfirmRemoval`, `-NoPause`.
- `wingetInstall.ps1`: `-NonInteractive` or `-NoPause`.
- `rmm.ps1`: `-NonInteractive`, `-TargetDirectory`, `-MsiPattern`, `-Selection`, `-NoPause`.
- `AllowGoogleCred.ps1`: `-DomainsAllowedToLogin`, `-DestinationFolder`, `-GcpwUrl`.
- `AllowGoogleCredentials.ps1`: `-DomainsAllowedToLogin`, `-DestinationFolder`, `-GcpwUrl`, `-DownloadWaitSec`.
- `AllowGCWPv1.3.ps1`: `-DomainsAllowedToLogin`, `-GcpwUrl`.
- `AllowGCWPv1.2.ps1`: `-DomainsAllowedToLogin`, `-DestinationFolder`, `-GcpwUrl`.

## Notes

- Several scripts disable UAC; plan for a reboot.
- Some scripts restart `explorer.exe` to apply UI changes.
- Folder name includes a space (`windows setup`); quote paths when running locally.
