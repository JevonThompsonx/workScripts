# BOLO - I have been modified for a new deployment method.

# Main function to encapsulate the script's logic.
function Get-AgentSelection {
    # Define the target directory.
    $targetDirectory = "C:\Archive\rmm"
    $regexPattern = '^([^-]+)-AV' # Regex to capture the text before "-AV".

    # --- Directory and File Validation ---
    # Check if the directory exists.
    if (-not (Test-Path -Path $targetDirectory -PathType Container)) {
        Write-Host "ERROR: The folder at '$targetDirectory' was not found." -ForegroundColor Red
        $choice = Read-Host "Please place the required files in the directory. Do you want to try again? (y/n)"
        if ($choice -eq 'y') {
            # If the user says 'y', run the function again.
            Get-AgentSelection
        }
        # If the user enters anything else, exit the script.
        return
    }

    # Get all files matching the pattern *-AV_*. This is more efficient than getting all files.
    # The BaseName property is used so we don't have to worry about the file extension.
    $files = Get-ChildItem -Path $targetDirectory -Filter "*-AV_*" -File | Select-Object FullName, BaseName

    # Check if any files were found.
    if ($null -eq $files) {
        Write-Host "No agent files matching the '*-AV_*' pattern were found in '$targetDirectory'." -ForegroundColor Yellow
        Read-Host "Press Enter to exit."
        return
    }

    # --- Display Menu and Get User Input ---
    Write-Host "Please select an agent from the list below:" -ForegroundColor Cyan
    
    # Create a temporary array to hold the display names and full file paths.
    $selectionList = @()
    $i = 1
    foreach ($file in $files) {
        # Use regex to extract the location name from the file's base name.
        if ($file.BaseName -match $regexPattern) {
            # $Matches[1] contains the first captured group from our regex: ([^-]+)
            $locationName = $Matches[1].Replace("_", " ") # Replace underscores with spaces for readability.
            
            # Display the numbered option to the user.
            Write-Host "  $i. $locationName"

            # Add the file info to our selection list for later retrieval.
            $selectionList += [pscustomobject]@{
                ID = $i
                Location = $locationName
                FullPath = $file.FullName
            }
            $i++
        }
    }

    # Check if the selection list is empty after processing.
    if ($selectionList.Count -eq 0) {
        Write-Host "No files matched the expected naming convention to build the selection list." -ForegroundColor Yellow
        Read-Host "Press Enter to exit."
        return
    }

    # --- Process User Selection ---
    $selection = 0
    while ($selection -lt 1 -or $selection -gt $selectionList.Count) {
        try {
            $input = Read-Host "Enter the number of your choice"
            # Attempt to cast the user's input to an integer.
            $selection = [int]$input
            if ($selection -lt 1 -or $selection -gt $selectionList.Count) {
                Write-Host "Invalid number. Please enter a number between 1 and $($selectionList.Count)." -ForegroundColor Red
            }
        }
        catch {
            # This block runs if the user enters text that is not a number.
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            $selection = 0 # Reset selection to ensure the loop continues.
        }
    }

    # Retrieve the chosen file using the validated selection.
    # The -1 is because arrays are 0-indexed, while our list starts at 1.
    $chosenFile = $selectionList[$selection - 1]

    # --- Final Output ---
    Clear-Host
    Write-Host "You have selected:" -ForegroundColor Green
    Write-Host "Location: $($chosenFile.Location)"
    Write-Host "Full File Path: $($chosenFile.FullPath)"
    
    # You can now use the $chosenFile.FullPath variable to do something with the file.
    # For example, to copy it:
    # Copy-Item -Path $chosenFile.FullPath -Destination "C:\some\other\path\"
    # Or to execute it (use with caution):
    # & $chosenFile.FullPath
}

# --- Script Entry Point ---
# Clear the screen and run the main function.
Clear-Host
Get-AgentSelection

# Pause the script at the end to see the output.
Write-Host ""
Read-Host "Script finished. Press Enter to exit."
