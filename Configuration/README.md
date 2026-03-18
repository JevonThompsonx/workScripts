← [Back to root](../README.md)

# Configuration

Windows 11 settings baseline scripts: power plan, UAC, dark mode, taskbar tweaks, and Winget installer.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [setup_script_windows_settings1_3.ps1](setup_script_windows_settings1_3.ps1) | Windows 11 settings baseline: power plan, hibernation off, UAC disable, dark mode, taskbar tweaks (v1.3) | Required | `-NoPause`, `-SkipTaskbar`, `-SkipBloatware` |
| [setup_scriptv1.5.ps1](setup_scriptv1.5.ps1) | Older comprehensive setup + debloat: power, UAC, dark mode, privacy tweaks, taskbar, `C:\Archive` creation | Required | `-NoPause` |
| [wingetInstall.ps1](wingetInstall.ps1) | Installs Winget (Windows Package Manager) from the latest GitHub release; logs to `C:\Archive\InstallLogs` | Required | `-NoPause`, `-NonInteractive` |

## Usage

### setup_script_windows_settings1_3.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')"
```

Non-interactive (`-NoPause` skips the end-of-script pause):

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/setup_script_windows_settings1_3.ps1')" -NoPause
```

### wingetInstall.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Configuration/wingetInstall.ps1')"
```

## Notes

- `setup_script_windows_settings1_3.ps1` disables UAC; a reboot is required for that change to take effect.
- Explorer restarts at the end of the settings script to apply UI changes (screen flashes briefly).
