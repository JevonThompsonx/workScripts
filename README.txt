 Installing Files from C:\Archive
----------------------------------
This script is designed to install all files located in the "C:\Archive" folder.
It requires this folder to exist; otherwise, it won’t function correctly.

Versions & Functionality
------------------------------

installAllArchiveSoftware.bat (Stable)
 This version is reliable and always works by running each `.exe` and `.msi` file in the "C:\Archive" folder one at a time.

Versions labeled “v2” (Testing)
These versions are still under testing. For some applications, I needed to adjust installation options, so they're split into silent installs and interactive installs. Both types of install search for files within the C:\Archive folder.

V2.5 
My current powershell version. This version does quiet installs of .msi files with log files for each app in the archive folder while .exes does a normal install with the GUI

Powershells scripts are disabled by default. To enable for the current terminal session only: 
powershell -ExecutionPolicy Bypass 

Steps:
1. Open cmd 
2. Navigate to the directory with the script
3. Enable powershell commands for this session only: powershell -ExecutionPolicy Bypass 
4. Run the script: ./installAllArchiveSoftwarev2.5.ps1

