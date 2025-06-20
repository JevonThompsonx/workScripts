WorkScripts
This repository (workScripts) serves as a collection of various PowerShell and batch scripts designed to automate common system administration tasks, including software installation, updates, drive mapping, and Windows configuration.

Each subfolder contains a set of related scripts and, where applicable, a dedicated README file with more detailed instructions and information.

Repository Structure
drives

installingSoftware

updatingSoftware

windows setup

windows uninstalls

📂 drives
This folder contains scripts primarily focused on mapping and unmapping Egnyte drives. The main script, cloneDrives.ps1, automates the download of all necessary batch files for this purpose.

Key Script:

cloneDrives.ps1: Downloads .bat files for Egnyte drive mapping.

For detailed instructions on using cloneDrives.ps1, including prerequisites and execution methods, please refer to its dedicated README:
README for cloneDrives.ps1

📂 installingSoftware
This folder houses scripts designed to automate the installation of software located in your C:\Archive directory. It supports both .exe and .msi installers with various levels of automation.

Versions & Functionality
installAllArchiveSoftware.bat (Stable):
A reliable version that sequentially runs each .exe and .msi file found in C:\Archive interactively.

Versions labeled “v2” (Testing):
These versions are under testing and offer more control, splitting installations into silent and interactive modes where necessary. They search for files within C:\Archive.

installAllArchiveSoftwarev2.5.ps1 (Current PowerShell Version):
This version performs quiet installations of .msi files, generating log files for each application in the archive folder. .exe files are installed with their normal graphical user interfaces.

Prerequisites (PowerShell Scripts)
PowerShell scripts are disabled by default. To enable for the current terminal session only:

powershell -ExecutionPolicy Bypass

Offline Install Steps
Open cmd.

Navigate to the directory with the script.

Enable PowerShell commands for this session only: powershell -ExecutionPolicy Bypass.

Run the script: ./installAllArchiveSoftwarev2.5.ps1

Online Install Steps
Open PowerShell as an administrator.

Enable PowerShell commands for this session only: powershell -ExecutionPolicy Bypass.

Execute the script directly from GitHub:

& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/installingSoftware/installAllArchiveSoftwarev2.5.ps1")))

Adding Web Apps (General Information)
3CX Web app: Access via https://ashleyvancecloud.3cx.us:5001/#/people.

Select "pwa creator" in the top right (at the right of the search bar) to install as a Progressive Web App.

📂 updatingSoftware
This collection of PowerShell scripts is designed to automate the download, silent installation, and cleanup of .msi application installers. These scripts include pre-flight checks to prevent disruption during updates by ensuring critical applications are not running.

Scripts Included
Update-Egnyte-v1.0.ps1

Description: Basic download, silent install, and cleanup for Egnyte (or similar) .msi files. No pre-flight checks.

Update-Egnyte-v1.5.ps1

Description: Updated Egnyte installer with a crucial pre-flight check. It aborts if specified critical applications (e.g., Word, Excel, AutoCAD, Vectorworks) are running to prevent data loss or disruption.

Update-MSI-Application-Base-v1.5.ps1

Description: A generic template based on v1.5, providing a foundational structure for updating any .msi application with pre-flight checks. Requires customization of $downloadUrl, $fileName, and $criticalProcesses.

Features
Automated Download: Fetches .msi installers from specified URLs.

Silent Installation: Installs applications without user intervention (/quiet /norestart).

Cleanup: Removes the downloaded installer file post-installation.

Pre-flight Application Check (v1.5+): Prevents installation if specified critical applications are running.

Configurable: Easy modification of variables like download URL, local paths, and critical process names.

Prerequisites & Configuration
Windows Operating System, PowerShell (v5.1+).

Administrator privileges for installation.

Configuration: Open the desired script and modify $downloadUrl, $localDirectory, $fileName, and $criticalProcesses (for v1.5+ scripts).

Usage
Run the desired script from a PowerShell console. You may need to run PowerShell as an Administrator.

.\Update-Egnyte-v1.5.ps1
# or for the base template
.\Update-MSI-Application-Base-v1.5.ps1

If scripts are disabled, temporarily adjust the execution policy: Set-ExecutionPolicy RemoteSigned -Scope Process -Force.

📂 windows setup
This folder contains scripts designed to perform basic Windows system setup and configuration changes.

Script Purpose
The main setup script, setup_script_windows_settings1.ps1, performs tasks such as:

Enabling the High Performance power plan.

Disabling hibernation.

Disabling User Account Control (UAC).

Enabling Dark Mode.

Offline Setup Steps
Open PowerShell as administrator (right-click).

Enable running PowerShell scripts: Set-ExecutionPolicy Bypass -Scope Process.

Enable admin account (if needed): .\enable_admin.bat.

Run the main setup script: .\setup_script_windows_settings1.ps1.

Run the Google Credentials script: .\AllowGoogleCredentials.ps1.

Online Setup Steps
Open PowerShell as administrator (right-click).

Enable running PowerShell scripts (if not already done): Set-ExecutionPolicy Bypass -Scope Process.

Enable admin account directly from GitHub:

& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/windows%20setup/enable_admin.bat")))

Run the main setup script directly from GitHub:

& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/setup_script_windows_settings1.ps1")))

Run the Google Credentials script directly from GitHub:

& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/windows%20setup/AllowGoogleCredentials.ps1")))

📂 windows uninstalls
This folder is intended for scripts related to uninstalling Windows applications or components.
