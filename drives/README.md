# drives

Egnyte drive mapping helpers.

## What is in this folder

- `cloneDrives.ps1` downloads all `.bat` mapping presets from `JevonThompsonx/eDrives` into `C:\Archive\Map egnyte drives`.
- `*.bat` mapping presets that call `EgnyteClient.exe` to add/remove drive letters.

## Prerequisites

- Egnyte Connect installed (these BATs assume `C:\Program Files (x86)\Egnyte Connect\EgnyteClient.exe`).
- User is signed in to Egnyte.
- The BAT presets are hardcoded for the `ashleyvance` domain; edit the `-d` value if your Egnyte domain differs.

## Quick start

Download the latest BAT presets to `C:\Archive\Map egnyte drives`:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/drives/cloneDrives.ps1')"
```

Then run the desired mapping BAT (either from `C:\Archive\Map egnyte drives` or from this folder).

## Included BAT presets

- `Civil Drives.bat`
- `Civil Drives - wJLT.bat`
- `Civil BAK.bat`
- `Structural Drives.bat`
- `Shared Services.bat`
- `Shared Servicesv2.bat`
- `Spare Computer Drives.bat`
- `Spare Computer Drives-No SSO.bat`
- `Remove All Drives.bat`

## Notes

- These scripts manage Egnyte drive mappings (via Egnyte Connect), not Windows SMB drive mappings.
- If SSO is not available/configured, use the `*-No SSO.bat` preset or edit `-sso` arguments.
