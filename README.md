### **workScripts Repository**

A collection of PowerShell and batch scripts to automate system administration tasks, including software management, drive mapping, and Windows configuration.

The logic is separated to be plug and play as needed 

-----


##  **Usage:**
* **Prerequisite:** Run all commands in an **administrator PowerShell** session.
* **Offline:** Download the directory then Navigate to the script directory and run the `.bat` and `.ps1` files.
* **Online:** Execute each script directly from GitHub.


* **Run all scripts:**
```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/Run-All-Work-Scriptsv1.2.ps1')"
```
* **Main Setup:**
 ```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/setup_script_windows_settings1_3.ps1')"
```
* **Enable Admin:**
 ```powershell
powershell -ExecutionPolicy Bypass -Command "$tempFile = Join-Path $env:TEMP 'enable_admin.bat'; irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/enable_admin.bat' -OutFile $tempFile; & $tempFile"
```
* **Debloat:**
```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/win11Debloat.ps1')"
```
* **Engineering debloat:**
```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/engineeringDebloat.ps1')"
```
* **Google Credentials:**
 ```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/AllowGoogleCred.ps1')"
```
* **Install rmm from C:\Archive\rmm:**
```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/windows%20setup/rmm.ps1')"
```
* **Install all apps in C:\Archive folder:**
```powershell
powershell -ExecutionPolicy Bypass -Command "IEX (irm 'https://raw.githubusercontent.com/JevonThompsonx/workScripts/main/installingSoftware/installAllArchiveSoftwarev2.6.ps1')"
```


## Boring stuff

### **📂 drives**

Contains scripts for mapping and unmapping Egnyte network drives.

  * **Key Script:** `cloneDrives.ps1`
      * **Function:** Downloads all necessary `.bat` files for mapping Egnyte drives.
      * **Note:** See the dedicated README in the folder for detailed instructions.

-----

### **📂 installingSoftware**

Scripts to automate software installation from the `C:\Archive` directory.

  * **Scripts & Functionality:**

      * **`installAllArchiveSoftware.bat` (Stable):** Interactively installs all `.exe` and `.msi` files from `C:\Archive`.
      * **`installAllArchiveSoftwarev2.5.ps1` (Current):** Silently installs `.msi` files (with logging) and interactively installs `.exe` files.

  * **Usage:**

      * **Prerequisite:** PowerShell scripts require bypassing the execution policy. In a terminal, run: `powershell -ExecutionPolicy Bypass`
      * **Online Install (v2.5):** Run in an admin PowerShell:
        ```powershell
        & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/installingSoftware/installAllArchiveSoftwarev2.5.ps1")))
        ```
      * **Note on Web Apps:** Progressive Web Apps (PWAs) like the 3CX web app can be installed directly from the browser's address bar.

-----

### **📂 updatingSoftware**

PowerShell scripts to automate the download, silent installation, and cleanup of `.msi` application installers.

  * **Features:**

      * Automated download and post-install cleanup.
      * Silent installation using `/quiet /norestart` flags.
      * **Pre-flight Checks (v1.5+):** Aborts installation if critical applications (e.g., Word, Excel) are running.
      * **Configurable:** Scripts can be modified to change the download URL, file name, and list of critical processes.

  * **Key Scripts:**

      * **`Update-Egnyte-v1.5.ps1`:** Updates Egnyte with pre-flight application checks.
      * **`Update-MSI-Application-Base-v1.5.ps1`:** A generic, customizable template for updating any `.msi` application.

  * **Usage:**

    1.  **Configure:** Modify script variables (`$downloadUrl`, `$criticalProcesses`, etc.).
    2.  **Run:** Execute from an admin PowerShell console (e.g., `.\Update-Egnyte-v1.5.ps1`).
    3.  **Permissions:** If needed, allow scripts for the current session: `Set-ExecutionPolicy RemoteSigned -Scope Process -Force`

-----

### **📂 windows setup**

Scripts for initial Windows system configuration.

  * **Key Scripts & Functions:**

      * **`setup_script_windows_settings1.ps1`:** Enables High Performance power plan, disables hibernation and UAC, enables Dark Mode.
      * **`enable_admin.bat`:** Enables the local administrator account.
      * **`AllowGoogleCredentials.ps1`:** Configures settings for Google Credentials.

