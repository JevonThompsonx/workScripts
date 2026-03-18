# workScripts

PowerShell and batch scripts for Windows provisioning and IT operations.

## Quick Start

Interactive (elevated PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')"
```

RMM / non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPassword "<YOUR_PASSWORD>"
```

## One-Liner Reference

| Script | What it does | One-liner |
|--------|-------------|-----------|
| **Runners** | | |
| [Run-All-Work-Scriptsv1.2.ps1](Runners/Run-All-Work-Scriptsv1.2.ps1) | Interactive master setup orchestrator (v1.3) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')"` |
| [Run-All-Work-Scriptsv1.2.ps1](Runners/Run-All-Work-Scriptsv1.2.ps1) `-NonInteractive` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')" -NonInteractive -SkipDebloat -SkipRmmInstall` |
| [Run-All-Work-Scriptsv1.2-RMM.ps1](Runners/Run-All-Work-Scriptsv1.2-RMM.ps1) | RMM non-interactive orchestrator | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPassword "<PASSWORD>"` |
| [Run-All-Work-Scriptsv1.2-RMM.ps1](Runners/Run-All-Work-Scriptsv1.2-RMM.ps1) `-AdministratorPasswordBase64` | Base64 password variant (RMM-safe for special characters) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPasswordBase64 "<BASE64>"` |
| **Install** | | |
| [installAllArchiveSoftwarev2.6.ps1](Install/installAllArchiveSoftwarev2.6.ps1) | Installs all MSI/EXE files from `C:\Archive`; MSIs silent with per-file logs, EXEs interactive (v2.6) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')"` |
| [installAllArchiveSoftwarev2.6.ps1](Install/installAllArchiveSoftwarev2.6.ps1) `-NonInteractive` | Non-interactive / RMM variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')" -NonInteractive` |
| [Egnyte-Nuke.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Nuke.ps1) | Completely removes Egnyte and forces a reboot | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Nuke.ps1')"` |
| [Egnyte-NukeNoRestart.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-NukeNoRestart.ps1) | Completely removes Egnyte without a forced reboot | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-NukeNoRestart.ps1')"` |
| [Egnyte-Update.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Update.ps1) | Downloads and installs the latest Egnyte Connect | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Update.ps1')"` |
| [NinjaOne-Egnyte-Nuke.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/NinjaOne-Egnyte-Nuke.ps1) | Enterprise Egnyte removal for NinjaOne RMM | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/NinjaOne-Egnyte-Nuke.ps1')"` |
| [NinjaOne-Egnyte-Install.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/NinjaOne-Egnyte-Install.ps1) | Enterprise Egnyte installer/updater for NinjaOne RMM | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/NinjaOne-Egnyte-Install.ps1')"` |
| [DryRun-Egnyte-Nuke.ps1](Install/updatingSoftware/egnyteNukeAndUpdate/DryRun-Egnyte-Nuke.ps1) | Validates what the Egnyte nuke would remove (no destructive actions) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/updatingSoftware/egnyteNukeAndUpdate/DryRun-Egnyte-Nuke.ps1')"` |
| **Maintenance** | | |
| [sfcDism.ps1](Maintenance/sfcDism.ps1) | Daily Windows maintenance: cadence-based DISM/SFC checks and repairs (v5.0.0) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/sfcDism.ps1')"` |
| [Invoke-WindowsUpdateRemediation.ps1](Maintenance/Invoke-WindowsUpdateRemediation.ps1) | Unblocks stuck Windows 11 updates; supports Diagnose and Remediate modes | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/Invoke-WindowsUpdateRemediation.ps1')"` |
| [win11Debloat.ps1](Maintenance/win11Debloat.ps1) | Bulk removes Windows 11 bloatware apps | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/win11Debloat.ps1')"` |
| [win11Debloat.ps1](Maintenance/win11Debloat.ps1) `-NonInteractive` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/win11Debloat.ps1')" -NonInteractive -ConfirmRemoval` |
| [engineeringDebloat.ps1](Maintenance/engineeringDebloat.ps1) | Deep removal of engineering apps (Autodesk, Vectorworks, Bluebeam, SolidWorks, Bentley) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/engineeringDebloat.ps1')"` |
| [engineeringDebloat.ps1](Maintenance/engineeringDebloat.ps1) `-NonInteractive` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/engineeringDebloat.ps1')" -NonInteractive -ConfirmRemoval` |
| [winApp_uninstaller.ps1](Maintenance/winApp_uninstaller.ps1) | Menu-driven Windows app uninstaller | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/winApp_uninstaller.ps1')"` |
| **Configuration** | | |
| [setup_script_windows_settings1_3.ps1](Configuration/setup_script_windows_settings1_3.ps1) | Windows 11 settings baseline: power plan, UAC disable, dark mode, taskbar tweaks (v1.3) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')"` |
| [setup_script_windows_settings1_3.ps1](Configuration/setup_script_windows_settings1_3.ps1) `-NoPause` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')" -NoPause` |
| [wingetInstall.ps1](Configuration/wingetInstall.ps1) | Installs Winget from the latest GitHub release; logs to `C:\Archive\InstallLogs` | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/wingetInstall.ps1')"` |
| **Accounts** | | |
| [enable_admin.bat](Accounts/enable_admin.bat) | Enables the built-in local Administrator account | `powershell -ExecutionPolicy Bypass -Command "$t = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/enable_admin.bat' -OutFile $t; & $t"` |
| [AllowGoogleCred.ps1](Accounts/AllowGoogleCred.ps1) | Installs/configures Google Credential Provider for Windows; uninstalls old versions and fixes black-box login (v3.0) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/AllowGoogleCred.ps1')"` |
| [AllowGCWPv1.3.ps1](Accounts/AllowGCWPv1.3.ps1) | GCPW installer with domain configuration (v1.3) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/AllowGCWPv1.3.ps1')"` |
| **Networking** | | |
| [cloneDrives.ps1](Networking/cloneDrives.ps1) | Downloads Egnyte drive-mapping BAT presets to `C:\Archive\Map egnyte drives` | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Networking/cloneDrives.ps1')"` |
| **Utilities** | | |
| [cleanupGoogleFileAssociations.ps1](Utilities/cleanupGoogleFileAssociations.ps1) | Resets Google file associations (`.gdoc`, `.gsheet`, `.gslides`) so Egnyte can claim them (v6) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/cleanupGoogleFileAssociations.ps1')"` |
| [cleanupGoogleFileAssociations.ps1](Utilities/cleanupGoogleFileAssociations.ps1) `-NoPause` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/cleanupGoogleFileAssociations.ps1')" -NoPause` |
| [lockGoogleFileAssociations.ps1](Utilities/lockGoogleFileAssociations.ps1) | Locks Google file associations to Egnyte via deny ACL (v5) | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')"` |
| [lockGoogleFileAssociations.ps1](Utilities/lockGoogleFileAssociations.ps1) `-NoPause` | Non-interactive variant | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')" -NoPause` |
| [lockGoogleFileAssociations.ps1](Utilities/lockGoogleFileAssociations.ps1) `-Unlock` | Reverses the ACL lock | `powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')" -Unlock` |

## Folder Guide

- [`Runners/`](Runners/README.md) — master orchestration scripts that run all setup steps in sequence
- [`Install/`](Install/README.md) — bulk `C:\Archive` installers, NinjaOne agent helper, and Egnyte update/nuke flows
- [`Maintenance/`](Maintenance/README.md) — SFC/DISM repair, Windows Update remediation, debloat, and app uninstaller scripts
- [`Configuration/`](Configuration/README.md) — Windows 11 settings baseline, Winget installer, and additional setup scripts
- [`Accounts/`](Accounts/README.md) — local Administrator account management and Google Credential Provider for Windows
- [`Networking/`](Networking/README.md) — Egnyte drive-mapping BAT presets and the `cloneDrives` downloader
- [`Utilities/`](Utilities/README.md) — Google file association fix/lock, printer deployment templates, and Proxmox helpers
- [`Archive/`](Archive/README.md) — deprecated or superseded scripts; do not use in production

## Notes

- Most scripts require elevated PowerShell (`Run as Administrator`).
- Test deployment scripts in a lab or non-production environment first.
- Review script contents before running in your environment.
- Some scripts disable UAC; a reboot is required for that change to take effect.
- `Archive/` scripts are deprecated and should not be used. They are kept for historical reference only.
