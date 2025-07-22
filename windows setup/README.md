# Setup Script

The purpose of this script is to do some basic windows setup 


Performs basic system setup: Enables High Performance power plan,
disables hibernation, disables UAC, and enables Dark Mode.

## Offline 
1. Open powershell as admin - right click 
2. Enable running powershell scripts: Set-ExecutionPolicy Bypass -Scope Process
3. Enable admin account: .\enable_admin.bat
4. Run the script .\setup_script_windows_settigns1.ps1
5. Run the script .\AllowGoogleCredentials.ps1


## Online 

1. open powershell as admin - right click 
2. Enable running powershell scripts if not already done: Set-ExecutionPolicy Bypass -Scope Process
  
   Enable admin account:
   ```
   & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/windows%20setup/enable_admin.bat)))
   ```
   
   Windows settings:
   ```
   Windows settings: `& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/setup_script_windows_settings1.ps1")))
   ```
   
  GCWP:
   ```
   & ([scriptblock]::Create((irm "https://github.com/JevonThompsonx/workScripts/raw/refs/heads/main/windows%20setup/AllowGCWPv1.2.ps1")))
   ```
