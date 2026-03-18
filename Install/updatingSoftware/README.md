← [Back to Install](../README.md)

# updatingSoftware

PowerShell scripts that download an MSI, run a silent install, and clean up. Most include a pre-flight check to abort if critical apps are open.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [Update-Egnyte-v1.5.ps1](Update-Egnyte-v1.5.ps1) | Downloads and installs the latest Egnyte MSI; aborts if critical apps are running (v1.5) | Required | `-DownloadUrl`, `-LocalDirectory`, `-FileName`, `-CriticalProcesses`, `-NoPause` |
| [Update-MSI-Application-Base-v1.5.ps1](Update-MSI-Application-Base-v1.5.ps1) | Reusable template for updating any MSI with pre-flight process checks (v1.5) | Required | `-DownloadUrl`, `-LocalDirectory`, `-FileName`, `-CriticalProcesses`, `-NoPause` |
| [updatingScript.1.6Base.ps1](updatingScript.1.6Base.ps1) | Improved v1.6 template with better empty critical-process list handling | Required | `-DownloadUrl`, `-LocalDirectory`, `-FileName`, `-CriticalProcesses`, `-NoPause` |

## Usage

Edit the configuration variables (`$downloadUrl`, `$fileName`, `$localDirectory`, `$criticalProcesses`) in the script, then run in an elevated PowerShell:

```powershell
.\Update-Egnyte-v1.5.ps1
```

Exit code `99` means a pre-flight check found a critical app running.

## Subfolders

- [`egnyteNukeAndUpdate/`](egnyteNukeAndUpdate/README.md) — complete Egnyte removal and reinstall flows, including NinjaOne-specific scripts
