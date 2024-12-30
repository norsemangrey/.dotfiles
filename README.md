This repository provides configuration files and scripts for setting up symlinks in a Windows development environment. The install.ps1 script will generate symbolic links to connect various configuration files to their respective target locations, including any sensitive configuration files stored in cloud providers.

## Installation

### Prerequisites

1. **Git:** If Git is not installed, you can install it using the `git-install.ps1` script:

    ```powershell
    Invoke-Expression (Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/norsemangrey/.dotfiles/master/git-install.ps1')
    ```

    This command installs Git, clones the repository, and executes the script automatically.

2. **Git Already Installed:** Clone this repository and ensure submodules are initialized:

    ```powershell
    git clone --recurse-submodules https://github.com/norsemangrey/.dotfiles.git
    Set-Location ./.dotfiles
    . ./install.ps1 -dryRun $true -debug $true
    ```
    >Note: The `-dryRun` flag is set to `$true` by default. To apply actual changes, set it to `$false` (see Usage).

## Usage

### Running the Script

1. **Basic Execution:** Run the script with:

    ```powershell
    . ./install.ps1 -dryRun $true -debug $true
    ```
   - `-dryRun`: Set this to `$false` to apply the symlink changes, replacing existing files in the specified locations.
   - `-debug`: Toggle debug output for more detailed logging.

2. **Updating Symlinks:** To pull the latest changes and re-run the script:

    ```powershell
    Set-Location $Env:USERPROFILE/.dotfiles
    git pull
    . ./install.ps1 -dryRun $true -debug $true
    ```
    >WARNING: When `-dryRun` is set to `$false`, any existing files at the symlink target paths will be replaced, and their original content may be lost.

### Manually Creating Symlinks

To create symbolic links manually, use:

- **CMD**:

    ```cmd
    mklink <target-path> <link-path>
    ```
- **PowerShell**:

    ```powershell
    New-Item -ItemType SymbolicLink -Path <link-path> -Target <target-path>
    ```

### Structure and Configuration

- **Environment Variables**:

  - Configuration paths are stored in a .env file.
  - The script reads these paths to create symlinks in the appropriate directories.

- **Sensitive Files**:

  - Sensitive configurations, such as API keys or private credentials, are stored in a cloud directory and linked by the script.
  - Only the symlink paths are stored in this repository for security.

#### Directory Structure

- **Root Directory**: Contains the primary script (`install.ps1`) and subfolders for different configurations.
- **utils/**: Contains auxiliary scripts, such as `logging-and-output-functions.psm1`, used for logging and message output.

## Notes

- **TODO**: The following improvements are planned:

  - Complete initial configurations for all supported applications.