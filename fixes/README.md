# fixes

Egnyte + Google Drive coexistence fix for Google file formats (`.gdoc`, `.gsheet`, `.gslides`).

## Scripts in this folder

- `cleanupGoogleFileAssociations.ps1` (cleanup/reset) removes conflicting registry keys and any prior ACL locks.
- `lockGoogleFileAssociations.ps1` (lock) applies a deny ACL so Google Drive cannot hijack associations again (supports `-Unlock`).

## One-liners (online)

Cleanup/reset:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/fixes/cleanupGoogleFileAssociations.ps1')"
```

Lock:

```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/fixes/lockGoogleFileAssociations.ps1')"
```

## Objective

Force Windows to use the Egnyte Desktop App for Google file formats while allowing Google Drive for Desktop to remain installed for other uses.

## The problem

Both Egnyte and Google Drive attempt to claim file associations for Google formats.

- Google Drive tries to overwrite user associations (HKCU) on startup.
- Egnyte sets system associations (HKCR) during installation.

When both are installed, `UserChoice` keys can become corrupted and files may stop opening or open in the wrong app.

## The solution methodology

Use a "clean, assert, and lock" strategy:

1. Run `cleanupGoogleFileAssociations.ps1` to wipe the association state.
2. Reboot.
3. Install Egnyte (Egnyte becomes the system default handler).
4. Run `lockGoogleFileAssociations.ps1` to deny writes to the per-user association keys.
5. Reinstall Google Drive (it can run, but cannot take over `.gdoc`/`.gsheet`/`.gslides`).

## Deployment workflow

1. Uninstall Google Drive and Egnyte.
2. Run the cleanup script.
3. Reboot.
4. Install Egnyte.
5. Run the lock script.
6. Reinstall Google Drive.
