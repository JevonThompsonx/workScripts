# updatingSoftware

PowerShell scripts that download an MSI, run a silent install, and clean up afterward. Most scripts include a pre-flight check to abort if critical apps are open.

## Scripts in this folder

- `Update-Egnyte-v1.0.ps1` basic Egnyte MSI download + install (no pre-flight checks).
- `Update-Egnyte-v1.5.ps1` Egnyte MSI download + install with pre-flight checks (edit `$downloadUrl` when Egnyte versions change).
- `Update-MSI-Application-Base-v1.5.ps1` template for updating any MSI with pre-flight checks.
- `updatingScript.1.6Base.ps1` newer template that also handles an empty critical-process list.
- `DONTUSE-Uninstall-Update-Egnytev2.1.ps1` legacy/experimental (not recommended).

## Egnyte nuke/reinstall

See `updatingSoftware/egnyteNukeAndUpdate/README.md` for full Egnyte removal + reinstall flows (including NinjaOne-focused scripts).

## Usage

1. Open an elevated PowerShell.
2. If needed for the session: `Set-ExecutionPolicy RemoteSigned -Scope Process -Force` (or `Bypass`).
3. Edit the script configuration (`$downloadUrl`, `$fileName`, `$localDirectory`, `$criticalProcesses`).
4. Run the script.

## Notes

- These scripts are MSI-focused; `.exe` updaters require different logic/switches.
- Exit code `99` is commonly used when a pre-flight check finds a running app.
