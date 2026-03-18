← [Back to root](../README.md)

# Maintenance

Windows health and maintenance scripts: SFC/DISM repairs, Windows Update remediation, debloat, and app removal.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [sfcDism.ps1](sfcDism.ps1) | Daily Windows maintenance: cadence-based DISM/SFC checks and repairs (v5.0.0) | Required | See [sfcDism.readme.md](sfcDism.readme.md) for all NinjaOne options |
| [Invoke-WindowsUpdateRemediation.ps1](Invoke-WindowsUpdateRemediation.ps1) | Unblocks stuck Windows 11 feature updates, including the "61% stuck" case | Required | `-Mode` (`Remediate`\|`Diagnose`) |
| [Invoke-WindowsUpdateRemediation.cmd](Invoke-WindowsUpdateRemediation.cmd) | Batch wrapper to double-click-launch the remediation script | Required | (none) |
| [win11Debloat.ps1](win11Debloat.ps1) | Bulk removes Windows 11 bloatware (Teams, Xbox, and more) | Required | `-NonInteractive`, `-Mode`, `-ConfirmRemoval`, `-NoPause` |
| [engineeringDebloat.ps1](engineeringDebloat.ps1) | Deep removal of engineering apps (Autodesk, Vectorworks, Bluebeam, SolidWorks, Bentley) | Required | `-NonInteractive`, `-Mode`, `-ConfirmRemoval`, `-NoPause` |
| [winApp_uninstaller.ps1](winApp_uninstaller.ps1) | Menu-driven Appx app remover; most apps are commented out — edit before running | Required | `-NonInteractive`, `-Mode`, `-SearchTerm`, `-ConfirmRemoval` |

## Usage

### sfcDism.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/sfcDism.ps1')"
```

See [sfcDism.readme.md](sfcDism.readme.md) for full cadence control options and NinjaOne configuration.

### Invoke-WindowsUpdateRemediation.ps1

Diagnose mode (read-only analysis):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/Invoke-WindowsUpdateRemediation.ps1')" -Mode Diagnose
```

Remediate mode:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/Invoke-WindowsUpdateRemediation.ps1')" -Mode Remediate
```

See [WindowsUpdateRemediation.readme.md](WindowsUpdateRemediation.readme.md) for NinjaOne configuration and option details.

### win11Debloat.ps1

Interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/win11Debloat.ps1')"
```

Non-interactive (removes all listed apps without prompts):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/win11Debloat.ps1')" -NonInteractive -ConfirmRemoval
```

### engineeringDebloat.ps1

Interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/engineeringDebloat.ps1')"
```

Non-interactive (removes all engineering apps without prompts):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/engineeringDebloat.ps1')" -NonInteractive -ConfirmRemoval
```

### winApp_uninstaller.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Maintenance/winApp_uninstaller.ps1')"
```
