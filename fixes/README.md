# Egnyte & Google Drive Co-Existence Strategy

Cleanup Scripts: 

powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/fixes/cleanupGoogleFileAssociations.ps1')"

Lock Script: 

powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/fixes/lockGoogleFileAssociations.ps1')"

**Objective:** Force Windows to use the **Egnyte Desktop App** for Google file formats (`.gdoc`, `.gsheet`, `.gslides`) while allowing **Google Drive for Desktop** to remain installed for other uses.

## The Problem

Both Egnyte and Google Drive utilize aggressive "self-healing" mechanisms to claim file associations for Google formats.

* **Google Drive** attempts to overwrite the User Registry (`HKCU`) association on every startup.
* **Egnyte** attempts to set the System Registry (`HKCR`) association during installation.
* **Result:** When both are installed, they conflict. This corrupts the `UserChoice` registry key, causing files to fail to open entirely or defaulting to the wrong application.

## The Solution Methodology

To resolve this for a fleet of 300+ computers, we utilize a **"Clean, Assert, and Lock"** strategy. We do not rely on user interaction (e.g., "Open With..."). Instead, we manipulate Windows Access Control Lists (ACLs) to physically prevent Google Drive from writing to the association keys.

### 1. The Cleanup Script (`cleanupGoogleFileAssociations.ps1`)

**Intent:** To establish a "Scorched Earth" clean slate before re-deployment.

* **Process Management:** Forcefully terminates `GoogleDriveFS` processes to release file locks.
* **User Registry (`HKCU`):** Deletes current user overrides for Google extensions.
* **System Registry (`HKCR`):** Deletes system-wide association traces to ensure the Egnyte installer sees a fresh environment.
* **Outcome:** Windows effectively "forgets" how to open these files, clearing any corruption.

### 2. The Association Logic (Reinstall)

**Intent:** To establish Egnyte as the default System Handler.

* By installing Egnyte *after* the cleanup but *before* the lock, Egnyte registers its `ProgID` in `HKEY_CLASSES_ROOT`.
* Since the User Registry is empty (thanks to the cleanup), Windows falls back to this System setting automatically.

### 3. The Lock Script (`lockGoogleFileAssociations.ps1`)

**Intent:** To prevent Google Drive from re-hijacking the association in the future.

* **Target:** `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.gdoc` (and related extensions).
* **Mechanism:** The script applies a **"Deny"** permission on the *Current User* for `CreateSubKey` and `SetValue`.
* **Why this works:** Google Drive runs as the *Current User*. When it attempts to create a `UserChoice` key to hijack the association, the operating system rejects the write request due to the ACL Deny rule.
* **Outcome:** The User Registry remains empty for these extensions, forcing Windows to permanently use the Egnyte System Default.

---

## Deployment Workflow 

To ensure stability, the deployment must follow this strict order of operations:

1. **Uninstall** Google Drive and Egnyte (Remove the conflicting agents).
2. **Run Cleanup Script** (Clear the registry logic).
3. **Reboot** (Unload registry hives to ensure clean application).
4. **Install Egnyte** (Establishes Egnyte as the "System Owner").
5. **Run Lock Script** (Prevents any future changes to this ownership).
6. **Reinstall Google Drive** (Google Drive installs but is powerless to change the file associations).
