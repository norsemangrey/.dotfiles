# Check if Git is installed
function IsGitInstalled {

    Write-Host "Checking if Git is installed..."

    $gitInstalled = Get-Command git -ErrorAction SilentlyContinue

    return $null -ne $gitInstalled

}

# Get the installed Git version
function GetGitVersion {

    Write-Host "Getting installed Git version..."

    $gitVersion = git --version

    return $gitVersion

}

# Install Git using winget
function InstallGit {

    Write-Host "Installing Git using winget..."

    winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements --silent

    # Refresh the PATH variable in the current session (in order for the 'git' command to work)
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH","User")

}

function UpdateAvailable {

    Write-Host "Checking if update available..."

    return $(winget upgrade | Select-String -Pattern "Git.Git")

}

# Update Git using winget
function UpdateGit {

    Write-Host "Updating Git using winget..."

    winget upgrade -n Git.Git

}

# Check if Git is already installed
if (IsGitInstalled) {

    Write-Host "Git is already installed."

    $installedVersion = GetGitVersion

    Write-Host "Installed Git version: $installedVersion"

    $updateAvailable = UpdateAvailable

    # Check if the "updateNewer" parameter is set to update Git to a newer version
    if ($updateNewer -and $updateAvailable) {

        UpdateGit

        $installedVersion = GetGitVersion

        Write-Host "Git updated to the latest version: $installedVersion"
    }

} else {

    InstallGit

    $installedVersion = GetGitVersion

    Write-Host "Git installed successfully. Version: $installedVersion"

}

# Output the installed Git version
$installedVersion

#Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/norsemangrey/.dotfiles/master/git-install.ps1')
git clone https://github.com/norsemangrey/.dotfiles.git

cd ./dotfiles

. ./install.ps1