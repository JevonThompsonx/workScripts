# Setup Script

The purpose of this script is to do some basic windows setup 


Performs basic system setup: Enables High Performance power plan,
disables hibernation, disables UAC, and enables Dark Mode.

## Offline Install
1. Open powershell as admin - right click 
2. Enable running powershell scripts: 
3. Run the script `./setup_script_windows_settigns1.ps1`

## Online Install 

1. open powershell as admin - right click 
2. Enable running powershell scripts if not already done: 
3. & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/InstallScripts/refs/heads/main/setup_script_windows_settings1.ps1")))