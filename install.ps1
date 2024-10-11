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

    if (-not (Test-Path $linkPath)) {

        Write-Host "Creating symlink: $linkPath -> $targetPath"
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath

    } else {

        Write-Host "Symlink already exists: $linkPath"

    }
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
                    $symlinkPath = $parts[1]

                    # Resolve the absolute path of the source file
                    $targetFilePath = Join-Path -Path $folder -ChildPath $sourceFile

                    if (Test-Path $targetFilePath) {

                        # Ensure the parent directory of the symlink exists
                        $symlinkDir = Split-Path -Path $symlinkPath -Parent

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