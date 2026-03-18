# workScripts

PowerShell and batch scripts for Windows provisioning and common IT operations.

This repo includes Windows setup/debloat scripts, drive mapping helpers, software install/update tooling, printer deployment templates, and a few small utilities. Most scripts are meant for elevated PowerShell, and some are designed to run through an RMM.

## Quick start (online)

Run the master orchestrator (recommended):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')"
```

Non-interactive (RMM-friendly):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2.ps1')" -NonInteractive -SkipDebloat -SkipRmmInstall
```

Non-interactive with Raphire debloat:

```powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```

## RMM one-liner (no `C:\Archive` installs)

Use the dedicated RMM runner with a forced Administrator password and no `C:\Archive` installs (skipped by design):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPassword "<YOUR_PASSWORD>"
```

If your RMM UI blocks special characters, use Base64:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Runners/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPasswordBase64 "<BASE64_UTF8_PASSWORD>"
```

## Common one-liners

Windows setup (current settings script):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')" -NoPause
```

Enable built-in local Administrator account:

```powershell
powershell -ExecutionPolicy Bypass -Command "$tempBat = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/enable_admin.bat' -OutFile $tempBat; & $tempBat"
```

Allow Google Credential Provider for Windows (GCWP) settings:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Accounts/AllowGoogleCred.ps1')"
```

Clone drive mapping BATs to `C:\Archive\Map egnyte drives`:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Networking/cloneDrives.ps1')"
```

Install everything in `C:\Archive` (MSI silent + logging, EXE interactive):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Install/installAllArchiveSoftwarev2.6.ps1')" -NonInteractive
```

## Printer scripts

The `Utilities/Printer-Scripts/` folder contains a public-safe printer deployment template set for Windows.

It includes:

- install-all printer deployment
- install-selected printer deployment
- delete-and-reinstall selected printers
- a generalized printer swap script
- shared helper functions
- a config-driven printer definition file
- a dedicated README explaining how to adapt the scripts

Notes:

- The public printer package is sanitized for GitHub
- Real internal printer names, site identifiers, private IPs, and company-specific paths were removed
- Sample values live in `Utilities/Printer-Scripts/PrinterConfig.psd1`
- Vendor driver binaries are not included in the public template
- See `Utilities/Printer-Scripts/README.md` for setup and customization details

## Folder guide

- `Runners/` master orchestration scripts that invoke other scripts remotely. See runner script headers for parameters.
- `Install/` bulk installers for `C:\Archive`, NinjaOne agent helper, and Egnyte update/nuke flows. See `Install/README.md` and `Install/updatingSoftware/README.md`.
- `Maintenance/` SFC/DISM repair, Windows Update remediation, debloat, and app uninstaller scripts. See `Maintenance/` for individual readme files.
- `Configuration/` Windows 11 settings scripts (dark mode, power plan, UAC, winget). See `Configuration/README.md`.
- `Accounts/` local Administrator account management and Google Credential Provider (GCWP) settings. See `Accounts/` scripts.
- `Networking/` drive mapping BAT presets and the cloneDrives downloader. See `Networking/README.md`.
- `Utilities/` file association cleanup/lock scripts, printer deployment templates, and Proxmox helpers. See `Utilities/README.md` and `Utilities/Printer-Scripts/README.md`.
- `Archive/` deprecated or superseded scripts kept for reference. Do not use in production.

## Notes

- Most scripts require elevated PowerShell
- Test deployment scripts in a lab or non-production environment first
- Review script contents before using them in your environment
- Some scripts assume Windows-specific paths, admin rights, or RMM execution context
