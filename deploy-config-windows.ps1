
<#
.SYNOPSIS
Install and manage symlinks for configuration files in a Windows development environment.

.DESCRIPTION
This script reads environment variables from a .env file and creates symbolic links for
configuration files based on paths specified in each subfolder's "paths.txt" file.
Symbolic links allow the configurations to be used without copying files directly,
facilitating easy updates and management.

.PARAMETER dryRun
When set to $true, performs a dry run without making any actual changes.

.PARAMETER debug
When set to $true, outputs additional debug information for each operation.

.EXAMPLE
.\install.ps1 -dryRun $true -debug $true
Performs a dry run with debug information enabled.

.EXAMPLE
.\install.ps1 -dryRun $false
Executes the script, creating symlinks as specified in the configuration files.

.NOTES
#>

param (
    [bool] $dryRun = $true,
    [bool] $debug = $true
)


# Path to the logger module file
$modulePath = "./utils/powershell/logging-and-output-functions.psm1"

# Import the module
Import-Module $modulePath


function Read-AndSetEnvironmentVariables {

    # Define the path to your .env file
    $envFilePath = ".env.windows"

    # Check if the .env file exists
    if (Test-Path -Path $envFilePath) {

        # Read each line in the .env file
        Get-Content -Path $envFilePath | ForEach-Object {

            $line = $_.Trim()

            # Ignore empty lines or lines that start with #
            if ($line -and -not $line.StartsWith("#")) {

                # Split at the first "=" to get the key and value
                $key, $value = $line -split "=", 2
                $key = $key.Trim()
                $value = $value.Trim()

                # Expand if any Environment paths
                $expandedValue = Invoke-Expression -Command "`"$value`""

                # Set the environment variable (PowerShell will automatically expand $Env: variables)
                [System.Environment]::SetEnvironmentVariable($key, $expandedValue, "Process")

            }
        }

    } else {

        Write-Message "Environment variables (.env) file not found!" "WARNING"

    }

}


function Test-ForEnvironmentVariable {
    param(
        [string] $path
    )

    # Regular expression pattern to match $Env:<variable>
    $pattern = '\$Env:([a-zA-Z_][\w]*)|%([a-zA-Z_][\w]*)%'

    # Replace all occurrences of environment variables in the path
    if ( $path -match $pattern ) {

        # Determine if it's a $Env: or %...% format and retrieve the variable name
        $envVariable = if ($matches[1]) { $matches[1] } else { $matches[2] }

        # Check if the environment variable is set
        $envValue = [System.Environment]::GetEnvironmentVariable($envVariable)

        # If the environment variable is not defined, return $null for the function
        if (-not $envValue) {

            Write-Message "Environment variable '$envVariable' is not set" "WARNING"

            return $null

        } else {

            $resolvedPath = $path -replace $pattern, $envValue

            return $resolvedPath

        }

    } else {

        return $path

    }

}


function Test-ForAbsolutePath {
    param (
        [string]$path,
        [string]$baseFolder  # Optional base folder for relative paths
    )

    # Regex pattern to match a Windows drive letter path, e.g., "C:\" or "D:\"
    $driveLetterPattern = '^[a-zA-Z]:\\'

    # Check if the path is absolute
    if ($path -match $driveLetterPattern) {

        # Absolute path, return it as is without checking existence
        return [System.IO.Path]::GetFullPath($path)

    } else {

        # Relative path: resolve it against the base folder or current directory
        $resolvedPath = if ($baseFolder) {

            Join-Path -Path $baseFolder -ChildPath $path

        } else {

            Join-Path -Path (Get-Location) -ChildPath $path

        }

        # Check if the resolved relative path exists
        if (Test-Path -Path $resolvedPath) {

            return [System.IO.Path]::GetFullPath($resolvedPath)

        } else {

            Write-Message "Path must exist if relative (i.e. targe path): '$path'." "WARNING"

            # Path does not exist; return null
            return $null

        }

    }

}


function Test-AndResolvePath {
    param (
        [string] $path,
        [string] $baseFolder
    )

    Write-Message "Verifying and resolving path ($path)..." "DEBUG"

    if ( $resolvedPath = Test-ForEnvironmentVariable $path ) {

        return Test-ForAbsolutePath $resolvedPath $baseFolder

    } else {

        return $null

    }

}


function New-DirectoryIfMissing {
    param(
        [string]$path
    )

    if (-not (Test-Path -Path $path)) {

        Write-Host "Creating symlink parent directory ($path)..." "DEBUG"

        New-Item -ItemType Directory -Path $path -Force

    }

}


function New-Symlink {
    param(
        [string] $linkPath,
        [string] $targetPath,
        [string] $name
    )

    # Backup folder for existing files (if not already a symlink)
    $backupFolder = Join-Path -Path "..\.dotfiles-old-config-backup" -ChildPath $name

    # Check if the linkPath exists
    if (Test-Path $linkPath) {

        # Get the item at linkPath
        $item = Get-Item $linkPath -Force

        # Check if file is a symlink
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {

            # It is a symbolic link, so get the current target of the symlink
            $currentTarget = (Get-Item -Path $linkPath -Force).Target

            # Check if current target path is same as target from file
            if ($currentTarget -eq $targetPath) {

                Write-Message "Symlink already exists and points to the correct target ($targetPath)" "INFO"

                # Exit the function as the symlink is already correct
                return

            } else {

                Write-Message "Symlink exists, but points to a different target ($currentTarget). Recreating..." "INFO"

                # Remove the incorrect symlink
                if ( -not $dryRun ) { Remove-Item -Path $linkPath -Force }
            }

        } else {

            Write-Message "A file or directory exists in the symlink path ($linkPath) and is not a symlink. Replacing..." "INFO"

            # Backup the file before deletion if it's not already a symlink
            $backupPath = Join-Path -Path $backupFolder -ChildPath ($item.Name)

            Write-Message "Backing up existing file to '$backupPath'..." "DEBUG"

            # Take backup of existing file/folder
            #if (-not $dryRun) {

                # Create backup folder if it does not exist
                if (-not (Test-Path -Path $backupFolder)) {

                    New-Item -ItemType Directory -Path $backupFolder | Out-Null

                }

                # Copy the file to the backup folder
                Copy-Item -Path $linkPath -Destination $backupPath

            #}

            # It is not a symbolic link (regular file or directory)
            if ( -not $dryRun ) { Remove-Item -Path $linkPath -Force -Recurse }

        }

    }

    # If we reach here, either the path didn't exist, or it was deleted. Create the symlink.
    Write-Message "Creating new symlink: $linkPath -> $targetPath" "INFO"

    # Create new symlink
    if ( -not $dryRun ) { New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath }

}


function Update-Symlinks {

    # Iterate through each subfolder of the root directory
    Get-ChildItem -Path $(Get-Location) -Recurse -Directory | ForEach-Object {

        $folder = $_.FullName
        $folderName = $_.Name

        # Check if paths.txt exists in the folder
        $pathsFile = Join-Path -Path $folder -ChildPath "paths.txt"

        # Check if paths file exists
        if (Test-Path $pathsFile) {

            Write-Message "Processing symlink paths for '$folderName'..." "INFO"

            # Read each line from the paths.txt
            Get-Content -Path $pathsFile | Where-Object { $_.Trim() -ne "" } | ForEach-Object {

                Write-Message "Processing new line ($_)" "DEBUG"

                # Get and trim new line
                $line = $_.Trim()

                # Check if line has content and starts with a "w" for "Windows"
                if ( $line -and $line.StartsWith("w") ) {

                    # Split the line into source file and symlink path
                    $parts = $line -split "\s+", 3

                    # Check if two strings / paths
                    if ($parts.Count -eq 3) {

                        # Verify paths and resolve to full path
                        $targetPath = Test-AndResolvePath $parts[1] $folder
                        $symlinkPath  = Test-AndResolvePath $parts[2] $folder

                        if ( $targetPath -and $symlinkPath) {

                            # Ensure the parent directory of the symlink exists
                            $symlinkDir = Split-Path -Path $symlinkPath -Parent

                            # Create symlink parent directories if they don't exist
                            New-DirectoryIfMissing -path $symlinkDir

                            # Create the symlink
                            New-Symlink -linkPath $symlinkPath -targetPath $targetPath -name $folderName

                        } else {

                            Write-Message "Issues with either target file path or symlink path." "ERROR"

                        }

                    } else {

                        Write-Message "Invalid line format in paths file. Entry must contain space separated system (w/l), target- and symlink path." "ERROR"

                    }

                }

            }

        }

    }

}

Read-AndSetEnvironmentVariables

Update-Symlinks
