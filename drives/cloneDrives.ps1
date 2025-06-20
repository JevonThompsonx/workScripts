# Set the target directory where the files will be saved
$targetDirectory = "C:\Archive\Map egnyte drives"

# Define the base URL for the raw GitHub content (for downloading files)
$githubRawUrlBase = "https://raw.githubusercontent.com/JevonThompsonx/eDrives/main/"

# Define the GitHub API URL to list repository contents (for discovering files)
$githubApiUrl = "https://api.github.com/repos/JevonThompsonx/eDrives/contents/"

# --- Script Execution ---

Write-Host "Starting download of GitHub files..."
Write-Host "Target directory: $targetDirectory"

# Check if the target directory exists, if not, create it
if (-not (Test-Path $targetDirectory)) {
    Write-Host "Creating target directory: $targetDirectory"
    New-Item -Path $targetDirectory -ItemType Directory | Out-Null
} else {
    Write-Host "Target directory already exists: $targetDirectory"
}

# Step 1: Get the list of files from the GitHub API
Write-Host "Fetching file list from GitHub API: $githubApiUrl"
$filesToDownload = @() # Initialize an empty array for file names

try {
    # Invoke-RestMethod is used to call REST APIs and parses the JSON response
    $repoContents = Invoke-RestMethod -Uri $githubApiUrl -ErrorAction Stop

    # Filter for .bat files
    foreach ($item in $repoContents) {
        # Check if it's a file and ends with .bat
        if ($item.type -eq "file" -and $item.name.EndsWith(".bat", [System.StringComparison]::OrdinalIgnoreCase)) {
            $filesToDownload += $item.name
        }
    }

    if ($filesToDownload.Count -eq 0) {
        Write-Warning "No .bat files found in the repository."
        Write-Host "Download process complete (no .bat files to download)."
        exit # Exit the script if no .bat files are found
    } else {
        Write-Host "Found $($filesToDownload.Count) .bat files to download." -ForegroundColor Cyan
    }

}
catch {
    Write-Error "Failed to fetch repository contents from GitHub API. Error: $($_.Exception.Message)"
    Write-Host "Please check the repository URL or your internet connection." -ForegroundColor Red
    exit # Exit the script on API failure
}


# Step 2: Loop through each discovered .bat file and download it
foreach ($fileName in $filesToDownload) {
    # Construct the raw file URL using the base URL and the file name
    $sourceUrl = $githubRawUrlBase + ([uri]::EscapeDataString($fileName))
    # Construct the full local path for the downloaded file
    $destinationPath = Join-Path -Path $targetDirectory -ChildPath $fileName

    Write-Host "Attempting to download '$fileName' from '$sourceUrl'..."

    try {
        # Use Invoke-WebRequest to download the file
        # -OutFile specifies the local path to save the downloaded content
        # -UseBasicParsing is recommended for simpler parsing of web content
        # -ErrorAction Stop ensures that any error during download stops the script immediately
        Invoke-WebRequest -Uri $sourceUrl -OutFile $destinationPath -UseBasicParsing -ErrorAction Stop
        Write-Host "Successfully downloaded '$fileName' to '$destinationPath'" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download '$fileName'. Error: $($_.Exception.Message)"
        Write-Host "Please check your internet connection or the file name/path on GitHub." -ForegroundColor Red
    }
}

Write-Host "All specified .bat files downloaded successfully!"
Write-Host "You can find the files in: $targetDirectory"
