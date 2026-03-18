← [Back to root](../README.md)

# Install

Bulk installers that run every MSI and EXE found in `C:\Archive`, plus a NinjaOne agent helper.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [installAllArchiveSoftwarev2.6.ps1](installAllArchiveSoftwarev2.6.ps1) | Installs all `.msi`/`.exe` files from `C:\Archive`; MSIs run silently with per-file logs, EXEs run interactively (v2.6) | Required | `-NonInteractive`, `-RunDebloat`, `-SkipDebloatPrompt`, `-NoPause` |
| [ninjaOneInstall.ps1](ninjaOneInstall.ps1) | Downloads and installs the NinjaOne RMM agent (set `$installerUrl` in the script before running) | Required | `-NonInteractive`, `-AllowReinstall`, `-DownloadTimeoutSec`, `-InstallTimeoutSec` |
| [installAllArchiveSoftwarev2SilentInstall.bat](installAllArchiveSoftwarev2SilentInstall.bat) | Runs EXEs with UI and MSIs silently via `msiexec /qn`; logs to `%TEMP%` | Required | (none) |
| [install_AllArchive_Softwarev2_InteractiveInstall.bat](install_AllArchive_Softwarev2_InteractiveInstall.bat) | Runs both EXEs and MSIs with full UI | Required | (none) |

## Usage

### installAllArchiveSoftwarev2.6.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')"
```

Non-interactive / RMM:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')" -NonInteractive
```

## Prerequisites

- `C:\Archive` must exist and contain the `.msi` and/or `.exe` installers to run.
- Run in an elevated PowerShell session.

## Logging

Logs are written to `C:\Archive\InstallLogs` (one log file per MSI).

## Subfolders

- [`updatingSoftware/`](updatingSoftware/README.md) — Egnyte update scripts and nuke/reinstall flows
