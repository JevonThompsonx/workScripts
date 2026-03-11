# workScripts

PowerShell and batch scripts for Windows provisioning and common IT operations.

This repo includes Windows setup/debloat scripts, drive mapping helpers, software install/update tooling, printer deployment templates, and a few small utilities. Most scripts are meant for elevated PowerShell, and some are designed to run through an RMM.

## Quick start (online)

Run the master orchestrator (recommended):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2.ps1')"
```

Non-interactive (RMM-friendly):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2.ps1')" -NonInteractive -SkipDebloat -SkipRmmInstall
```

Non-interactive with Raphire debloat:

```powershell
& ([scriptblock]::Create((irm "https://debloat.raphi.re/"))) -RunDefaults
```

## RMM one-liner (no `C:\Archive` installs)

Use the dedicated RMM runner with a forced Administrator password and no `C:\Archive` installs (skipped by design):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPassword "<YOUR_PASSWORD>"
```

If your RMM UI blocks special characters, use Base64:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2-RMM.ps1')" -AdministratorPasswordBase64 "<BASE64_UTF8_PASSWORD>"
```

## Common one-liners

Windows setup (current settings script):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1')" -NoPause
```

Enable built-in local Administrator account:

```powershell
powershell -ExecutionPolicy Bypass -Command "$tempBat = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/enable_admin.bat' -OutFile $tempBat; & $tempBat"
```

Allow Google Credential Provider for Windows (GCWP) settings:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/AllowGoogleCred.ps1')"
```

Clone drive mapping BATs to `C:\Archive\Map egnyte drives`:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/drives/cloneDrives.ps1')"
```

Install everything in `C:\Archive` (MSI silent + logging, EXE interactive):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1')" -NonInteractive
```

## Printer scripts

The `Printer-Scripts/` folder contains a public-safe printer deployment template set for Windows.

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
- Sample values live in `Printer-Scripts/PrinterConfig.psd1`
- Vendor driver binaries are not included in the public template
- See `Printer-Scripts/README.md` for setup and customization details

## Folder guide

- `Printer-Scripts/` sanitized Windows printer deployment templates and documentation. See `Printer-Scripts/README.md`.
- `drives/` drive mapping scripts (BAT presets + downloader). See `drives/README.md`.
- `fixes/` file association cleanup/lock scripts. See `fixes/README.md`.
- `installingSoftware/` bulk installers for `C:\Archive` + agent installer helper. See `installingSoftware/README.md`.
- `updatingSoftware/` MSI update templates and software update/nuke flows. See `updatingSoftware/README.md`.
- `windows setup/` Windows setup/debloat scripts and helpers. See `windows setup/README.md`.
- `proxmox/` small Proxmox/Linux helper scripts. See `proxmox/README.md`.

## Notes

- Most scripts require elevated PowerShell
- Test deployment scripts in a lab or non-production environment first
- Review script contents before using them in your environment
- Some scripts assume Windows-specific paths, admin rights, or RMM execution context
