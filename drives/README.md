# Drives

## PowerShell Script: Download Egnyte Drive Mapping Files
This README provides instructions on how to use the cloneDrives.ps1 PowerShell script, which automatically downloads all .bat files related to Egnyte drive mapping from a specified GitHub repository.

## What This Script Does
The cloneDrives.ps1 script will perform the following actions:
- It checks for and, if necessary, creates the directory C:\Archive\Map egnyte drives.
- It queries the GitHub API to identify all .bat files within the JevonThompsonx/eDrives repository's main branch.
- It then downloads each identified .bat file into the C:\Archive\Map egnyte drives folder.

## Prerequisites
Before running the script, you might need to adjust your PowerShell execution policy. By default, PowerShell prevents the execution of scripts downloaded from the internet for security reasons.

### Enabling PowerShell Script Execution
To allow the script to run, open PowerShell as an Administrator and execute the following command:

`Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**Set-ExecutionPolicy:** This cmdlet modifies the execution policy

**RemoteSigned:** This policy allows scripts created on your local computer to run. Scripts downloaded from the internet must be signed by a trusted publisher. Since this script is a one-off download and execution, RemoteSigned is generally sufficient and safer than Unrestricted.

**-Scope CurrentUser:** This applies the policy only to the current user, not to all users on the system, making it a less impactful change.

You will be prompted to confirm this change. Type Y and press Enter.

## How to Run the Script
You can run the cloneDrives.ps1 script directly from its raw GitHub URL without needing to download it manually first.

1. Open PowerShell:
2. Search for "PowerShell" in your Start Menu.
3. run as admin
4. Execute the command: Copy and paste the following command into your PowerShell window and press Enter:

`& ([scriptblock]::Create((irm "<https://raw.githubusercontent.com/JevonThompsonx/workScripts/refs/heads/main/drives/cloneDrives.ps1>")))`

** This is an alias for Invoke-RestMethod, which downloads the content of the URL (the raw PowerShell script).

**([scriptblock]::Create(...)):** This takes the downloaded script content (as a string) and converts it into a runnable PowerShell script block.

**&:** This is the call operator, which executes the script block.

The script will then proceed to download the .bat files to C:\Archive\Map egnyte drives and provide status messages in the PowerShell window.
