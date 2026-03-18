← [Back to root](../README.md)

# Utilities

Google file association fix/lock scripts, printer deployment templates, and Proxmox helpers.

## Scripts

| File | Description | Elevation | Key Parameters |
|------|-------------|-----------|----------------|
| [cleanupGoogleFileAssociations.ps1](cleanupGoogleFileAssociations.ps1) | Resets Google file associations (`.gdoc`, `.gsheet`, `.gslides`) so Egnyte can claim them (v6) | Required | `-NoPause` |
| [lockGoogleFileAssociations.ps1](lockGoogleFileAssociations.ps1) | Locks Google file associations to Egnyte via deny ACL; supports `-Unlock` to reverse (v5) | Required | `-Unlock`, `-NoPause` |

## Usage

### cleanupGoogleFileAssociations.ps1

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/cleanupGoogleFileAssociations.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/cleanupGoogleFileAssociations.ps1')" -NoPause
```

### lockGoogleFileAssociations.ps1

Lock:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')"
```

Non-interactive:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')" -NoPause
```

Reverse the ACL lock:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Utilities/lockGoogleFileAssociations.ps1')" -Unlock
```

## Google + Egnyte coexistence workflow

Force Windows to use the Egnyte Desktop App for Google file formats while keeping Google Drive for Desktop installed:

1. Uninstall Google Drive and Egnyte.
2. Run `cleanupGoogleFileAssociations.ps1`.
3. Reboot.
4. Install Egnyte (Egnyte becomes the system default handler).
5. Run `lockGoogleFileAssociations.ps1`.
6. Reinstall Google Drive.

## Subfolders

- [`Printer-Scripts/`](Printer-Scripts/README.md) — sanitized Windows printer deployment template (config-driven, RMM-adaptable)
- [`proxmox/`](proxmox/README.md) — Proxmox/Linux VM helpers
