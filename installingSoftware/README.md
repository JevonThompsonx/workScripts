# installingSoftware

Bulk installers that run everything found in `C:\Archive`.

## Recommended script

- `installAllArchiveSoftwarev2.6.ps1` (recommended) installs `.msi` files silently with per-MSI logs and launches `.exe` installers interactively. It also offers an optional external debloat step.

Online one-liner:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1')"
```

Non-interactive (RMM):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1')" -NonInteractive
```

## Other scripts in this folder

- `installAllArchiveSoftwarev2.5.ps1` similar to v2.6 (no optional external debloat step).
- `installAllArchiveSoftwarev2SilentInstall.bat` runs EXEs with UI and MSIs via `msiexec /qn` (logs to `%TEMP%`).
- `install_AllArchive_Softwarev2_InteractiveInstall.bat` runs EXEs with UI and MSIs with UI.
- `installAllArchiveSoftwareNoWait2.bat` launches all installers without waiting (easy to overwhelm endpoints).
- `installAllArchiveSoftware.bat` legacy; MSI handling is not reliable (prefer the PowerShell versions).
- `ninjaOneInstall.ps1` helper to download + install NinjaOne agent (requires setting `$installerUrl` in the script).

## RMM parameters

- `installAllArchiveSoftwarev2.6.ps1`: `-NonInteractive` (implies `-NoPause` and skips debloat prompt unless `-RunDebloat`), `-RunDebloat`, `-SkipDebloatPrompt`, `-NoPause`.
- `installAllArchiveSoftwarev2.5.ps1`: `-NonInteractive` or `-NoPause`.
- `ninjaOneInstall.ps1`: `-NonInteractive` (skips prompts) and `-AllowReinstall`.

## Prerequisites

- `C:\Archive` exists and contains the installers you want to run (`.msi` and/or `.exe`).
- Run PowerShell scripts in an elevated PowerShell.

## Logging

- `installAllArchiveSoftwarev2.5.ps1` and `installAllArchiveSoftwarev2.6.ps1` create logs under `C:\Archive\InstallLogs`.
- Some BAT variants log to `%TEMP%`.
