param(
    [string] $user="norsemangrey",
    [string] $repo,
    [string] $branch="main",
    [string] $script
)

# Verify all required arguments are provided
if (-not $user -or -not $repo -or -not $branch -or -not $script) {

    Write-Error "All arguments (user, repo, branch, script) must be provided."

    exit 1

}

# URL to download the entire repository as a ZIP file
$repoUrl = "https://github.com/$user/$repo/archive/refs/heads/$branch.zip"

# Path to save the ZIP file locally
$zipFilePath = "$env:TEMP\$repo.zip"

# Extract path for the ZIP file
$extractPath = "$env:TEMP\$repo"

# Path to the script to run
$scriptPath = "$extractPath\$repo-$branch\$script"

try {

    Write-Host "Downloading repository from $repoUrl..."

    # Download the repo ZIP file
    Invoke-WebRequest -Uri $repoUrl -OutFile $zipFilePath -ErrorAction Stop

    Write-Host "Repository downloaded successfully to $zipFilePath."

    Write-Host "Extracting ZIP file to $extractPath..."

    if (Test-Path $extractPath) {

        Remove-Item -Path $extractPath -Recurse -Force

        Write-Host "Cleaned up existing extract path: $extractPath."

    }

    # Extract the ZIP file
    Expand-Archive -Path $zipFilePath -DestinationPath $extractPath -Force -ErrorAction Stop

    Write-Host "Repository extracted successfully."

    # Test script path and run
    if (Test-Path $scriptPath) {

        Write-Host "Running the script at $scriptPath..."

        # Run the script
        Start-Process "powershell.exe" -ArgumentList "-NoExit -NoProfile -ExecutionPolicy RemoteSigned -File $scriptPath"

    } else {

        Write-Error "Script file not found at $scriptPath."

    }

} catch {

    Write-Error "An error occurred: $_"

} finally {

    if (Test-Path $zipFilePath) {

        # Remove the ZIP file after use
        Remove-Item $zipFilePath -Force

        Write-Host "Temporary ZIP file removed."
    }

}