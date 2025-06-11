# Egnyte Nuke & Update

Scripts used to delete egnyte, all leftover files and reboot if possible

## Versions 
I doubt this one will change much. 

## How to Use 
1. `Set-ExecutionPolicy -Scope Process Unrestricted` to allow running powershell scripts

### Offline - downloading script
1. Download files in this folder 
2. Within powershell , navigate to the folder with the scripts
3. run the "Nuke" script
4. reboot when prompted to
5. run the "Update" script to install the latest version of egnyte - (3.26) as of writing
5. map drives if needed

### Online - running script without downloading
1. & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Nuke.ps1")))
2. Reboot
3. Install latest version of egnyte
  1. Download and install via link: https://egnyte-cdn.egnyte.com/egnytedrive/win/en-us/latest/EgnyteConnectWin.msi
  or 
  2. Run installs script: & ([scriptblock]::Create((irm "https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/updatingSoftware/egnyteNukeAndUpdate/Egnyte-Update.ps1")))
