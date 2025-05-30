# PowerShell MSI Application Update Scripts

This repository contains a collection of PowerShell scripts designed to automate the download, silent installation, and cleanup of `.msi` application installers. These scripts have evolved to include pre-flight checks for running applications to prevent disruption during updates.

## Scripts Included

1.  **`Update-Egnyte-v1.0.ps1`**
    * **Version:** 1.0 (2025-05-29)
    * **Description:** This initial version downloads a specified `.msi` file (configured for Egnyte by default), installs it silently, and then removes the downloaded installer.
    * **Key Feature:** Basic download, install, and cleanup functionality.
    * **Limitation:** Does not check for running applications before attempting installation.

2.  **`Update-Egnyte-v1.5.ps1`** 
    * **Version:** 1.5 (2025-05-29)
    * **Description:** An updated version of the Egnyte installer script. It includes a crucial pre-flight check to see if specific critical applications (that might use Egnyte for storage) are running. If they are, the script will abort the update to prevent potential data loss or disruption.
    * **Key Features:**
        * Downloads, silently installs, and cleans up the `.msi` installer.
        * **Pre-flight check:** Verifies if critical applications (e.g., Word, Excel, AutoCAD, Vectorworks) are running and aborts if they are.
    * **Customization:** The list of `$criticalProcesses` can be modified to suit your environment.

3.  **`Update-MSI-Application-Base-v1.5.ps1`**
    * **Version:** 1.5 (2025-05-29)
    * **Description:** This script serves as a generic template based on `Update-Egnyte-v1.5.ps1`. It includes the pre-flight check for running applications and is intended to be adapted for updating various `.msi` applications.
    * **Key Features:**
        * Provides a foundational structure for downloading, silently installing, and cleaning up any `.msi` installer.
        * Includes the pre-flight check for running applications.
    * **Customization:** You **must** update the `$downloadUrl`, `$fileName`, and potentially the `$criticalProcesses` variables for the specific application you intend to manage.

## Features

* **Automated Download:** Fetches the `.msi` installer from a specified URL.
* **Silent Installation:** Installs the application without user intervention (`/quiet /norestart`).
* **Cleanup:** Removes the downloaded installer file post-installation.
* **Pre-flight Application Check (v1.5+):** Prevents installation if specified critical applications are running, avoiding potential conflicts or data issues.
* **Configurable:** Key variables like download URL, local paths, and critical process names can be easily modified within the scripts.

## Prerequisites

* Windows Operating System.
* PowerShell (typically version 5.1 or higher).
* Permissions to:
    * Create directories (if `$localDirectory` doesn't exist).
    * Download files from the internet.
    * Install software (Administrator privileges are usually required for `msiexec`).
    * Remove files.

## Configuration

Open the desired script in a text editor (like PowerShell ISE, VS Code, or Notepad) and modify the following variables in the "--- Configuration ---" section:

* `$downloadUrl`: The direct download link to the `.msi` file.
    * **Example:** `"https://example.com/path/to/your/application.msi"`
* `$localDirectory`: The local folder where the installer will be downloaded.
    * **Example:** `"C:\TempInstallers"`
* `$fileName`: The name to give the downloaded installer file.
    * **Example:** `"MyApplicationInstaller.msi"`

For `v1.5` scripts (`Update-Egnyte-v1.5.ps1` and `Update-MSI-Application-Base-v1.5.ps1`), you will also need to configure:

* `$criticalProcesses`: An array of process names (without the `.exe` extension) that should cause the script to halt if they are running.
    * **Example:**
        ```powershell
        $criticalProcesses = @(
            "MYCRITICALAPP",
            "ANOTHERAPP"
            # Add any other relevant application process names here
        )
        ```

## Usage

1.  **Configure:** Modify the script variables as described above for the application you wish to update.
2.  **Run:** Execute the script from a PowerShell console. You may need to run PowerShell as an Administrator, especially for the installation step.

    ```powershell
    .\Update-Egnyte-v1.5.ps1
    ```
    or for the base template after customization:
    ```powershell
    .\Update-MSI-Application-Base-v1.5.ps1
    ```

3.  **Execution Policy:** If you encounter an error about scripts being disabled on your system, you might need to adjust the PowerShell execution policy. For example, to allow scripts signed by a trusted publisher or locally created scripts for the current session:
    ```powershell
    Set-ExecutionPolicy RemoteSigned -Scope Process -Force
    ```
    (Use with caution and understand the security implications of execution policies.)

## Exit Codes

* `0`: Script completed successfully.
* `1`: General error (e.g., download failure, installation failure).
* `99` (for v1.5+ scripts): Update aborted because one or more critical applications were found running.

## Important Notes

* **MSI Only:** These scripts are specifically designed for `.msi` installers. They will not work for `.exe` or other installer types without significant modification.
* **Administrator Privileges:** Installation of software typically requires administrator rights. Ensure the script is run in an elevated PowerShell session if necessary.
* **Error Handling:** The scripts include basic `try/catch` blocks for error handling during download and installation. Check the console output for error messages.
* **URL Validity:** Ensure the `$downloadUrl` is always pointing to the correct and current version of the installer you wish to deploy.

## Future Improvements (Potential)

* Support for `.exe` installers with silent switches.
* More robust logging (e.g., to a file or Event Log).
* Parameterization of script variables for easier command-line execution.
* Integration with a version checking mechanism to only download if an update is available.

## License

Feel free to use, modify, and distribute these scripts. If you plan to use this in a more formal project, consider adding a standard open-source license file (e.g., MIT License).
