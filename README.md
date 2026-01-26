# workScripts

PowerShell and batch scripts for Windows provisioning and common IT operations (setup/debloat, Egnyte mapping, software installs/updates, and a few utilities).

Most scripts require an elevated PowerShell.

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
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2.ps1')" -NonInteractive -RunRaphireDebloat
```

## RMM one-liner (no C:\Archive installs)

Use the dedicated RMM runner with a forced Administrator password and no C:\Archive installs (skipped by design):

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

Clone Egnyte drive mapping BATs to `C:\Archive\Map egnyte drives`:

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

## Folder guide

- `drives/` Egnyte mapping scripts (BAT presets + downloader). See `drives/README.md`.
- `fixes/` Egnyte + Google Drive file association cleanup/lock scripts. See `fixes/README.md`.
- `installingSoftware/` bulk installers for `C:\Archive` + NinjaOne agent installer helper. See `installingSoftware/README.md`.
- `updatingSoftware/` MSI update templates + Egnyte update/nuke flows. See `updatingSoftware/README.md`.
- `windows setup/` Windows setup/debloat scripts and helpers (folder name includes a space). See `windows setup/README.md`.
- `proxmox/` small Proxmox/Linux helper scripts. See `proxmox/README.md`.
