# Get the root folder where the script is located
$rootDir = (Get-Location)

# Function to create directories if they don't exist
function Ensure-DirectoryExists {
    param([string]$path)

    if (-not (Test-Path -Path $path)) {

        Write-Host "Creating directory: $path"

        New-Item -ItemType Directory -Path $path -Force

    }

}

# Function to create symlink
function Create-Symlink {
    param([string]$linkPath, [string]$targetPath)

    # Check if the linkPath exists
    if (Test-Path $linkPath) {

        # Get the item at linkPath
        $item = Get-Item $linkPath -Force

        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {

            # It is a symbolic link
            Write-Host "Symlink already exists: $linkPath"

            return  # Exit the function since the symlink already exists

        } else {

            # It is not a symbolic link (regular file or directory)
            Write-Host "A file or directory exists at $linkPath and is not a symlink. Deleting it."

            Remove-Item -Path $linkPath -Force -Recurse

            Write-Host "Deleted: $linkPath"
        }

    }

    # If we reach here, either the path didn't exist, or it was deleted. Create the symlink.
    Write-Host "Creating symlink: $linkPath -> $targetPath"

    New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath

}

# Iterate through each subfolder of the root directory
Get-ChildItem -Path $rootDir -Recurse -Directory | ForEach-Object {

    $folder = $_.FullName

    # Check if paths.txt exists in the folder
    $pathsFile = Join-Path -Path $folder -ChildPath "paths.txt"

    if (Test-Path $pathsFile) {

        Write-Host "Processing paths.txt in $folder"

        # Read each line from the paths.txt
        Get-Content -Path $pathsFile | ForEach-Object {

            $line = $_.Trim()

            if ($line -and $line -notlike "#*") {

                # Split the line into source file and symlink path
                $parts = $line -split "\s+", 2

                if ($parts.Count -eq 2) {

                    $sourceFile = $parts[0]
                    $symlinkPathUnresolved = $parts[1]

                    $symlinkPath = Invoke-Expression "`"$symlinkPathUnresolved`""

                    # Resolve the absolute path of the source file
                    $targetFilePath = Join-Path -Path $folder -ChildPath $sourceFile

                    Write-Host $targetFilePath

                    if (Test-Path $targetFilePath) {

                        # Ensure the parent directory of the symlink exists
                        $symlinkDir = Split-Path -Path $symlinkPath -Parent

                        Write-Host $symlinkDir

                        Ensure-DirectoryExists -path $symlinkDir

                        # Create the symlink
                        Create-Symlink -linkPath $symlinkPath -targetPath $targetFilePath

                    } else {

                        Write-Host "Source file not found: $targetFilePath"

                    }
                } else {

                    Write-Host "Invalid line format in paths.txt: $line"

                }
            }
        }
    }
}