← [Back to root](../README.md)

# Networking

Egnyte drive-mapping BAT presets and the `cloneDrives` downloader.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [cloneDrives.ps1](cloneDrives.ps1) | Downloads all `.bat` mapping presets from `JevonThompsonx/eDrives` into `C:\Archive\Map egnyte drives` | Not required | (none) |
| [Civil Drives.bat](Civil%20Drives.bat) | Maps Civil Engineering Egnyte drives | Not required | (none) |
| [Civil Drives - wJLT.bat](Civil%20Drives%20-%20wJLT.bat) | Maps Civil Engineering Egnyte drives (JLT variant) | Not required | (none) |
| [Civil BAK.bat](Civil%20BAK.bat) | Maps Civil BAK Egnyte drives | Not required | (none) |
| [Structural Drives.bat](Structural%20Drives.bat) | Maps Structural Engineering Egnyte drives | Not required | (none) |
| [Shared Services.bat](Shared%20Services.bat) | Maps Shared Services Egnyte drives | Not required | (none) |
| [Shared Servicesv2.bat](Shared%20Servicesv2.bat) | Maps Shared Services Egnyte drives (v2) | Not required | (none) |
| [Spare Computer Drives.bat](Spare%20Computer%20Drives.bat) | Maps Spare Computer Egnyte drives (SSO) | Not required | (none) |
| [Spare Computer Drives-No SSO.bat](Spare%20Computer%20Drives-No%20SSO.bat) | Maps Spare Computer Egnyte drives (no SSO) | Not required | (none) |
| [Remove All Drives.bat](Remove%20All%20Drives.bat) | Removes all mapped Egnyte drives | Not required | (none) |

## Usage

### cloneDrives.ps1

Download the latest BAT presets to `C:\Archive\Map egnyte drives`:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Networking/cloneDrives.ps1')"
```

Then run the desired mapping BAT from `C:\Archive\Map egnyte drives` or directly from this folder.

## Prerequisites

- Egnyte Connect installed (`C:\Program Files (x86)\Egnyte Connect\EgnyteClient.exe`).
- User is signed in to Egnyte.
- The BAT presets are hardcoded for the `ashleyvance` domain; edit the `-d` value if your Egnyte domain differs.

## Notes

- These scripts manage Egnyte drive mappings (via Egnyte Connect), not Windows SMB drive mappings.
- If SSO is not configured, use `Spare Computer Drives-No SSO.bat` or edit `-sso` arguments in the desired preset.
